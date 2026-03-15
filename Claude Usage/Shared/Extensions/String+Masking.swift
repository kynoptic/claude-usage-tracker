import Foundation

extension String {
    /// Masks an API key or session key for display, preserving a prefix and suffix.
    ///
    /// Returns a fixed placeholder when the key is too short to mask safely.
    func maskedKey() -> String {
        guard count > 20 else { return "•••••••••" }
        let prefix = String(self.prefix(12))
        let suffix = String(self.suffix(4))
        return "\(prefix)•••••\(suffix)"
    }

    /// Returns up to two initials derived from this string treated as a name.
    ///
    /// - Two or more words: first letter of each of the first two words, uppercased.
    /// - One word: first two characters, uppercased.
    /// - Empty string: `"?"`.
    func profileInitials() -> String {
        let words = split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}
