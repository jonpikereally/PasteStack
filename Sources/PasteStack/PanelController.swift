import AppKit
import SwiftUI

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PanelController {
    let store: Store
    let monitor: ClipboardMonitor
    let state: PanelState
    private var panel: KeyablePanel?
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    var isVisible: Bool { panel?.isVisible ?? false }

    init(store: Store, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
        self.state = PanelState(store: store)
        state.controller = self
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        state.reset()

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let height: CGFloat = 340
        let frame = NSRect(x: vf.minX, y: vf.minY, width: vf.width, height: height)

        if panel == nil {
            let p = KeyablePanel(contentRect: frame,
                                 styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                                 backing: .buffered, defer: false)
            p.level = .statusBar
            p.isFloatingPanel = true
            p.hidesOnDeactivate = false
            p.isReleasedWhenClosed = false
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.contentView = NSHostingView(rootView: ContentView(state: state, store: store))
            panel = p
        }
        panel?.setFrame(frame, display: true)
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel?.orderOut(nil)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            switch event.keyCode {
            case 53: // esc
                self.hide()
                return nil
            case 123: // left
                self.state.moveSelection(by: -1)
                return nil
            case 124: // right
                self.state.moveSelection(by: 1)
                return nil
            case 36, 76: // return / keypad enter (shift = plain text)
                if let item = self.state.selectedItem {
                    self.paste(item, plain: event.modifierFlags.contains(.shift))
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    /// Copy the item to the pasteboard, return focus to the previous app, and hit Cmd+V for the user.
    func paste(_ item: ClipItem, plain: Bool = false, asImage: Bool = false) {
        hide()
        Paster.write(item, store: store, monitor: monitor, plainText: plain, asImage: asImage)
        let target = previousApp
        target?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if Paster.accessibilityTrusted {
                Paster.sendCmdV()
            }
        }
    }

    func copyOnly(_ item: ClipItem, plain: Bool = false) {
        Paster.write(item, store: store, monitor: monitor, plainText: plain)
        hide()
    }

    func promptNewBoard(then assign: ClipItem? = nil) {
        let alert = NSAlert()
        alert.messageText = "New Pinboard"
        alert.informativeText = "Name for the new pinboard:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let board = store.addBoard(named: name)
            if let item = assign { store.toggle(item, in: board) }
        }
    }
}
