import AppKit

/// Every failure a user can run into has a stable code, so it can be looked up
/// on the public error list (ERRORS.md) or pasted into an LLM. Add new codes
/// here and to ERRORS.md together, and never show a user an error without one.
/// Codes are never reused or renumbered.
enum ErrorCode: String, CaseIterable {
    // 1xx — updates
    case noUpdateSource = "PS-101"
    case badUpdateSource = "PS-102"
    case updateSourceUnreachable = "PS-103"
    case updateServerError = "PS-104"
    case updateInfoMalformed = "PS-105"
    case updateDownloadFailed = "PS-106"
    case updateUnpackFailed = "PS-107"
    case updateMissingApp = "PS-108"
    case updateWrongApp = "PS-109"
    case updateDamagedApp = "PS-110"
    case updateInstallerFailed = "PS-111"
    case updateSwapFailed = "PS-112"
    // 2xx — login item
    case loginItemFailed = "PS-201"
    // 3xx — pasting and the shortcut
    case accessibilityMissing = "PS-301"
    case pasteKeystrokeFailed = "PS-302"
    case shortcutUnavailable = "PS-303"
    // 4xx — screenshots
    case screenshotFolderUnwatchable = "PS-401"
    // 5xx — saved data
    case dataFolderUnavailable = "PS-501"
    case historyUnreadable = "PS-502"
    case historySaveFailed = "PS-503"
    case itemSaveFailed = "PS-504"
    case itemUnreadable = "PS-505"
    // 6xx — reserved for the Install PasteStack.command script (release.sh)
    // 9xx — anything not covered above
    case unexpected = "PS-999"

    var summary: String {
        switch self {
        case .noUpdateSource: return "No update source is set."
        case .badUpdateSource: return "The update source isn't a web link or a file path."
        case .updateSourceUnreachable: return "Couldn't reach the update source."
        case .updateServerError: return "The update server returned an error."
        case .updateInfoMalformed: return "The update information is damaged or in the wrong format."
        case .updateDownloadFailed: return "Couldn't download the update."
        case .updateUnpackFailed: return "Couldn't unpack the downloaded update."
        case .updateMissingApp: return "The downloaded update doesn't contain PasteStack."
        case .updateWrongApp: return "The downloaded update is a different app."
        case .updateDamagedApp: return "The downloaded update is damaged."
        case .updateInstallerFailed: return "Couldn't start installing the update."
        case .updateSwapFailed: return "Installing the update failed, so the previous version was kept."
        case .loginItemFailed: return "Couldn't change Open at Login."
        case .accessibilityMissing: return "PasteStack doesn't have Accessibility permission, so it can copy items but can't paste them for you."
        case .pasteKeystrokeFailed: return "Couldn't send the ⌘V keystroke to paste."
        case .shortcutUnavailable: return "Couldn't set up the ⇧⌘V shortcut."
        case .screenshotFolderUnwatchable: return "Couldn't watch the screenshot folder, so new screenshots aren't being copied."
        case .dataFolderUnavailable: return "Couldn't create PasteStack's data folder, so history can't be saved."
        case .historyUnreadable: return "Your saved history or pinboards couldn't be read."
        case .historySaveFailed: return "Couldn't save your history and pinboards."
        case .itemSaveFailed: return "Couldn't save an item's image or app data."
        case .itemUnreadable: return "Couldn't read an item's saved image or app data, so a simpler version was pasted."
        case .unexpected: return "Something unexpected went wrong."
        }
    }

    var hint: String {
        switch self {
        case .noUpdateSource, .badUpdateSource:
            return "Set one with “Update Source…” in the menu, or leave it empty to use the built-in source."
        case .updateSourceUnreachable:
            return "Check your internet connection and try again."
        case .updateServerError, .updateDownloadFailed:
            return "Try again in a few minutes. If it keeps happening, download the latest version from GitHub."
        case .updateInfoMalformed, .updateUnpackFailed, .updateMissingApp, .updateWrongApp, .updateDamagedApp:
            return "The published update is broken. Download the latest version from GitHub instead."
        case .updateInstallerFailed, .updateSwapFailed:
            return "Make sure PasteStack is in ~/Applications and that the folder isn't locked, then try again."
        case .loginItemFailed:
            return "You can add PasteStack yourself in System Settings → General → Login Items."
        case .accessibilityMissing:
            return "Turn PasteStack on in System Settings → Privacy & Security → Accessibility. If it's already on, remove it with “−”, add it again, and relaunch."
        case .pasteKeystrokeFailed:
            return "Press ⌘V yourself; the item is already on the clipboard."
        case .shortcutUnavailable:
            return "Another app is probably using ⇧⌘V. Quit it, or open PasteStack from the menu bar icon."
        case .screenshotFolderUnwatchable:
            return "Allow PasteStack to access your Desktop (or your screenshot folder) in System Settings → Privacy & Security → Files and Folders."
        case .dataFolderUnavailable, .historySaveFailed, .itemSaveFailed:
            return "Check that your disk isn't full and that ~/Library/Application Support/PasteStack is writable."
        case .itemUnreadable:
            return "The saved copy is missing or damaged. Copy the original again to get the full version back."
        case .historyUnreadable:
            return "PasteStack started with that part empty. The unreadable file was kept next to it, renamed with “damaged” in the name."
        case .unexpected:
            return "Try again. If it keeps happening, copy the details and ask for help."
        }
    }
}

