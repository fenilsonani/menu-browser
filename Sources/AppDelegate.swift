import AppKit
import SwiftUI
import ServiceManagement
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let browserManager = BrowserManager()
    private let preferencesState = PreferencesState()
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "MenuBrowser")
        }

        menu.delegate = self
        statusItem.menu = menu

        setupHotkey()
        preferencesState.onShortcutChanged = { [weak self] in
            self?.setupHotkey()
        }

    }

    private func setupHotkey() {
        let keyCode = UInt32(preferencesState.shortcutKeyCode)
        let modifiers = carbonModifiers(from: preferencesState.shortcutModifiers)

        HotkeyManager.shared.register(keyCode: keyCode, carbonModifiers: modifiers)
        HotkeyManager.shared.onHotKey = { [weak self] in
            self?.statusItem.button?.performClick(nil)
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let allBrowsers = browserManager.installedBrowsers()
        let browsers = preferencesState.orderedBrowsers(from: allBrowsers)
        let defaultID = browserManager.defaultBrowserBundleID()

        for (index, browser) in browsers.enumerated() {
            let item = NSMenuItem(
                title: browser.name,
                action: #selector(browserSelected(_:)),
                keyEquivalent: index < 9 ? "\(index + 1)" : ""
            )
            item.target = self
            item.image = browser.icon
            item.representedObject = browser

            if browser.bundleIdentifier.caseInsensitiveCompare(defaultID ?? "") == .orderedSame {
                item.state = .on
            }

            menu.addItem(item)
        }

        menu.addItem(.separator())

        let shortcutHint = NSMenuItem(
            title: "Open with \(preferencesState.shortcutDisplay)",
            action: nil,
            keyEquivalent: ""
        )
        shortcutHint.isEnabled = false
        menu.addItem(shortcutHint)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(
            title: "Quit MenuBrowser",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func browserSelected(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? BrowserInfo else { return }
        browserManager.setDefaultBrowser(browser)
    }

    @objc private func showPreferences() {
        preferencesState.refreshBrowsers(using: browserManager)

        if preferencesWindow == nil {
            let view = PreferencesView(state: preferencesState)
            let hostingView = NSHostingView(rootView: view)

            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = hostingView
            window.center()
            window.isReleasedWhenClosed = false

            preferencesWindow = window
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
