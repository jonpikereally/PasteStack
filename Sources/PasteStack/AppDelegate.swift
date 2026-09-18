import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = Store()
    private(set) var monitor: ClipboardMonitor!
    private(set) var panelController: PanelController!
    private let hotKey = HotKeyManager()
    private var statusItem: NSStatusItem!
    private var pauseMenuItem: NSMenuItem!
    private var catchAllMenuItem: NSMenuItem!
    private var axMenuItem: NSMenuItem!
    private var screenshotMenuItem: NSMenuItem!
    private var loginMenuItem: NSMenuItem!
    private var updateMenuItem: NSMenuItem!
    private let screenshotWatcher = ScreenshotWatcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor = ClipboardMonitor(store: store)
        panelController = PanelController(store: store, monitor: monitor)
        monitor.start()

        hotKey.onPress = { [weak self] in self?.panelController.toggle() }
        hotKey.register()

        screenshotWatcher.onScreenshot = { [weak self] url in
            self?.monitor.ingestImageFile(url, appName: "Screenshot",
                                          bundleID: "com.apple.screencaptureui",
                                          copyToClipboard: true)
        }
        UserDefaults.standard.register(defaults: ["watchScreenshots": true])
        if UserDefaults.standard.bool(forKey: "watchScreenshots") {
            screenshotWatcher.start()
        }

        setupStatusItem()

        Updater.shared.onChange = { [weak self] in self?.refreshUpdateItem() }
        Updater.shared.startAutomaticChecks()

        // One-time nudge for the Accessibility permission that lets us auto-press Cmd+V.
        if !Paster.accessibilityTrusted {
            Paster.promptForAccessibility()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                           accessibilityDescription: "PasteStack")

        let menu = NSMenu()
        let versionItem = NSMenuItem(title: "PasteStack v\(AppVersion.version) — built \(AppVersion.built)",
                                     action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        axMenuItem = NSMenuItem(title: "", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        axMenuItem.target = self
        menu.addItem(axMenuItem)
        menu.addItem(.separator())

        let open = NSMenuItem(title: "Open PasteStack", action: #selector(openPanel), keyEquivalent: "v")
        open.keyEquivalentModifierMask = [.command, .shift]
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        pauseMenuItem = NSMenuItem(title: "Pause Capturing", action: #selector(togglePause), keyEquivalent: "")
        pauseMenuItem.target = self
        menu.addItem(pauseMenuItem)

        catchAllMenuItem = NSMenuItem(title: "Catch-All Capture (Logic, app data)",
                                      action: #selector(toggleCatchAll), keyEquivalent: "")
        catchAllMenuItem.target = self
        catchAllMenuItem.state = monitor.catchAll ? .on : .off
        menu.addItem(catchAllMenuItem)

        screenshotMenuItem = NSMenuItem(title: "Copy New Screenshots to Clipboard",
                                        action: #selector(toggleScreenshots), keyEquivalent: "")
        screenshotMenuItem.target = self
        screenshotMenuItem.state = UserDefaults.standard.bool(forKey: "watchScreenshots") ? .on : .off
        menu.addItem(screenshotMenuItem)

        loginMenuItem = NSMenuItem(title: "Open at Login",
                                   action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        loginMenuItem.target = self
        loginMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginMenuItem)

        let clear = NSMenuItem(title: "Clear History (keeps pinned)", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        menu.addItem(.separator())

        updateMenuItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateMenuItem.target = self
        menu.addItem(updateMenuItem)

        let source = NSMenuItem(title: "Update Source…", action: #selector(editUpdateSource), keyEquivalent: "")
        source.target = self
        menu.addItem(source)

        let github = NSMenuItem(title: "PasteStack on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        github.target = self
        menu.addItem(github)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit PasteStack", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        menu.autoenablesItems = false
        for item in menu.items where item.action != nil { item.isEnabled = true }
        statusItem.menu = menu
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change login item"
            alert.informativeText = error.localizedDescription
                + "\n\nYou can also add PasteStack manually in System Settings → General → Login Items."
            alert.runModal()
        }
        loginMenuItem.state = service.status == .enabled ? .on : .off
    }

    // Refresh live status each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        loginMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if Paster.accessibilityTrusted {
            axMenuItem.title = "Auto-paste: ✓ enabled"
        } else {
            axMenuItem.title = "⚠️ Auto-paste OFF — click to grant Accessibility"
        }
    }

    // MARK: - Updates

    private func refreshUpdateItem() {
        if let m = Updater.shared.available {
            updateMenuItem.title = "⬆︎ Install Update to v\(m.version)…"
            statusItem.button?.image = NSImage(systemSymbolName: "arrow.down.doc",
                                               accessibilityDescription: "PasteStack — update available")
        } else {
            updateMenuItem.title = "Check for Updates…"
            statusItem.button?.image = NSImage(
                systemSymbolName: monitor.paused ? "pause.circle" : "doc.on.clipboard",
                accessibilityDescription: "PasteStack")
        }
    }

    @objc private func checkForUpdates() {
        if let m = Updater.shared.available {
            offerInstall(m)
            return
        }
        updateMenuItem.title = "Checking for Updates…"
        Updater.shared.check { [weak self] result in
            guard let self else { return }
            self.refreshUpdateItem()
            switch result {
            case .success(let m?):
                self.offerInstall(m)
            case .success(nil):
                let alert = NSAlert()
                alert.messageText = "PasteStack is up to date"
                alert.informativeText = "You're running v\(AppVersion.version), the newest version available."
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            case .failure(let error):
                self.showUpdateError(error)
            }
        }
    }

    private func offerInstall(_ m: UpdateManifest) {
        let alert = NSAlert()
        alert.messageText = "Update to PasteStack v\(m.version)?"
        var info = "You have v\(AppVersion.version)."
        if let notes = m.notes, !notes.isEmpty { info += "\n\nWhat's new:\n\(notes)" }
        info += "\n\nPasteStack will quit, update itself and reopen. Your history and pinboards are kept."
            + "\n\nAfterwards macOS will ask you to turn Accessibility back on for PasteStack "
            + "(it asks after every update). Until you do, picking a card copies it but won't paste it for you."
        alert.informativeText = info
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        store.saveNow()
        updateMenuItem.title = "Installing Update…"
        updateMenuItem.isEnabled = false
        Updater.shared.install(m) { [weak self] error in
            self?.updateMenuItem.isEnabled = true
            self?.refreshUpdateItem()
            self?.showUpdateError(error)
        }
    }

    private func showUpdateError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn't update PasteStack"
        alert.informativeText = error.localizedDescription
        if case UpdateError.noFeed = error {
            alert.addButton(withTitle: "Set Update Source…")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { editUpdateSource() }
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func editUpdateSource() {
        let alert = NSAlert()
        alert.messageText = "Update Source"
        alert.informativeText = "Where PasteStack looks for new versions: a web link or a file path to a latest.json feed. "
            + "Leave it empty to use the built-in source"
            + (AppVersion.updateFeed.isEmpty ? " (none in this build)." : ":\n\(AppVersion.updateFeed)")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 380, height: 24))
        field.stringValue = UserDefaults.standard.string(forKey: "updateFeed") ?? ""
        field.placeholderString = AppVersion.updateFeed.isEmpty ? "https://…/latest.json" : AppVersion.updateFeed
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty && Updater.url(from: value) == nil {
            showUpdateError(UpdateError.badFeed(value))
            return
        }
        Updater.shared.feed = value
        Updater.shared.check { _ in }
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/jonpikereally/PasteStack") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAccessibilitySettings() {
        if !Paster.accessibilityTrusted { Paster.promptForAccessibility() }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openPanel() { panelController.show() }

    @objc private func toggleCatchAll() {
        monitor.catchAll.toggle()
        catchAllMenuItem.state = monitor.catchAll ? .on : .off
    }

    @objc private func toggleScreenshots() {
        let newValue = !UserDefaults.standard.bool(forKey: "watchScreenshots")
        UserDefaults.standard.set(newValue, forKey: "watchScreenshots")
        screenshotMenuItem.state = newValue ? .on : .off
        newValue ? screenshotWatcher.start() : screenshotWatcher.stop()
    }

    @objc private func togglePause() {
        monitor.paused.toggle()
        pauseMenuItem.title = monitor.paused ? "Resume Capturing" : "Pause Capturing"
        refreshUpdateItem()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Items pinned to a pinboard are kept."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearHistory()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }
}
