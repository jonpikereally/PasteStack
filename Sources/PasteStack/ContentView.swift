import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var state: PanelState
    @ObservedObject var store: Store
    @FocusState private var searchFocused: Bool

    init(state: PanelState, store: Store) {
        self.state = state
        self.store = store
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.4)
            cardWall
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .padding(8)
        .onAppear { searchFocused = true }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search content, kind, app, or day…", text: $state.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .frame(width: 240)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            boardTabs

            Spacer()

            Text("← → navigate · ↩ paste · ⇧↩ plain text · esc close")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var boardTabs: some View {
        HStack(spacing: 4) {
            tab(label: "History", icon: "clock", id: nil)
            ForEach(store.boards) { board in
                tab(label: board.name, icon: "pin.fill", id: board.id)
                    .contextMenu {
                        Button("Delete Pinboard \"\(board.name)\"", role: .destructive) {
                            store.deleteBoard(board)
                            if state.activeBoard == board.id { state.activeBoard = nil }
                        }
                    }
            }
            Button {
                state.controller?.promptNewBoard()
            } label: {
                Image(systemName: "plus").font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .padding(6)
            .help("New pinboard")
        }
    }

    private func tab(label: String, icon: String, id: UUID?) -> some View {
        let active = state.activeBoard == id
        return Button {
            state.activeBoard = id
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.callout)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(active ? Color.accentColor.opacity(0.25) : Color.clear,
                        in: Capsule())
            .overlay(Capsule().strokeBorder(active ? Color.accentColor : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// One handler for all card clicks: our own double-click detection
    /// (honoring the system double-click speed) so slow double-clicks
    /// still paste instead of silently doing nothing.
    private func handleClick(_ item: ClipItem) {
        if state.registerClick(id: item.id) {
            DebugLog.log("DBLCLICK on \(DebugLog.describe(item))")
            if let live = state.filteredItems.first(where: { $0.id == item.id }) {
                state.controller?.paste(live, plain: NSEvent.modifierFlags.contains(.shift))
            }
        } else {
            DebugLog.log("CLICK on \(DebugLog.describe(item))")
            state.select(id: item.id)
        }
    }

    private var cardWall: some View {
        let items = state.filteredItems
        // Group consecutive items by calendar day (items are newest-first).
        var groups: [(String, [(Int, ClipItem)])] = []
        for (idx, item) in items.enumerated() {
            let label = PanelState.dayLabel(for: item.date)
            if groups.last?.0 != label { groups.append((label, [])) }
            groups[groups.count - 1].1.append((idx, item))
        }
        return Group {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard").font(.largeTitle).foregroundStyle(.tertiary)
                    Text(state.query.isEmpty ? "Nothing here yet — copy something!" : "No matches")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 24) {
                            ForEach(groups, id: \.0) { label, entries in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    LazyHStack(alignment: .top, spacing: 12) {
                                        ForEach(entries, id: \.1.id) { idx, item in
                                            ClipCard(item: item,
                                                     selected: idx == state.selection,
                                                     store: store,
                                                     state: state)
                                                .onTapGesture { handleClick(item) }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .onChange(of: state.scrollTarget) { target in
                        if let target {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(target, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ClipCard: View {
    let item: ClipItem
    let selected: Bool
    let store: Store
    let state: PanelState

    private var accent: Color {
        switch item.type {
        case .text: return .blue
        case .url: return .teal
        case .image: return .purple
        case .file: return .orange
        case .raw: return .indigo
        }
    }

    private var typeLabel: String {
        switch item.type {
        case .text: return "TEXT"
        case .url: return "LINK"
        case .image: return "IMAGE"
        case .file: return "FILE"
        case .raw: return "APP DATA"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header stripe
            HStack {
                Text(typeLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if item.rawFile != nil && item.type != .raw {
                    Image(systemName: "shippingbox.fill").font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                        .help("Full app data captured — pastes with complete fidelity")
                }
                if !item.boards.isEmpty {
                    Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(accent.gradient)

            // Content preview
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()

            // Footer: source app
            HStack(spacing: 6) {
                appIcon
                Text(item.appName ?? "Unknown")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text(item.date, style: .relative)
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary.opacity(0.3))
        }
        .frame(width: 190, height: 230)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        // .clipped()/.clipShape() only clip drawing, not hit-testing: an
        // overflowing image would otherwise steal clicks from neighbors.
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(selected ? accent : .white.opacity(0.1),
                          lineWidth: selected ? 2.5 : 1))
        .shadow(color: .black.opacity(selected ? 0.3 : 0.12), radius: selected ? 8 : 3, y: 2)
        .scaleEffect(selected ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: selected)
        .contextMenu { menu }
    }

    @ViewBuilder private var content: some View {
        switch item.type {
        case .image:
            if let url = store.imageURL(for: item), let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 190, height: 160)
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .file:
            if let url = store.imageURL(for: item), let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 190, height: 160)
                    .clipped()
                    .allowsHitTesting(false)
                    .overlay(alignment: .bottomLeading) {
                        // Filename badge so lookalike screenshots are distinguishable.
                        Text(URL(fileURLWithPath: item.text ?? "").lastPathComponent)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1).truncationMode(.middle)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(6)
                            .allowsHitTesting(false)
                    }
            } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach((item.text ?? "").split(separator: "\n").prefix(5), id: \.self) { path in
                    Label(URL(fileURLWithPath: String(path)).lastPathComponent,
                          systemImage: "doc")
                        .font(.caption).lineLimit(1)
                }
            }
            .padding(10)
            }
        case .url:
            Text(item.text ?? "")
                .font(.caption)
                .foregroundStyle(.teal)
                .underline()
                .padding(10)
        case .raw:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.indigo)
                    if let size = item.rawSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ForEach((item.text ?? "").split(separator: "\n").prefix(6), id: \.self) { t in
                    Text(t)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
        case .text:
            Text(item.text ?? "")
                .font(looksLikeCode ? .system(size: 10, design: .monospaced) : .system(size: 12))
                .padding(10)
        }
    }

    private var looksLikeCode: Bool {
        guard let t = item.text else { return false }
        return t.contains("\n") && (t.contains("{") || t.contains("</") || t.contains("def ") || t.contains("func "))
    }

    @ViewBuilder private var appIcon: some View {
        if let bid = item.bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable().frame(width: 14, height: 14)
        } else {
            Image(systemName: "app.dashed").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    /// File items pointing at a single image file (screenshots, copied
    /// pictures) can also paste as actual pixels.
    private var canPasteAsImage: Bool {
        if item.imageFile != nil && item.type != .image { return true }
        guard item.type == .file,
              let paths = item.text?.split(separator: "\n"), paths.count == 1
        else { return false }
        let ext = URL(fileURLWithPath: String(paths[0])).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "tiff", "tif", "heic", "webp", "bmp"].contains(ext)
    }

    @ViewBuilder private var menu: some View {
        Button("Paste") { state.controller?.paste(item) }
        if canPasteAsImage {
            Button("Paste as Image") { state.controller?.paste(item, asImage: true) }
        }
        if item.text != nil && item.type != .raw {
            Button("Paste as Plain Text") { state.controller?.paste(item, plain: true) }
        }
        Button("Copy Without Pasting") { state.controller?.copyOnly(item) }
        if item.text != nil && item.type != .raw {
            Button("Copy as Plain Text") { state.controller?.copyOnly(item, plain: true) }
        }
        Divider()
        if store.boards.isEmpty {
            Button("Pin to New Pinboard…") { state.controller?.promptNewBoard(then: item) }
        } else {
            Menu("Pinboards") {
                ForEach(store.boards) { board in
                    Button {
                        store.toggle(item, in: board)
                    } label: {
                        if item.boards.contains(board.id) {
                            Label(board.name, systemImage: "checkmark")
                        } else {
                            Text(board.name)
                        }
                    }
                }
                Divider()
                Button("New Pinboard…") { state.controller?.promptNewBoard(then: item) }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { store.delete(item) }
    }
}
