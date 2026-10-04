import Foundation

/// Turns a copied email link ("mailto:jon@example.com?subject=Hi") into the
/// bare address. On by default; menu bar → Remove "mailto:" from Copied Emails.
enum MailtoCleaner {
    static let defaultsKey = "stripMailto"

    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// The bare address(es) when `s` is a single mailto: link, otherwise nil.
    /// Only whole-clipboard links count, so prose that mentions "mailto:"
    /// somewhere in the middle is left alone.
    static func clean(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("mailto:"), !trimmed.contains("\n") else { return nil }
        var rest = trimmed.dropFirst("mailto:".count)
        if rest.hasPrefix("//") { rest = rest.dropFirst(2) }
        if let q = rest.firstIndex(of: "?") { rest = rest[..<q] }
        let address = (String(rest).removingPercentEncoding ?? String(rest))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? nil : address
    }
}
