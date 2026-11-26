import Cocoa
import ApplicationServices
import Darwin

// Brave profile tool:
//   brave-focus <work|personal>              focus the profile's window,
//                                            press again (while it is active) to hide it
//   brave-focus --new-window <work|personal> always open a new window
//   brave-focus --serve                      internal: warm daemon for the socket
//
// Each profile has its own Brave build: work lives in stable Brave, personal in
// Brave Beta. Two applications instead of two profiles inside one app, because
// activating an app raises all of its windows in every Space — with both profiles
// in one app, focusing work dragged the personal window over the terminal on the
// other display.
//
// The first Accessibility call into Brave costs tens of milliseconds (connection
// setup), so the hotkey goes through a small daemon that keeps it warm: the
// script talks to it over a unix socket and only pays the cold start once.
//
// The daemon must keep a real run loop on its main thread. AppKit only refreshes
// `NSWorkspace.frontmostApplication` while a run loop is pumping; a process that
// sits in `select()` sees the value it read at startup forever. That stale value
// made the toggle hide an already-hidden Brave instead of focusing it, so the
// first press did nothing at all. The socket now lives on a background thread and
// the main thread runs the run loop for the tracker.

// ---------------------------------------------------------------------------
// configuration
// ---------------------------------------------------------------------------

let DEBUG = ProcessInfo.processInfo.environment["BRAVE_FOCUS_DEBUG"] == "1"

/// True in `--serve` mode: the daemon never shows permission prompts.
var isDaemon = false

/// Test/experiment switch: focus the window with Accessibility only and never
/// activate the whole application. Activating an app raises all of its windows
/// in every Space, which drags the other profile forward on the other display.
var windowOnly = false

/// Kept alive for the daemon's lifetime so App Nap does not throttle polling.
var activityToken: NSObjectProtocol?

func debug(_ message: @autoclosure () -> String) {
    guard DEBUG else { return }
    FileHandle.standardError.write(("[brave-focus] " + message() + "\n").data(using: .utf8)!)
}

/// One Brave build per profile.
struct Target {
    let bundle: String
    let appName: String
    let profileDir: String
    /// Brave puts the profile name in the window title only when the app has more
    /// than one profile, so a single-profile build matches any window.
    let titleSuffix: String?
}

let TARGETS: [String: Target] = [
    "work": Target(
        bundle: "com.brave.Browser",
        appName: "Brave Browser",
        profileDir: "Profile 1",
        titleSuffix: "- Brave - Work"
    ),
    "personal": Target(
        bundle: "com.brave.Browser.beta",
        appName: "Brave Browser Beta",
        profileDir: "Default",
        titleSuffix: nil
    ),
]

/// Gap left around a maximized window — matches Raycast's window management.
let WINDOW_GAP: CGFloat = 8

/// Idle time after which the helper daemon exits.
let DAEMON_IDLE_TIMEOUT: TimeInterval = 4 * 60 * 60

/// How often the daemon samples the frontmost application.
let TRACKER_INTERVAL: TimeInterval = 0.2

// ---------------------------------------------------------------------------
// logging
// ---------------------------------------------------------------------------

let LOG_LIMIT_BYTES = 256 * 1024

private let logTimestampFormatter = ISO8601DateFormatter()

func supportDirectory() -> String {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/brave-focus").path
    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    return path
}

/// One line per decision in `~/Library/Caches/brave-focus/log`. A silent helper
/// is impossible to debug after the fact, and a silent "nothing happened" is
/// exactly the failure this tool had.
func note(_ message: @autoclosure () -> String) {
    let line = "\(logTimestampFormatter.string(from: Date())) \(isDaemon ? "daemon" : "client")[\(getpid())] \(message())\n"
    if DEBUG { FileHandle.standardError.write(line.data(using: .utf8)!) }

    let manager = FileManager.default
    let path = supportDirectory() + "/log"
    if let attributes = try? manager.attributesOfItem(atPath: path),
       let size = attributes[.size] as? Int, size > LOG_LIMIT_BYTES {
        try? manager.removeItem(atPath: path + ".1")
        try? manager.moveItem(atPath: path, toPath: path + ".1")
    }
    if !manager.fileExists(atPath: path) {
        manager.createFile(atPath: path, contents: nil)
    }
    if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    }
}

