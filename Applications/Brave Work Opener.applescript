-- Brave Work Opener
--
-- Tracked in the dotfiles repo. After editing, rebuild and re-register:
--   osacompile -o ~/Applications/Brave\ Work\ Opener.app \
--     ~/Applications/Brave\ Work\ Opener.applescript
--   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
--     -f ~/Applications/Brave\ Work\ Opener.app
--
-- Finicky sends work URLs here instead of straight to Brave, because Brave
-- (Chromium) opens a NEW window when the last active Brave window is an
-- app-mode/PWA window (ClickUp, Home Assistant, Positive Intelligence …):
-- an app window cannot host a normal tab, so Chromium creates a fresh window.
--
-- Fix: raise an existing normal Brave window first, so Chromium's "last active
-- browser" is a real browser window and the URL lands in it as a tab.
-- A new window is only created when Brave is not running or has no normal
-- window left (i.e. only app windows) — which is the wanted behaviour.

property workProfileSwitch : "--profile-directory=Profile 1"
property braveBundleId : "com.brave.Browser"

on open location theURL
	openInWorkBrowser(theURL)
end open location

-- A file:// URL (Finder double-click, `open -a … file://…`) is delivered by
-- LaunchServices as an opened document, not as an `open location` event, so
-- without this handler the applet launches, ignores the event and quits.
on open theDocs
	repeat with theDoc in theDocs
		openInWorkBrowser("file://" & (POSIX path of theDoc))
	end repeat
end open

on openInWorkBrowser(theURL)
	if application "Brave Browser" is running then
		try
			tell application "Brave Browser"
				-- App-mode/PWA windows report an empty title; normal browser
				-- windows always report their active tab's title.
				set targetIndex to 0
				repeat with i from 1 to count of windows
					if (title of window i as text) is not "" then
						set targetIndex to i
						exit repeat
					end if
				end repeat
				if targetIndex > 0 then
					set index of window targetIndex to 1
					activate
				end if
			end tell
			delay 0.15
		end try
	end if

	do shell script "open -b " & quoted form of braveBundleId & ¬
		" -n --args " & quoted form of workProfileSwitch & ¬
		" " & quoted form of theURL
end openInWorkBrowser
