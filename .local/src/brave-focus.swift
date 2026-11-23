import Cocoa
import ApplicationServices
import Darwin

// Brave profile tool:
//   brave-focus <work|personal>              focus the profile's window,
//                                            press again (while it is active) to hide it
//   brave-focus --new-window <work|personal> always open a new window
//   brave-focus --serve                      internal: warm daemon for the socket
//
// Brave titles its windows "<page title> - Brave - <profile name>", which is the
// only way to tell profiles apart: Chromium exposes nothing else to the CLI.
//
// The first Accessibility call into Brave costs tens of milliseconds (connection
// setup), so the hotkey goes through a small daemon that keeps it warm: the
// script talks to it over a unix socket and only pays the cold start once.

// ---------------------------------------------------------------------------
// configuration
// ---------------------------------------------------------------------------

let BRAVE_BUNDLE = "com.brave.Browser"

let DEBUG = ProcessInfo.processInfo.environment["BRAVE_FOCUS_DEBUG"] == "1"

func debug(_ message: @autoclosure () -> String) {
    guard DEBUG else { return }
    FileHandle.standardError.write(("[brave-focus] " + message() + "\n").data(using: .utf8)!)
}

/// key -> (profile directory, profile name as Brave shows it)
let PROFILES: [String: (dir: String, name: String)] = [
    "work": (dir: "Profile 1", name: "Work"),
    "personal": (dir: "Default", name: "Personal"),
]

/// Gap left around a maximized window — matches Raycast's window management.
let WINDOW_GAP: CGFloat = 8

/// Idle time after which the helper daemon exits.
let DAEMON_IDLE_TIMEOUT: TimeInterval = 4 * 60 * 60

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
/// The daemon runs long enough to see the activation that happened before
/// Raycast put its panel up.
final class ActiveAppTracker {
    static let shared = ActiveAppTracker()

    private let lock = NSLock()
    private var bundle: String?

    var lastNonLauncherBundle: String? {
        lock.lock()
        defer { lock.unlock() }
        return bundle
    }

    func record(_ bundleId: String?) {
        guard let bundleId, !LAUNCHER_BUNDLES.contains(bundleId) else { return }
        lock.lock()
        bundle = bundleId
        lock.unlock()
    }

    func start() {
        record(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: queue
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            ActiveAppTracker.shared.record(app?.bundleIdentifier)
        }
    }
}

/// Owner of the frontmost normal window on screen — used only as a fallback
/// when no history is available (first press after login).
func frontmostWindowOwner() -> String? {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    for info in list {
        guard (info[kCGWindowLayer as String] as? Int ?? 0) == 0 else { continue }
        let owner = info[kCGWindowOwnerName as String] as? String ?? ""
        if ["Raycast", "Alfred", "Spotlight"].contains(owner) { continue }
        return owner
    }
    return nil
}

/// True when Brave is the app in front.
///
/// While a hotkey command runs, the launcher panel is frontmost, so the current
/// frontmost app says nothing about what the user was actually looking at.
func braveIsFrontmostApp() -> Bool {
    let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    if frontmost == BRAVE_BUNDLE { return true }
    guard let frontmost, LAUNCHER_BUNDLES.contains(frontmost) else { return false }

    if let tracked = ActiveAppTracker.shared.lastNonLauncherBundle {
        return tracked == BRAVE_BUNDLE
    }
    return frontmostWindowOwner() == "Brave Browser"
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

func braveApp() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: BRAVE_BUNDLE).first
}