func milliseconds(since start: CFAbsoluteTime) -> String {
    String(format: "%.0f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000)
}

// ---------------------------------------------------------------------------
// accessibility helpers
// ---------------------------------------------------------------------------

/// Launchers that are frontmost while a hotkey command runs.
let LAUNCHER_BUNDLES: Set<String> = [
    "com.raycast.macos",
    "com.runningwithcrayons.Alfred",
    "com.apple.Spotlight",
]

/// Remembers the last app that was really in front, ignoring launchers.
///
/// The value has to be sampled from a run loop (see the note at the top of the
/// file): pulling it once and keeping it for hours is what broke the toggle.
final class ActiveAppTracker {
    static let shared = ActiveAppTracker()

    private let lock = NSLock()
    private var frontmost: String?
    private var lastNonLauncher: String?

    var frontmostBundle: String? {
        lock.lock()
        defer { lock.unlock() }
        return frontmost
    }

    var lastNonLauncherBundle: String? {
        lock.lock()
        defer { lock.unlock() }
        return lastNonLauncher
    }

    func sample() {
        let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        lock.lock()
        frontmost = bundle
        if let bundle, !LAUNCHER_BUNDLES.contains(bundle) {
            lastNonLauncher = bundle
        }
        lock.unlock()
    }

    /// Daemon only: keep the sample fresh while the run loop runs.
    func startPolling(every interval: TimeInterval = TRACKER_INTERVAL) {
        sample()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            ActiveAppTracker.shared.sample()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
}

/// True when the given Brave build is the app the user is actually looking at.
///
/// While a hotkey command runs its launcher is frontmost, so a launcher in front
/// means "ask the history what was there before". No history (a freshly started
/// client) means no hiding: bringing the window forward is always what the user
/// wanted, hiding it is only right when they are already in it.
func isFrontmostApp(_ bundle: String) -> Bool {
    let frontmost = ActiveAppTracker.shared.frontmostBundle
    if frontmost == bundle { return true }
    guard let frontmost, LAUNCHER_BUNDLES.contains(frontmost) else { return false }
    return ActiveAppTracker.shared.lastNonLauncherBundle == bundle
}

/// Brave shows the profile name in the window title only when the app has more
/// than one profile, so `nil` means "whatever window this build has".
func titleMatches(_ window: AXUIElement, _ suffix: String?) -> Bool {
    guard let suffix else { return true }
    return stringAttribute(window, kAXTitleAttribute).hasSuffix(suffix)
}

/// Did the app end up with the window we asked for? Element identity is the
/// reliable part; the title check covers Chromium swapping the AX object.
func isFocused(app: NSRunningApplication, window: AXUIElement, suffix: String?) -> Bool {
    guard let focused = focusedWindow(of: app) else { return false }
    if CFEqual(focused, window) { return true }
    guard let suffix else { return false }
    return stringAttribute(focused, kAXTitleAttribute).hasSuffix(suffix)
}

func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return (value as? String) ?? ""
}

func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return (value as? Bool) ?? false
}

func setBoolAttribute(_ element: AXUIElement, _ attribute: String, _ value: Bool) {
    AXUIElementSetAttributeValue(element, attribute as CFString, value ? kCFBooleanTrue : kCFBooleanFalse)
}

func windows(of app: NSRunningApplication) -> [AXUIElement] {
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success else {
        return []
    }
    return (value as? [AXUIElement]) ?? []
}

func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
          let window = value else { return nil }
    return (window as! AXUIElement)
}

func app(for bundle: String) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first
}

