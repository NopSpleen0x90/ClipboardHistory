import AppKit
import Combine

class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published private(set) var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int
    private let maxUnpinned = 30
    private let storageKey = "clipboard_history_v2"

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        loadSaved()
    }

    func startMonitoring() {
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let str = pb.string(forType: .string),
           !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(ClipboardItem(text: str))
        } else if let img = NSImage(pasteboard: pb) {
            add(ClipboardItem(image: img))
        }
    }

    private func add(_ item: ClipboardItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Se il contenuto è già pinnato, non duplicare
            if self.items.contains(where: { $0.pinned && $0.contentEquals(item) }) { return }

            // Rimuovi eventuale duplicato non pinnato
            self.items.removeAll { !$0.pinned && $0.contentEquals(item) }

            // Inserisci in cima alla sezione non-pinnata (subito dopo gli elementi pinnati)
            let insertIdx = self.items.firstIndex { !$0.pinned } ?? self.items.endIndex
            self.items.insert(item, at: insertIdx)

            // Limita solo gli elementi non pinnati
            var unpinnedIdxs = self.items.indices.filter { !self.items[$0].pinned }
            while unpinnedIdxs.count > self.maxUnpinned {
                self.items.remove(at: unpinnedIdxs.removeLast())
            }
            self.save()
        }
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    /// Cancella solo gli elementi NON pinnati.
    func clearAll() {
        items.removeAll { !$0.pinned }
        save()
    }

    /// Fissa o sblocca un elemento; i pinnati vengono spostati in cima.
    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].pinned.toggle()
        // Ri-ordina: pinnati prima, poi non-pinnati (ogni gruppo mantiene l'ordine relativo)
        let pinned   = items.filter { $0.pinned }
        let unpinned = items.filter { !$0.pinned }
        items = pinned + unpinned
        save()
    }

    func paste(_ item: ClipboardItem, thenActivate app: NSRunningApplication?) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.content {
        case .text(let str):  pb.setString(str, forType: .string)
        case .image(let img): pb.writeObjects([img])
        }

        lastChangeCount = pb.changeCount

        // Sposta in cima alla sua sezione (pinnati → top pinnati; altri → top non-pinnati)
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: idx)
        }
        if item.pinned {
            items.insert(item, at: 0)
        } else {
            let insertIdx = items.firstIndex { !$0.pinned } ?? items.endIndex
            items.insert(item, at: insertIdx)
        }
        save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            app?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.sendCmdV()
            }
        }
    }

    private func sendCmdV() {
        guard AXIsProcessTrusted() else { return }
        let src = CGEventSource(stateID: .hidSystemState)
        let dn = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        dn?.flags = .maskCommand
        up?.flags = .maskCommand
        dn?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - Persistenza (JSON, include stato pinnato)

    private func save() {
        let data: [[String: Any]] = items.compactMap { item in
            guard case .text(let s) = item.content else { return nil }
            return [
                "id":        item.id.uuidString,
                "text":      s,
                "pinned":    item.pinned,
                "timestamp": item.timestamp.timeIntervalSince1970
            ]
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadSaved() {
        guard let data = UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]] else { return }
        items = data.compactMap { dict in
            guard let text = dict["text"] as? String else { return nil }
            let id        = (dict["id"] as? String).flatMap(UUID.init) ?? UUID()
            let pinned    = dict["pinned"] as? Bool ?? false
            let ts        = dict["timestamp"] as? Double ?? Date().timeIntervalSince1970
            return ClipboardItem(text: text, id: id, timestamp: Date(timeIntervalSince1970: ts), pinned: pinned)
        }
    }
}

