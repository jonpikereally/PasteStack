import AppKit
import CoreServices

/// Watches the folder where macOS saves screenshots (Desktop by default) and
/// reports each new screenshot file so it can be copied to the clipboard and
/// added to history. The file itself is never touched.
final class ScreenshotWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private let dir: URL
    var onScreenshot: (URL) -> Void = { _ in }

    init() {
        // Respect a custom `defaults write com.apple.screencapture location`.
        let custom = UserDefaults(suiteName: "com.apple.screencapture")?
            .string(forKey: "location")
        if let custom {
            dir = URL(fileURLWithPath: (custom as NSString).expandingTildeInPath)
        } else {
            dir = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        }
    }

    func start() {
        guard source == nil else { return }
        known = Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
                                                            eventMask: .write,
                                                            queue: .main)
        src.setEventHandler { [weak self] in
            // Give screencapture a moment to finish writing the file.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self?.checkNew() }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func checkNew() {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for name in names where !known.contains(name) {
            known.insert(name)
            guard !name.hasPrefix("."),
                  ["png", "jpg", "jpeg"].contains((name as NSString).pathExtension.lowercased())
            else { continue }
            let url = dir.appendingPathComponent(name)
            if isScreenshot(url) { onScreenshot(url) }
        }
    }

    private func isScreenshot(_ url: URL) -> Bool {
        if let md = MDItemCreateWithURL(nil, url as CFURL),
           let flag = MDItemCopyAttribute(md, "kMDItemIsScreenCapture" as CFString) as? Bool {
            return flag
        }
        // Metadata not indexed yet — fall back to the filename.
        return url.lastPathComponent.localizedCaseInsensitiveContains("screenshot")
            || url.lastPathComponent.localizedCaseInsensitiveContains("screen shot")
    }
}