/// Reading and moving windows needs Accessibility permission for whichever app
/// runs this helper (Raycast, the terminal, …). The daemon must not prompt: it
/// would ask on every press, so only the short-lived client does.
func ensureAccessibility(prompt: Bool = true) -> Bool {
    if AXIsProcessTrusted() { return true }
    guard prompt else { return false }
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

// ---------------------------------------------------------------------------
// geometry
// ---------------------------------------------------------------------------

func windowFrame(_ window: AXUIElement) -> CGRect? {
    var positionRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
    AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
    guard let positionRef, let sizeRef else { return nil }
    var origin = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(positionRef as! AXValue, .cgPoint, &origin)
    AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
    return CGRect(origin: origin, size: size)
}

/// AX uses top-left origin on the main display, NSScreen uses bottom-left.
func axRect(from cocoa: NSRect, mainHeight: CGFloat) -> CGRect {
    CGRect(x: cocoa.origin.x, y: mainHeight - cocoa.maxY, width: cocoa.width, height: cocoa.height)
}

func screen(for window: AXUIElement) -> NSScreen? {
    let mainHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
        ?? NSScreen.screens.first?.frame.height ?? 0
    guard let frame = windowFrame(window) else { return NSScreen.main }
    let center = CGPoint(x: frame.midX, y: frame.midY)
    return NSScreen.screens.first { axRect(from: $0.frame, mainHeight: mainHeight).contains(center) }
        ?? NSScreen.main
}

/// Brave keeps re-laying out a fresh window for a while; wait until its frame
/// stops changing before touching the geometry.
func waitUntilStable(_ window: AXUIElement, timeout: TimeInterval = 3) {
    guard var last = windowFrame(window) else { return }
    var stableSince = Date()
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        usleep(100_000)
        guard let current = windowFrame(window) else { return }
        if current == last {
            if Date().timeIntervalSince(stableSince) > 0.35 { return }
        } else {
            last = current
            stableSince = Date()
        }
    }
}

/// Maximize inside the screen's visible frame, leaving `WINDOW_GAP` on each side.
/// Chromium may move the window again after a first successful set, so the
/// geometry has to hold for a few consecutive checks.
func maximizeWithGap(_ window: AXUIElement, attempts: Int = 40) {
    guard let screen = screen(for: window) else { return }
    let mainHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
        ?? screen.frame.height
    let target = axRect(from: screen.visibleFrame, mainHeight: mainHeight)
        .insetBy(dx: WINDOW_GAP, dy: WINDOW_GAP)

    debug("target=\(target) screen=\(screen.localizedName)")

    var consecutiveMatches = 0
    for attempt in 0..<attempts {
        var origin = target.origin
        var size = target.size
        if let value = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        usleep(150_000)

        guard let frame = windowFrame(window) else { return }
        let matches = abs(frame.origin.x - target.origin.x) < 1
            && abs(frame.origin.y - target.origin.y) < 1
            && abs(frame.width - target.width) < 1
            && abs(frame.height - target.height) < 1
        debug("attempt \(attempt): \(frame) match=\(matches)")

        if matches {
            consecutiveMatches += 1
            if consecutiveMatches >= 3 { return }
        } else {
            consecutiveMatches = 0
        }
    }
}

// ---------------------------------------------------------------------------
// actions
// ---------------------------------------------------------------------------

/// What a press is going to do. Deciding first lets the daemon answer before a
/// slow action (opening a window takes seconds) without lying about it.
enum Work {
    case hide(NSRunningApplication)
    case focus(NSRunningApplication, AXUIElement, String?)
    case activateOnly(NSRunningApplication)
    case open(Target)
    case fail(String)
}

