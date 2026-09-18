import Foundation

/// One (type, data) pair in a raw pasteboard archive. Order is significant.
struct RawBlob: Codable {
    let t: String   // pasteboard type identifier
    let d: Data     // verbatim data
}

enum ClipType: String, Codable {
    case text, url, image, file
    case raw   // catch-all: full pasteboard contents stored verbatim
}

struct Pinboard: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
}

struct ClipItem: Codable, Identifiable, Equatable {
    let id: UUID
    let type: ClipType
    var text: String?          // text/url content, file paths, or type list for raw items
    var imageFile: String?     // relative filename of stored PNG preview
    var rawFile: String?       // relative filename of verbatim pasteboard archive (catch-all)
    var rawSize: Int?          // total bytes of raw archive, for display
    var ocrText: String?       // text recognized in image items (searchable)
    var appName: String?
    var bundleID: String?
    let date: Date
    var contentHash: String
    var boards: Set<UUID>

    init(type: ClipType, text: String? = nil, imageFile: String? = nil,
         rawFile: String? = nil, rawSize: Int? = nil,
         appName: String?, bundleID: String?, contentHash: String) {
        self.id = UUID()
        self.type = type
        self.text = text
        self.imageFile = imageFile
        self.rawFile = rawFile
        self.rawSize = rawSize
        self.appName = appName
        self.bundleID = bundleID
        self.date = Date()
        self.contentHash = contentHash
        self.boards = []
    }
}
