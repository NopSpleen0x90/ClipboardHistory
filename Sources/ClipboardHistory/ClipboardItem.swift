import Foundation
import AppKit

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    var pinned: Bool

    init(text: String) {
        id = UUID()
        content = .text(text)
        timestamp = Date()
        pinned = false
    }

    init(image: NSImage) {
        id = UUID()
        content = .image(image)
        timestamp = Date()
        pinned = false
    }

    // Usato per caricare dallo storage
    init(text: String, id: UUID, timestamp: Date, pinned: Bool) {
        self.id = id
        self.content = .text(text)
        self.timestamp = timestamp
        self.pinned = pinned
    }

    func contentEquals(_ other: ClipboardItem) -> Bool {
        if case .text(let a) = content, case .text(let b) = other.content {
            return a == b
        }
        return false
    }

    var previewText: String {
        switch content {
        case .text(let s): return s
        case .image: return "📷 Immagine"
        }
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool { lhs.id == rhs.id }
}

enum ClipboardContent {
    case text(String)
    case image(NSImage)
}