/// `allowHide` is false for the cold client: without a daemon there is no
/// tracked history of the frontmost app, and a wrong "hide" looks exactly like a
/// hotkey that did nothing. Bringing the window forward is always safe.
func plan(profileKey: String, forceNewWindow: Bool, prompt: Bool, allowHide: Bool) -> Work {
    guard let target = TARGETS[profileKey.lowercased()] else { return .fail("unknown-profile") }

    let trusted = ensureAccessibility(prompt: prompt)

    // Not running at all: `open` does not need Accessibility.
    guard let app = app(for: target.bundle) else {
        return .open(target)
    }

    // No Accessibility permission means no window titles and no geometry. The
    // hotkey still does something useful (Activation does not need it) instead
    // of silently doing nothing.
    guard trusted else { return .activateOnly(app) }

    if forceNewWindow { return .open(target) }

    guard let window = windows(of: app).first(where: { titleMatches($0, target.titleSuffix) }) else {
        return .open(target)
    }

    // Smart toggle: if the window is already the active one, hide the app again.
    // Same as Raycast's app hotkey with "Toggle Visibility" (`Cmd+H`).
    // A hidden app still owns the menu bar, so `isHidden` has to be part of the
    // check — otherwise hiding could never be undone.
    let isActive = allowHide
        && !app.isHidden
        && isFrontmostApp(target.bundle)
        && focusedWindow(of: app).map { titleMatches($0, target.titleSuffix) } == true

    return isActive ? .hide(app) : .focus(app, window, target.titleSuffix)
}

func focus(app: NSRunningApplication, window: AXUIElement, suffix: String?, label: String, activateApp: Bool) {
    let startedAt = CFAbsoluteTimeGetCurrent()

    if app.isHidden { app.unhide() }
    if boolAttribute(window, kAXMinimizedAttribute) {
        setBoolAttribute(window, kAXMinimizedAttribute, false)
    }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    // Activating the app raises every window of it in every Space. When the
    // caller wants only this window in front (the other profile is on another
    // display), skip the activation and let Accessibility do the work.
    if activateApp {
        // Activate the app first, then bring this exact window forward: activating
        // lets Brave focus its own last used window.
        app.activate(options: [])
    }

    for _ in 0..<4 {
        setBoolAttribute(window, kAXMainAttribute, true)
        setBoolAttribute(window, kAXFocusedAttribute, true)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, window)
        usleep(80_000)
        if isFocused(app: app, window: window, suffix: suffix) {
            note("\(label): focused in \(milliseconds(since: startedAt))\(activateApp ? "" : " (window only)")")
            return
        }
    }

    // Brave ignores the raise while it is busy (page load, waking up, a sheet).
    // Making the window main as well is the last thing left to try.
    setBoolAttribute(window, kAXMainAttribute, true)
    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    note("\(label): focus not confirmed after \(milliseconds(since: startedAt)), applied the main-window fallback")
}

func openNewWindow(_ target: Target, label: String) {
    // Remember which windows already exist, so the new one can be picked out
    // (right after opening, the app still reports the old window as focused).
    let before = app(for: target.bundle).map { windows(of: $0) } ?? []

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-na", target.appName, "--args", "--profile-directory=\(target.profileDir)"]
    try? process.run()
    process.waitUntilExit()

    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
        guard let app = app(for: target.bundle) else { usleep(50_000); continue }
        let fresh = windows(of: app).first { window in
            !before.contains { CFEqual($0, window) }
                && titleMatches(window, target.titleSuffix)
                && !boolAttribute(window, kAXMinimizedAttribute)
        }
        if let fresh {
            debug("new window: \(stringAttribute(fresh, kAXTitleAttribute))")
            waitUntilStable(fresh)
            maximizeWithGap(fresh)
            return
        }
        usleep(50_000)
    }
    note("\(label): new window did not appear")
}

