import AppKit
import SwiftUI

// NSPanel custom per ricevere eventi tastiera
class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

class PanelController: NSObject, NSWindowDelegate {
    private var panel: ClipboardPanel?
    private(set) var previousApp: NSRunningApplication?
    private var isPasting = false

    override init() {
        super.init()
        buildPanel()
    }

    private func buildPanel() {
        let p = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.hasShadow = true
        p.backgroundColor = .clear
        p.isOpaque = false
        p.delegate = self

        let view = ClipboardHistoryView(
            monitor: ClipboardMonitor.shared,
            onPaste: { [weak self] item in
                self?.handlePaste(item)
            },
            onClose: { [weak self] in
                self?.hideAndRestore()
            }
        )

        p.contentViewController = NSHostingController(rootView: view)
        self.panel = p
    }

    func toggle() {
        if panel?.isVisible == true {
            hideAndRestore()
        } else {
            show()
        }
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        guard let panel, let screen = NSScreen.main else { return }

        let pw: CGFloat = 380, ph: CGFloat = 520
        let ox = screen.visibleFrame.midX - pw / 2
        let oy = screen.visibleFrame.midY - ph / 2
        panel.setFrame(NSRect(x: ox, y: oy, width: pw, height: ph), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func hideAndRestore() {
        hide()
        previousApp?.activate(options: .activateIgnoringOtherApps)
    }

    private func handlePaste(_ item: ClipboardItem) {
        isPasting = true
        let app = previousApp
        hide()
        ClipboardMonitor.shared.paste(item, thenActivate: app)
        // Reset flag dopo che la sequenza async è stata schedulata
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isPasting = false
        }
    }

    // NSWindowDelegate: si chiude quando perde il focus (click fuori)
    func windowDidResignKey(_ notification: Notification) {
        guard !isPasting else { return }
        hide()
        previousApp?.activate(options: .activateIgnoringOtherApps)
    }
}
