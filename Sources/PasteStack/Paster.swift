import AppKit
import ApplicationServices

enum Paster {
    static var accessibilityTrusted: Bool { AXIsProcessTrusted() }

    static func promptForAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    /// Write the item onto the system pasteboard.
    static func write(_ item: ClipItem, store: Store, monitor: ClipboardMonitor,
                      plainText: Bool, asImage: Bool = false) {
        let pb = NSPasteboard.general
        pb.clearContents()

        // History items saved as mailto: links paste as the bare address.
        if MailtoCleaner.enabled, let t = item.text, let address = MailtoCleaner.clean(t) {
            pb.setString(address, forType: .string)
            monitor.markSelfWrite()
            return
        }

        // Paste-as-image: put actual pixel data on the clipboard, resolved
        // from the file on disk (freshest) or the stored preview.
        if asImage {
            var png: Data? = nil
            if item.type == .file,
               let path = item.text?.split(separator: "\n").first,
               let d = try? Data(contentsOf: URL(fileURLWithPath: String(path))),
               let rep = NSBitmapImageRep(data: d) {
                png = rep.representation(using: .png, properties: [:])
            }
            if png == nil, let f = item.imageFile {
                png = try? Data(contentsOf: store.imagesDir.appendingPathComponent(f))
            }
            if let png {
                pb.setData(png, forType: .png)
                if let tiff = NSImage(data: png)?.tiffRepresentation {
                    pb.setData(tiff, forType: .tiff)
                }
                monitor.markSelfWrite()
                return
            }
            ErrorReporter.shared.report(AppError(.itemUnreadable, "no readable image for paste-as-image"),
                                        surface: .menu)
        }

        // Plain-text paste: strip all formatting/types, write just the string.
        if plainText, let t = item.text, item.type != .raw {
            pb.setString(t, forType: .string)
            monitor.markSelfWrite()
            return
        }

        // Catch-all items: restore the original pasteboard structure —
        // every item, every type, byte-for-byte, in original order.
        if let rawFile = item.rawFile {
            let data = try? Data(contentsOf: store.rawDir.appendingPathComponent(rawFile))
            var restored = false
            if let data, let archive = try? JSONDecoder().decode([[RawBlob]].self, from: data),
               !archive.isEmpty {
                let pbItems = archive.map { blobs -> NSPasteboardItem in
                    let pbItem = NSPasteboardItem()
                    for blob in blobs {
                        pbItem.setData(blob.d, forType: .init(blob.t))
                    }
                    return pbItem
                }
                restored = pb.writeObjects(pbItems)
            } else if let data, let legacy = try? JSONDecoder().decode([String: Data].self, from: data),
                      !legacy.isEmpty {
                // Archives from the earlier catch-all format.
                for (typeName, blob) in legacy {
                    pb.setData(blob, forType: .init(typeName))
                }
                restored = true
            }
            if restored {
                monitor.markSelfWrite()
                return
            }
            ErrorReporter.shared.report(AppError(.itemUnreadable, "app data \(rawFile)"), surface: .menu)
        }

        switch item.type {
        case .text, .url, .raw:
            pb.setString(item.text ?? "", forType: .string)
        case .file:
            let urls = (item.text ?? "").split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
            pb.writeObjects(urls as [NSURL])
        case .image:
            if let url = store.imageURL(for: item), let data = try? Data(contentsOf: url) {
                pb.setData(data, forType: .png)
            }
        }
        monitor.markSelfWrite()
    }

    /// Simulate Cmd+V in the frontmost app. Requires Accessibility permission.
    static func sendCmdV() {
        let vKey = CGKeyCode(9) // kVK_ANSI_V
        guard let src = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false) else {
            ErrorReporter.shared.report(AppError(.pasteKeystrokeFailed, "couldn't create the keyboard events"),
                                        surface: .menu)
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