func execute(_ work: Work, profileKey: String) {
    switch work {
    case .hide(let app):
        note("\(profileKey): hiding (its window is already in front)")
        app.hide()
    case .focus(let app, let window, let suffix):
        focus(app: app, window: window, suffix: suffix, label: profileKey, activateApp: !windowOnly)
    case .activateOnly(let app):
        note("\(profileKey): no accessibility permission, activating the app only")
        if app.isHidden { app.unhide() }
        app.activate(options: [])
    case .open(let target):
        note("\(profileKey): opening a new window in \(target.appName)")
        openNewWindow(target, label: profileKey)
    case .fail(let reason):
        note("\(profileKey): nothing to do (\(reason))")
    }
}

// ---------------------------------------------------------------------------
// daemon (keeps the Accessibility connection to Brave warm)
// ---------------------------------------------------------------------------

func socketPath() -> String {
    supportDirectory() + "/sock"
}

func pidPath() -> String {
    supportDirectory() + "/pid"
}

func lockPath() -> String {
    supportDirectory() + "/lock"
}

func executablePath() -> String {
    URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
}

/// True when a daemon is actually listening on the socket (a leftover socket
/// file from a killed daemon does not count).
func daemonIsListening() -> Bool {
    let path = socketPath()
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = Array(path.utf8)
    guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return false }
    withUnsafeMutableBytes(of: &address.sun_path) { raw in raw.copyBytes(from: pathBytes) }

    return withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    } == 0
}

/// Starts the daemon in the background unless something already listens.
func startDaemon() {
    guard !daemonIsListening() else { return }
    unlink(socketPath())
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "nohup '\(executablePath())' --serve >/dev/null 2>&1 &"]
    try? process.run()
    process.waitUntilExit()
}

/// Only one daemon may own the socket; a second one (two hotkeys racing on a
/// cold start) would bind-fail and leave a socket file behind.
func acquireDaemonLock() -> Int32? {
    let fd = open(lockPath(), O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else { return nil }
    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
        close(fd)
        return nil
    }
    return fd
}

func removeRuntimeFiles() {
    unlink(socketPath())
    try? FileManager.default.removeItem(atPath: pidPath())
}

func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let offset = Int(fd / 32)
    let mask = Int32(1) << (fd % 32)
    withUnsafeMutablePointer(to: &set) { pointer in
        pointer.withMemoryRebound(to: Int32.self, capacity: 4) { $0[offset] |= mask }
    }
}

func fdIsSet(_ fd: Int32, _ set: inout fd_set) -> Bool {
    let offset = Int(fd / 32)
    let mask = Int32(1) << (fd % 32)
    return withUnsafeMutablePointer(to: &set) { pointer in
        pointer.withMemoryRebound(to: Int32.self, capacity: 4) { ($0[offset] & mask) != 0 }
    }
}

func reply(_ fd: Int32, _ text: String) {
    _ = text.withCString { write(fd, $0, strlen($0)) }
}

