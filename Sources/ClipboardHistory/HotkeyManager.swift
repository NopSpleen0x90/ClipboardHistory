import AppKit

/// Global hotkey manager using NSEvent (sandbox-compatible, no Carbon dependency).
/// Monitors ⌘⇧V system-wide; requires Accessibility permission granted by the user.
class HotkeyManager {
    private var monitor: Any?

    func register(handler: @escaping () -> Void) {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // keyCode 9 = kVK_ANSI_V; ignore Control and Option to avoid collisions
            let relevant: NSEvent.ModifierFlags = [.command, .shift, .control, .option]
            guard event.keyCode == 9,
                  event.modifierFlags.intersection(relevant) == [.command, .shift]
            else { return }
            DispatchQueue.main.async { handler() }
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
