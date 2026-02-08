import AppKit
import CoreServices
import ApplicationServices

struct BrowserInfo: Identifiable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let icon: NSImage
    let appURL: URL
}

class BrowserManager {

    func installedBrowsers() -> [BrowserInfo] {
        guard let httpsURL = URL(string: "https://example.com") else { return [] }

        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: httpsURL)
        var browsers: [BrowserInfo] = []

        for appURL in appURLs {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier else { continue }

            let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? appURL.deletingPathExtension().lastPathComponent

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 18, height: 18)

            browsers.append(BrowserInfo(
                bundleIdentifier: bundleID,
                name: name,
                icon: icon,
                appURL: appURL
            ))
        }

        browsers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return browsers
    }

    func defaultBrowserBundleID() -> String? {
        guard let httpsURL = URL(string: "https://example.com") else { return nil }
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: httpsURL) else { return nil }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    func setDefaultBrowser(_ browser: BrowserInfo) {
        // Auto-confirm the system dialog in the background
        autoConfirmBrowserDialog()

        let appURL = browser.appURL
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http") { error in
            if let error = error {
                NSLog("Failed to set default browser for http: \(error)")
            }
        }
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https") { error in
            if let error = error {
                NSLog("Failed to set default browser for https: \(error)")
            }
        }
    }

    /// Requests Accessibility permission (shows system prompt if not granted).
    /// Call once at launch so auto-confirm works on first browser switch.
    func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    // Runs AppleScript to auto-click "Use [Browser]" in the CoreServicesUIAgent dialog.
    // Silently fails if Accessibility permission hasn't been granted.
    private func autoConfirmBrowserDialog() {
        DispatchQueue.global(qos: .userInteractive).async {
            let script = """
            tell application "System Events"
                tell application process "CoreServicesUIAgent"
                    repeat 20 times
                        try
                            if exists window 1 then
                                tell window 1
                                    click (first button whose name starts with "Use")
                                end tell
                            end if
                        end try
                        delay 0.3
                    end repeat
                end tell
            end tell
            """

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }
}