/// Accept loop on a background thread, so the main thread can pump the run loop
/// that keeps `NSWorkspace` (and therefore the frontmost app) up to date.
func serveConnections(serverFD: Int32) -> Never {
    let startedAt = Date()
    var lastActivity = Date()

    while true {
        var readSet = fd_set()
        fdSet(serverFD, &readSet)
        var timeout = timeval(tv_sec: 120, tv_usec: 0)
        let ready = withUnsafeMutablePointer(to: &readSet) { pointer in
            select(serverFD + 1, pointer, nil, nil, &timeout)
        }

        if Date().timeIntervalSince(lastActivity) > DAEMON_IDLE_TIMEOUT {
            note("idle timeout, exiting")
            removeRuntimeFiles()
            exit(0)
        }

        // Rebuilt binary? Hand over the next press to the new version.
        if let attributes = try? FileManager.default.attributesOfItem(atPath: executablePath()),
           let modified = attributes[.modificationDate] as? Date,
           modified > startedAt {
            note("binary replaced, exiting")
            removeRuntimeFiles()
            exit(0)
        }

        guard ready > 0, fdIsSet(serverFD, &readSet) else { continue }

        let clientFD = accept(serverFD, nil, nil)
        guard clientFD >= 0 else { continue }

        var buffer = [UInt8](repeating: 0, count: 128)
        let count = read(clientFD, &buffer, buffer.count)
        let request = count > 0
            ? String(decoding: buffer[0..<count], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        lastActivity = Date()

        if request == "stop" {
            reply(clientFD, "ok\n")
            close(clientFD)
            note("stop requested, exiting")
            removeRuntimeFiles()
            exit(0)
        }

        var forceNew = false
        var key: String?
        if !request.isEmpty {
            let parts = request.split(separator: " ")
            forceNew = parts.first == "new"
            let candidate = forceNew ? String(parts.dropFirst().first ?? "") : String(parts.first ?? "")
            if !candidate.isEmpty { key = candidate }
        }

        guard let key else {
            reply(clientFD, "error:bad-request\n")
            close(clientFD)
            continue
        }

        let work = plan(profileKey: key, forceNewWindow: forceNew, prompt: false, allowHide: true)
        if case .fail(let reason) = work {
            note("\(key): refusing the request (\(reason))")
            reply(clientFD, "error:\(reason)\n")
            close(clientFD)
            continue
        }

        // Answer before doing the work: a cold launch (or opening a window) takes
        // seconds, and the client must never time out and re-run the action.
        reply(clientFD, "ok\n")
        close(clientFD)
        execute(work, profileKey: key)
    }
}

func runServer() -> Never {
    isDaemon = true

    guard let lockFD = acquireDaemonLock() else {
        note("another daemon already owns the socket, exiting")
        exit(0)
    }
    _ = lockFD

    if ensureAccessibility(prompt: false) {
        note("accessibility ok")
    } else {
        note("no accessibility permission: only app activation is possible")
    }

    let path = socketPath()
    unlink(path)

    let serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
    guard serverFD >= 0 else {
        note("socket() failed")
        exit(1)
    }

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = Array(path.utf8)
    guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
        note("socket path too long")
        exit(1)
    }
    withUnsafeMutableBytes(of: &address.sun_path) { raw in raw.copyBytes(from: pathBytes) }

    let bound = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(serverFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard bound == 0, listen(serverFD, 8) == 0 else {
        note("bind/listen failed")
        exit(1)
    }
    chmod(path, 0o600)

    note("serving on \(path)")
    try? "\(getpid())".write(toFile: pidPath(), atomically: true, encoding: .utf8)

    // The tracker needs a pumping run loop, the socket must not block it.
    // App Nap would coalesce the tracker timer; a 5-minute-stale frontmost app
    // would bring back exactly the bug this daemon exists to avoid.
    activityToken = ProcessInfo.processInfo.beginActivity(
        options: .userInitiatedAllowingIdleSystemSleep,
        reason: "brave-focus keeps the frontmost app fresh for the browser hotkeys"
    )
    ActiveAppTracker.shared.startPolling()
    Thread.detachNewThread { serveConnections(serverFD: serverFD) }

    RunLoop.main.run()
    removeRuntimeFiles()
    exit(0)
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

var forceNewWindow = false
var profileKey: String?

for argument in CommandLine.arguments.dropFirst() {
    switch argument {
    case "--serve":
        runServer()
    case "--new-window":
        forceNewWindow = true
    case "--window-only":
        windowOnly = true
    default:
        profileKey = argument
    }
}

guard let profileKey else {
    FileHandle.standardError.write("usage: brave-focus [--new-window] <work|personal>\n".data(using: .utf8)!)
    exit(2)
}

// A client lives for a fraction of a second and never pumps a run loop, so the
// single sample taken here is the only one available — and the only one needed.
ActiveAppTracker.shared.sample()

let work = plan(profileKey: profileKey, forceNewWindow: forceNewWindow, prompt: true, allowHide: false)
if case .fail(let reason) = work {
    note("\(profileKey): cannot act (\(reason))")
    exit(2)
}
execute(work, profileKey: profileKey)
startDaemon()
exit(0)
