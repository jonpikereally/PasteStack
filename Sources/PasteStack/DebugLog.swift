import Foundation

/// Diagnostic log at ~/Library/Application Support/PasteStack/debug.log.
/// Off by default because entries include the start of clipboard items. Turn on with:
///   defaults write com.jonpike.pastestack debugLogging -bool true
enum DebugLog {
    static let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteStack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("debug.log")
    }()

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    static func log(_ msg: String) {
        guard UserDefaults.standard.bool(forKey: "debugLogging") else { return }
        let line = "\(df.string(from: Date())) \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    static func describe(_ item: ClipItem) -> String {
        let preview = (item.text ?? "<no text>").prefix(30).replacingOccurrences(of: "\n", with: "␤")
        return "[\(item.id.uuidString.prefix(8)) \(item.type.rawValue) '\(preview)']"
    }
}
