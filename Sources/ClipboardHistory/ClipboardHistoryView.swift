import SwiftUI
import AppKit

struct ClipboardHistoryView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @State private var search = ""
    @State private var selectedIndex = 0
    @State private var keyMonitor: Any?

    var onPaste: (ClipboardItem) -> Void
    var onClose: () -> Void

    // Sezioni filtrate (pinnati sempre prima)
    var filteredPinned: [ClipboardItem] {
        let pinned = monitor.items.filter { $0.pinned }
        guard !search.isEmpty else { return pinned }
        return pinned.filter { matchesSearch($0) }
    }

    var filteredUnpinned: [ClipboardItem] {
        let unpinned = monitor.items.filter { !$0.pinned }
        guard !search.isEmpty else { return unpinned }
        return unpinned.filter { matchesSearch($0) }
    }

    var filtered: [ClipboardItem] { filteredPinned + filteredUnpinned }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            Divider()
            itemList
        }
        .frame(width: 380, height: 520)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { installKeyMonitor(); selectedIndex = 0 }
        .onDisappear { removeKeyMonitor() }
        .onChange(of: monitor.items) { _ in selectedIndex = 0 }
        .onChange(of: search) { _ in selectedIndex = 0 }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.secondary)
            Text("Cronologia Appunti")
                .font(.headline)
            Spacer()
            if monitor.items.contains(where: { !$0.pinned }) {
                Button("Cancella cronologia") { monitor.clearAll() }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Cerca...", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
    }

    @ViewBuilder
    private var itemList: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        // Sezione Fissati
                        if !filteredPinned.isEmpty {
                            sectionHeader("📌  Fissati")
                            ForEach(Array(filteredPinned.enumerated()), id: \.element.id) { i, item in
                                row(for: item, flatIndex: i)
                            }
                        }

                        // Sezione Recenti
                        if !filteredUnpinned.isEmpty {
                            sectionHeader(filteredPinned.isEmpty ? "🕐  Recenti" : "🕐  Recenti")
                            ForEach(Array(filteredUnpinned.enumerated()), id: \.element.id) { i, item in
                                row(for: item, flatIndex: filteredPinned.count + i)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedIndex) { idx in
                    guard idx < filtered.count else { return }
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(filtered[idx].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func row(for item: ClipboardItem, flatIndex: Int) -> some View {
        ItemRow(
            item: item,
            isSelected: flatIndex == selectedIndex,
            onPin: { monitor.togglePin(item) }
        )
        .id(item.id)
        .onTapGesture { onPaste(item) }
        .onHover { if $0 { selectedIndex = flatIndex } }
        .contextMenu {
            Button("Incolla") { onPaste(item) }
            Button(item.pinned ? "Rimuovi fissa" : "Fissa") { monitor.togglePin(item) }
            Divider()
            Button("Rimuovi") { monitor.remove(item) }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(search.isEmpty ? "Nessun elemento copiato" : "Nessun risultato")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func matchesSearch(_ item: ClipboardItem) -> Bool {
        if case .text(let s) = item.content {
            return s.localizedCaseInsensitiveContains(search)
        }
        return false
    }

    // MARK: - Key handling

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch Int(event.keyCode) {
            case 53: // ESC
                onClose()
                return nil
            case 125: // ↓
                if selectedIndex < filtered.count - 1 { selectedIndex += 1 }
                return nil
            case 126: // ↑
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 36, 76: // Return / Enter numpad
                if selectedIndex < filtered.count { onPaste(filtered[selectedIndex]) }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}

// MARK: - Row

struct ItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    var onPin: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            typeIcon
            contentPreview
            Spacer()
            pinButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }

    private var rowBackground: Color {
        if item.pinned {
            return isSelected
                ? Color.yellow.opacity(0.25)
                : Color.yellow.opacity(0.08)
        }
        return isSelected ? Color.accentColor.opacity(0.3) : Color.clear
    }

    @ViewBuilder
    private var typeIcon: some View {
        switch item.content {
        case .text:
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
                .frame(width: 18)
        case .image:
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            switch item.content {
            case .text(let str):
                Text(str)
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            case .image(let img):
                HStack(spacing: 8) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 48)
                    Text("Immagine")
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var pinButton: some View {
        Button(action: onPin) {
            Image(systemName: item.pinned ? "pin.fill" : "pin")
                .font(.system(size: 11))
                .foregroundStyle(item.pinned ? Color.yellow : Color.secondary)
        }
        .buttonStyle(.plain)
        .opacity(item.pinned || hovered ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: hovered)
        .help(item.pinned ? "Rimuovi fissa" : "Fissa")
    }
}

