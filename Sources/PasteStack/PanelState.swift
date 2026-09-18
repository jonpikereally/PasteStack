import AppKit
import Combine

final class PanelState: ObservableObject {
    @Published var query: String = ""
    @Published var selection: Int = 0
    @Published var activeBoard: UUID? = nil   // nil = full history
    /// Card to scroll into view. Set ONLY by keyboard navigation — clicks
    /// must never trigger a scroll, or the wall slides under the cursor.
    @Published var scrollTarget: UUID? = nil

    let store: Store
    weak var controller: PanelController?
    private var cancellables: Set<AnyCancellable> = []

    init(store: Store) {
        self.store = store
        // Reset selection whenever the filter changes.
        $query.sink { [weak self] _ in self?.selection = 0 }.store(in: &cancellables)
        $activeBoard.sink { [weak self] _ in self?.selection = 0 }.store(in: &cancellables)
    }

    var filteredItems: [ClipItem] {
        var result = store.items
        if let board = activeBoard {
            result = result.filter { $0.boards.contains(board) }
        }
        let tokens = query.lowercased()
            .split(whereSeparator: { $0 == " " })
            .map(String.init)
        if !tokens.isEmpty {
            result = result.filter { item in
                let blob = Self.searchBlob(for: item)
                return tokens.allSatisfy { blob.contains($0) }
            }
        }
        return result
    }

    /// Everything searchable about an item: content, OCR'd image text, source
    /// app, kind keywords ("image", "pdf", "link"…), and date words
    /// ("today", "yesterday", "monday", "august 24"…).
    static func searchBlob(for item: ClipItem) -> String {
        var parts: [String] = []
        if let t = item.text { parts.append(t.lowercased()) }
        if let t = item.ocrText { parts.append(t.lowercased()) }
        if let a = item.appName { parts.append(a.lowercased()) }

        switch item.type {
        case .text:
            parts.append("text")
        case .url:
            parts.append("link url web")
            if let host = URL(string: item.text ?? "")?.host {
                parts.append(host.lowercased())
            }
        case .image:
            parts.append("image picture screenshot photo")
        case .file:
            parts.append("file")
            for path in (item.text ?? "").split(separator: "\n") {
                let ext = URL(fileURLWithPath: String(path)).pathExtension.lowercased()
                if !ext.isEmpty { parts.append(ext) }
            }
        case .raw:
            parts.append("data app")
        }

        parts.append(dateWords(for: item.date))
        return parts.joined(separator: " ")
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE MMMM MMM d"   // e.g. "Friday August Aug 28"
        return df
    }()

    static func dateWords(for date: Date) -> String {
        var words = dateFormatter.string(from: date).lowercased()
        let cal = Calendar.current
        if cal.isDateInToday(date) { words += " today" }
        if cal.isDateInYesterday(date) { words += " yesterday" }
        return words
    }

    /// Section label for the day-grouped card wall.
    static func dayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let df = DateFormatter()
        df.dateFormat = cal.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "EEEE, MMM d" : "EEEE, MMM d, yyyy"
        return df.string(from: date)
    }

    var selectedItem: ClipItem? {
        let items = filteredItems
        guard items.indices.contains(selection) else { return items.first }
        return items[selection]
    }

    /// Click bookkeeping for our own double-click detection (SwiftUI's
    /// count:2 gesture window is stricter than the user's system setting).
    var lastClick: (id: UUID, time: Date)? = nil

    /// Returns true when this click completes a double-click on the same card,
    /// honoring the user's system double-click speed.
    func registerClick(id: UUID) -> Bool {
        let now = Date()
        defer { lastClick = (id, now) }
        if let last = lastClick, last.id == id,
           now.timeIntervalSince(last.time) <= NSEvent.doubleClickInterval {
            lastClick = nil
            return true
        }
        return false
    }

    /// Select by item identity, resolved at event time — immune to stale
    /// indices captured in view closures.
    func select(id: UUID) {
        if let i = filteredItems.firstIndex(where: { $0.id == id }) {
            selection = i
        }
    }

    func moveSelection(by delta: Int) {
        let items = filteredItems
        guard !items.isEmpty else { return }
        selection = min(max(selection + delta, 0), items.count - 1)
        scrollTarget = items[selection].id
    }

    func reset() {
        query = ""
        selection = 0
    }
}