/// Reading window titles needs Accessibility permission for whichever app runs
/// this helper (Raycast, the terminal, …). Ask once, then carry on.
func ensureAccessibility() -> Bool {
    if AXIsProcessTrusted() { return true }
    let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(prompt)
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

func openNewWindow(profileDir: String, profileName: String) {
    let suffix = "- Brave - \(profileName)"

    // Remember which windows already exist, so the new one can be picked out
    // (right after opening, Brave still reports the old window as focused).
    let before = braveApp().map { windows(of: $0) } ?? []

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-na", "Brave Browser", "--args", "--profile-directory=\(profileDir)"]
    try? process.run()
    process.waitUntilExit()

    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
        guard let app = braveApp() else { usleep(50_000); continue }
        let fresh = windows(of: app).first { window in
            !before.contains { CFEqual($0, window) }
                && stringAttribute(window, kAXTitleAttribute).hasSuffix(suffix)
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
    debug("new window did not appear")
}

/// Returns 0 when handled, 2 for bad arguments.
func perform(profileKey: String, forceNewWindow: Bool) -> Int32 {
    let startedAt = CFAbsoluteTimeGetCurrent()
    func stamp(_ label: String) {
        debug("\(label): \(String(format: "%.1f ms", (CFAbsoluteTimeGetCurrent() - startedAt) * 1000))")
    }

    guard let target = PROFILES[profileKey.lowercased()] else { return 2 }
    _ = ensureAccessibility()

    let suffix = "- Brave - \(target.name)"

    guard !forceNewWindow, let app = braveApp() else {
        openNewWindow(profileDir: target.dir, profileName: target.name)
        return 0
    }
    stamp("app")

    guard let window = windows(of: app).first(where: { stringAttribute($0, kAXTitleAttribute).hasSuffix(suffix) }) else {
        openNewWindow(profileDir: target.dir, profileName: target.name)
        return 0
    }
    stamp("windows")

    // Smart toggle: if the window is already the active one, hide the app again.
    // Same as Raycast's app hotkey with "Toggle Visibility" (`Cmd+H`).
    // A hidden app still owns the menu bar, so `isHidden` has to be part of the
    // check — otherwise hiding could never be undone.
    let isActive = !app.isHidden
        && braveIsFrontmostApp()
        && focusedWindow(of: app).map { stringAttribute($0, kAXTitleAttribute).hasSuffix(suffix) } == true

    stamp("active-check")
    if isActive {
        app.hide()
        stamp("hidden")
        return 0
    }

    if app.isHidden { app.unhide() }
    if boolAttribute(window, kAXMinimizedAttribute) {
        setBoolAttribute(window, kAXMinimizedAttribute as String, false)
    }
    // Activate the app first, then bring this exact window forward: activating
    // with .activateAllWindows lets Brave focus its own last used window.
    app.activate(options: [])
    stamp("activate")

    // Unhiding makes Brave restore its own last window, so wait until it is the
    // frontmost app and then make sure the requested window is the focused one.
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    for _ in 0..<40 {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == BRAVE_BUNDLE { break }
        usleep(25_000)
    }

    for _ in 0..<3 {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, window)
        usleep(80_000)
        let focused = focusedWindow(of: app).map { stringAttribute($0, kAXTitleAttribute) } ?? ""
        if focused.hasSuffix(suffix) { break }
    }
    stamp("raised-and-focused")
    return 0
}

// ---------------------------------------------------------------------------
// daemon (keeps the Accessibility connection to Brave warm)
// ---------------------------------------------------------------------------

func socketPath() -> String {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/brave-focus").path
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir + "/sock"
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

func runServer() -> Never {
    ActiveAppTracker.shared.start()
    guard ensureAccessibility() else {
        debug("no accessibility permission, daemon exits")
        exit(1)
    }

    let path = socketPath()
    unlink(path)

    let serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
    guard serverFD >= 0 else { exit(1) }

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = Array(path.utf8)
    guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else { exit(1) }
    withUnsafeMutableBytes(of: &address.sun_path) { raw in raw.copyBytes(from: pathBytes) }

    let bound = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(serverFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }
    guard bound == 0, listen(serverFD, 8) == 0 else { exit(1) }
    chmod(path, 0o600)
    debug("serving on \(path)")

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
            debug("idle timeout, exiting")
            unlink(path)
            exit(0)
        }

        // Rebuilt binary? Hand over the next press to the new version.
        if let attributes = try? FileManager.default.attributesOfItem(atPath: executablePath()),
           let modified = attributes[.modificationDate] as? Date,
           modified > startedAt {
            debug("binary replaced, exiting")
            unlink(path)
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
        var key: String?
        var forceNew = false

        if request == "stop" {
            write(clientFD, "ok\n", 3)
            close(clientFD)
            unlink(path)
            exit(0)
        } else if !request.isEmpty {
            let parts = request.split(separator: " ")
            forceNew = parts.first == "new"
            let candidate = forceNew ? String(parts.dropFirst().first ?? "") : String(parts.first ?? "")
            if !candidate.isEmpty { key = candidate }
        }

        guard let key else {
            _ = "error\n".withCString { write(clientFD, $0, strlen($0)) }
            close(clientFD)
            continue
        }

        // Answer before doing the work: a cold launch (or opening a window) takes
        // seconds, and the client must never time out and re-run the action.
        _ = "ok\n".withCString { write(clientFD, $0, strlen($0)) }
        close(clientFD)
        _ = perform(profileKey: key, forceNewWindow: forceNew)
    }
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
    default:
        profileKey = argument
    }
}

guard let profileKey else {
    FileHandle.standardError.write("usage: brave-focus [--new-window] <work|personal>\n".data(using: .utf8)!)
    exit(2)
}

let status = perform(profileKey: profileKey, forceNewWindow: forceNewWindow)
startDaemon()
exit(status)
