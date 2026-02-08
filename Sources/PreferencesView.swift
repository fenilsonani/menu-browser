import SwiftUI
import ServiceManagement
import ApplicationServices

// MARK: - Preferences State

class PreferencesState: ObservableObject {
    @Published var shortcutKeyCode: UInt16 {
        didSet { saveShortcut() }
    }
    @Published var shortcutModifiers: NSEvent.ModifierFlags {
        didSet { saveShortcut() }
    }
    @Published var isRecording = false
    @Published var browsers: [BrowserInfo] = []
    @Published var accessibilityGranted = AXIsProcessTrusted()

    var shortcutDisplay: String {
        modifierSymbols(shortcutModifiers) + keyName(shortcutKeyCode)
    }

    var onShortcutChanged: (() -> Void)?
    private var localMonitor: Any?

    init() {
        let stored = UserDefaults.standard
        let code = stored.integer(forKey: "shortcutKeyCode")
        let mods = stored.integer(forKey: "shortcutModifiers")

        if code != 0 && mods != 0 {
            self.shortcutKeyCode = UInt16(code)
            self.shortcutModifiers = NSEvent.ModifierFlags(rawValue: UInt(mods))
        } else {
            self.shortcutKeyCode = 0x0B // B
            self.shortcutModifiers = [.command, .shift]
        }
    }

    // MARK: - Shortcut

    private func saveShortcut() {
        UserDefaults.standard.set(Int(shortcutKeyCode), forKey: "shortcutKeyCode")
        UserDefaults.standard.set(Int(shortcutModifiers.rawValue), forKey: "shortcutModifiers")
    }

    func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == 0x35 {
                self.stopRecording()
                return nil
            }

            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !mods.isEmpty else { return event }

            self.shortcutKeyCode = event.keyCode
            self.shortcutModifiers = mods
            self.stopRecording()
            self.onShortcutChanged?()
            return nil
        }
    }

    func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        isRecording = false
    }

    // MARK: - Browser Ordering

    func refreshBrowsers(using manager: BrowserManager) {
        let all = manager.installedBrowsers()
        browsers = applyOrder(to: all)
    }

    func orderedBrowsers(from all: [BrowserInfo]) -> [BrowserInfo] {
        applyOrder(to: all)
    }

    private func applyOrder(to all: [BrowserInfo]) -> [BrowserInfo] {
        let storedIDs = UserDefaults.standard.stringArray(forKey: "browserOrder") ?? []
        var ordered: [BrowserInfo] = []
        for id in storedIDs {
            if let b = all.first(where: { $0.bundleIdentifier.caseInsensitiveCompare(id) == .orderedSame }) {
                ordered.append(b)
            }
        }
        for b in all {
            if !ordered.contains(where: { $0.bundleIdentifier.caseInsensitiveCompare(b.bundleIdentifier) == .orderedSame }) {
                ordered.append(b)
            }
        }
        return ordered
    }

    private func saveOrder() {
        UserDefaults.standard.set(browsers.map { $0.bundleIdentifier }, forKey: "browserOrder")
    }

    func moveBrowser(at index: Int, up: Bool) {
        let newIndex = up ? index - 1 : index + 1
        guard newIndex >= 0 && newIndex < browsers.count else { return }
        browsers.swapAt(index, newIndex)
        saveOrder()
    }

    // MARK: - Accessibility

    private var accessibilityTimer: Timer?

    func refreshAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func startAccessibilityPolling() {
        refreshAccessibility()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshAccessibility()
        }
    }

    func stopAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Preferences View (Liquid Glass)

struct PreferencesView: View {
    @ObservedObject var state: PreferencesState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 20) {
                // Glass header capsule
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .semibold))
                    Text("MenuBrowser")
                        .font(.system(.headline, design: .rounded))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .glassEffect(.regular, in: Capsule())

                // Browsers section
                VStack(alignment: .leading, spacing: 8) {
                    Text("BROWSERS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .tracking(0.8)
                        .padding(.leading, 8)

                    VStack(spacing: 0) {
                        ForEach(Array(state.browsers.enumerated()), id: \.1.id) { index, browser in
                            HStack(spacing: 10) {
                                Image(nsImage: browser.icon)
                                Text(browser.name)
                                    .lineLimit(1)
                                Spacer()
                                if index < 9 {
                                    Text("\u{2318}\(index + 1)")
                                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 5))
                                }
                                Button { state.moveBrowser(at: index, up: true) } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(index == 0 ? .quaternary : .secondary)
                                }
                                .buttonStyle(.borderless)
                                .disabled(index == 0)

                                Button { state.moveBrowser(at: index, up: false) } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(index == state.browsers.count - 1 ? .quaternary : .secondary)
                                }
                                .buttonStyle(.borderless)
                                .disabled(index == state.browsers.count - 1)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)

                            if index < state.browsers.count - 1 {
                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(0.4)
                            }
                        }
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                }

                // General section
                VStack(alignment: .leading, spacing: 8) {
                    Text("GENERAL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .tracking(0.8)
                        .padding(.leading, 8)

                    VStack(spacing: 0) {
                        // Keyboard shortcut
                        HStack {
                            Label("Keyboard Shortcut", systemImage: "keyboard")
                            Spacer()
                            Button(action: {
                                if state.isRecording {
                                    state.stopRecording()
                                } else {
                                    state.startRecording()
                                }
                            }) {
                                Text(state.isRecording ? "Press shortcut\u{2026}" : state.shortcutDisplay)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(state.isRecording ? .secondary : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.horizontal, 16).opacity(0.4)

                        // Launch at Login
                        HStack {
                            Label("Launch at Login", systemImage: "arrow.trianglehead.clockwise")
                            Spacer()
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.horizontal, 16).opacity(0.4)

                        // Instant Switching
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("Instant Switching", systemImage: "bolt.fill")
                                Spacer()
                                if state.accessibilityGranted {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Enabled")
                                            .font(.callout.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Button(action: { state.requestAccessibility() }) {
                                        Text("Open Settings")
                                            .font(.callout.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                    }
                                    .buttonStyle(.plain)
                                    .glassEffect(.regular, in: Capsule())
                                }
                            }
                            if state.accessibilityGranted {
                                Text("Browser switching skips the confirmation dialog")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("Toggle on **MenuBrowser** in Settings \u{2192} Accessibility")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(28)
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { state.startAccessibilityPolling() }
        .onDisappear { state.stopAccessibilityPolling() }
        .onChange(of: launchAtLogin) { _, newValue in
            toggleLaunchAtLogin(newValue)
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