struct AppError: LocalizedError {
    let code: ErrorCode
    /// Technical specifics (paths, system error text). Never clipboard contents.
    let detail: String?

    init(_ code: ErrorCode, _ detail: String? = nil) {
        self.code = code
        self.detail = detail
    }

    init(wrapping error: Error, as code: ErrorCode = .unexpected) {
        if let e = error as? AppError { self = e } else { self.init(code, error.localizedDescription) }
    }

    var errorDescription: String? { "\(code.summary) (\(code.rawValue))" }
}

/// Logs every error to ~/Library/Application Support/PasteStack/errors.log and
/// shows it to the user with its code: in an alert, or as a menu bar row for
/// background failures.
final class ErrorReporter {
    enum Surface {
        case alert     // shown right away
        case menu      // "⚠️ Problem PS-xxx" row in the menu bar dropdown
        case logOnly   // e.g. an automatic update check while offline
    }

    static let shared = ErrorReporter()
    /// The public error list. Both URLs work without a GitHub account; the raw
    /// one is plain text, which AI assistants read most reliably.
    static let helpURL = "https://github.com/jonpikereally/PasteStack/blob/main/ERRORS.md"
    static let plainTextHelpURL = "https://raw.githubusercontent.com/jonpikereally/PasteStack/main/ERRORS.md"

    /// Hover text for anything that shows an error.
    static let tooltip = "Look up this error code on the PasteStack error list: \(helpURL)\n"
        + "You can also give that page and the copied error details to an AI assistant for help."

    /// Latest background problem waiting in the menu, if any.
    private(set) var pending: AppError?
    var onChange: () -> Void = {}
    private var lastLogged: [ErrorCode: Date] = [:]

    static let logURL: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PasteStack", isDirectory: true)
            .appendingPathComponent("errors.log")
    }()

    func report(_ error: AppError, surface: Surface, title: String = "PasteStack ran into a problem") {
        DispatchQueue.main.async {
            self.log(error)
            switch surface {
            case .alert:
                self.present(error, title: title)
            case .menu:
                self.pending = error
                self.onChange()
            case .logOnly:
                break
            }
        }
    }

    func clearPending() {
        pending = nil
        onChange()
    }

    /// Shows the error with its code. `actions` become extra buttons; returns
    /// the index of the action picked, or nil for OK.
    @discardableResult
    func present(_ error: AppError, title: String, actions: [String] = []) -> Int? {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        var text = error.code.summary
        if let d = error.detail, !d.isEmpty { text += "\n\n\(d)" }
        text += "\n\n\(error.code.hint)\n\nError code: \(error.code.rawValue)"
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        for a in actions { alert.addButton(withTitle: a) }
        alert.addButton(withTitle: "Copy Error Details")
        alert.addButton(withTitle: "Open Error List")
        Self.addTooltips(to: alert)
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if response == actions.count + 1 {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(Self.details(error), forType: .string)
            return nil
        }
        if response == actions.count + 2 {
            if let url = URL(string: Self.helpURL) { NSWorkspace.shared.open(url) }
            return nil
        }
        if response >= 1 && response <= actions.count { return response - 1 }
        return nil
    }

    /// Puts the error-list hover text on every piece of text in the alert,
    /// and on the alert itself for the space between them.
    static func addTooltips(to alert: NSAlert) {
        alert.layout()
        func walk(_ view: NSView) {
            if view is NSTextField { view.toolTip = tooltip }
            view.subviews.forEach(walk)
        }
        if let content = alert.window.contentView {
            content.toolTip = tooltip
            walk(content)
        }
    }

    /// Copyable report: everything needed to troubleshoot, nothing private.
    static func details(_ error: AppError) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        #if arch(arm64)
        let arch = "Apple Silicon"
        #else
        let arch = "Intel"
        #endif
        var lines = ["PasteStack error \(error.code.rawValue): \(error.code.summary)"]
        if let d = error.detail, !d.isEmpty { lines.append("Details: \(d)") }
        lines.append("Suggested fix: \(error.code.hint)")
        lines.append("PasteStack v\(AppVersion.version) (built \(AppVersion.built)), macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion), \(arch)")
        lines.append("Time: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Error code list: \(helpURL)")
        lines.append("Plain-text error list for AI assistants: \(plainTextHelpURL)")
        return lines.joined(separator: "\n")
    }

    private func log(_ error: AppError) {
        // The same code repeating (e.g. a full disk failing every save) is
        // logged at most once a minute.
        let now = Date()
        if let last = lastLogged[error.code], now.timeIntervalSince(last) < 60 { return }
        lastLogged[error.code] = now

        let line = "\(ISO8601DateFormatter().string(from: now)) \(error.code.rawValue) v\(AppVersion.version) "
            + error.code.summary + (error.detail.map { " — \($0)" } ?? "") + "\n"
        let url = Self.logURL
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? Int, size > 512 * 1024 {
            let old = url.deletingPathExtension().appendingPathExtension("old.log")
            try? fm.removeItem(at: old)
            try? fm.moveItem(at: url, to: old)
        }
        guard let data = line.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
