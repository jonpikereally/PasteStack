import Foundation
import AppKit

final class Store: ObservableObject {
    @Published var items: [ClipItem] = []
    @Published var boards: [Pinboard] = []

    let maxHistory = 1000
    let baseDir: URL
    var imagesDir: URL { baseDir.appendingPathComponent("images", isDirectory: true) }
    var rawDir: URL { baseDir.appendingPathComponent("raw", isDirectory: true) }
    private var indexURL: URL { baseDir.appendingPathComponent("history.json") }
    private var boardsURL: URL { baseDir.appendingPathComponent("boards.json") }
    private var saveWork: DispatchWorkItem?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseDir = appSupport.appendingPathComponent("PasteStack", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: rawDir, withIntermediateDirectories: true)
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) {
            items = decoded
        }
        if let data = try? Data(contentsOf: boardsURL),
           let decoded = try? JSONDecoder().decode([Pinboard].self, from: data) {
            boards = decoded
        }
    }

    func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        let enc = JSONEncoder()
        if let data = try? enc.encode(items) { try? data.write(to: indexURL, options: .atomic) }
        if let data = try? enc.encode(boards) { try? data.write(to: boardsURL, options: .atomic) }
    }

    // MARK: - Items

    func add(_ item: ClipItem) {
        // Dedup: same content re-copied moves to front, keeping its board pins.
        // Blob filenames are content-derived, so matching hashes mean matching files.
        if let idx = items.firstIndex(where: { $0.contentHash == item.contentHash }) {
            let existing = items.remove(at: idx)
            var updated = item
            updated.boards = existing.boards
            if updated.ocrText == nil { updated.ocrText = existing.ocrText }
            items.insert(updated, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        trim()
        scheduleSave()
    }

    private func trim() {
        guard items.count > maxHistory else { return }
        // Never trim items pinned to a board.
        var kept: [ClipItem] = []
        var unpinnedCount = 0
        for item in items {
            if !item.boards.isEmpty {
                kept.append(item)
            } else if unpinnedCount < maxHistory {
                kept.append(item)
                unpinnedCount += 1
            } else {
                removeBlobs(of: item)
            }
        }
        items = kept
    }

    /// Delete an item's blob files, unless another item still references them.
    private func removeBlobs(of item: ClipItem) {
        if let f = item.imageFile,
           !items.contains(where: { $0.id != item.id && $0.imageFile == f }) {
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(f))
        }
        if let f = item.rawFile,
           !items.contains(where: { $0.id != item.id && $0.rawFile == f }) {
            try? FileManager.default.removeItem(at: rawDir.appendingPathComponent(f))
        }
    }

    func delete(_ item: ClipItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            let removed = items.remove(at: idx)
            removeBlobs(of: removed)
            scheduleSave()
        }
    }

    func clearHistory() {
        let goners = items.filter { $0.boards.isEmpty }
        items.removeAll { $0.boards.isEmpty }
        for item in goners { removeBlobs(of: item) }
        scheduleSave()
    }

    // MARK: - Boards

    @discardableResult
    func addBoard(named name: String) -> Pinboard {
        let board = Pinboard(id: UUID(), name: name)
        boards.append(board)
        scheduleSave()
        return board
    }

    func deleteBoard(_ board: Pinboard) {
        boards.removeAll { $0.id == board.id }
        for idx in items.indices { items[idx].boards.remove(board.id) }
        scheduleSave()
    }

    func toggle(_ item: ClipItem, in board: Pinboard) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[idx].boards.contains(board.id) {
            items[idx].boards.remove(board.id)
        } else {
            items[idx].boards.insert(board.id)
        }
        scheduleSave()
    }

    func setOCR(id: UUID, text: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].ocrText = text
        scheduleSave()
    }

    func imageURL(for item: ClipItem) -> URL? {
        guard let f = item.imageFile else { return nil }
        return imagesDir.appendingPathComponent(f)
    }
}
