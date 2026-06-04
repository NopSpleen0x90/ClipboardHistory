import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var panelController: PanelController?
    let hotkeyManager = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        ClipboardMonitor.shared.startMonitoring()
        panelController = PanelController()

        hotkeyManager.register {
            self.panelController?.toggle()
        }

        requestAccessibilityIfNeeded()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Clipboard History"
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Mostra Cronologia  ⌘⇧V", action: #selector(showPanel), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Cancella tutto", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func showPanel() { panelController?.show() }

    @objc func clearHistory() { ClipboardMonitor.shared.clearAll() }

    private func requestAccessibilityIfNeeded() {
        if !AXIsProcessTrusted() {
            let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }
}
