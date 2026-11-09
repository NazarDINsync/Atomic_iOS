import Foundation

/// Converts LaTeX / mhchem chemistry markup produced by the LLM into plain Unicode text.
///
/// Examples:
/// - `$\text{C}_2\text{H}_6\text{O}$` → `C₂H₆O`
/// - `$\ce{2H2 + O2 -> 2H2O}$` → `2H₂ + O₂ → 2H₂O`
/// - `$78.29^\circ\text{C}$` → `78.29°C`
/// - `$\text{SO}_4^{2-}$` → `SO₄²⁻`
nonisolated enum ChemTextFormatter {

    /// Rewrites every math segment in `text` and leaves the rest untouched.
    static func format(_ text: String) -> String {
        var result = text
        // Delimited math: $$…$$, \[…\], $…$, \(…\) — paired with the delimiter length to strip.
        let delimited: [(pattern: String, delimiter: Int)] = [
            (#"\$\$.+?\$\$"#, 2),
            (#"\\\[.+?\\\]"#, 2),
            (#"\$[^$\n]+?\$"#, 1),
            (#"\\\(.+?\\\)"#, 2),
        ]
        for (pattern, delimiter) in delimited {
            result = replaceMatches(of: pattern, in: result, group: 0) { match in
                let inner = String(match.dropFirst(delimiter).dropLast(delimiter))
                // Only treat it as math if it contains LaTeX syntax, so "$5 and $10" stays intact.
                guard inner.contains(where: { "\\_^".contains($0) }) else { return match }
                return convertMath(inner)
            }
        }
        // Bare markup the model sometimes emits without delimiters, e.g. \text{H}_2\text{O}.
        let bare = #"(?:\\(?:text|mathrm|ce)\{[^{}]*\}(?:[_^](?:\{[^{}]*\}|[\w+\-]))*)+"#
        result = replaceMatches(of: bare, in: result, group: 0) { convertMath($0) }
        return result
    }

    /// Converts the inside of one LaTeX math segment.
    static func convertMath(_ input: String) -> String {
        var s = input

        // mhchem: \ce{H2O} — digits after an element or bracket become subscripts.
        s = replaceMatches(of: #"\\ce\{([^{}]*)\}"#, in: s) { content in
            var inner = replaceMatches(of: #"(?<=[A-Za-z)\]])(\d+)"#, in: content) { toSubscript($0) }
            inner = inner
                .replacingOccurrences(of: "<=>", with: "⇌")
                .replacingOccurrences(of: "<->", with: "⇌")
                .replacingOccurrences(of: "->", with: "→")
                .replacingOccurrences(of: "<-", with: "←")
            // Charges like ^2- or ^{2-} are handled by the superscript pass below.
            return inner
        }

        // Symbols.
        let symbols: [(String, String)] = [
            (#"\\(?:longrightarrow|rightarrow|to)(?![A-Za-z])"#, "→"),
            (#"\\(?:longleftarrow|leftarrow)(?![A-Za-z])"#, "←"),
            (#"\\(?:rightleftharpoons|leftrightharpoons|leftrightarrow|rightleftarrows)(?![A-Za-z])"#, "⇌"),
            (#"\\(?:circ|degree)(?![A-Za-z])"#, "°"),
            (#"\\cdot(?![A-Za-z])"#, "·"),
            (#"\\times(?![A-Za-z])"#, "×"),
            (#"\\pm(?![A-Za-z])"#, "±"),
            (#"\\approx(?![A-Za-z])"#, "≈"),
            (#"\\(?:leq|le)(?![A-Za-z])"#, "≤"),
            (#"\\(?:geq|ge)(?![A-Za-z])"#, "≥"),
            (#"\\Delta(?![A-Za-z])"#, "Δ"),
            (#"\\alpha(?![A-Za-z])"#, "α"),
            (#"\\beta(?![A-Za-z])"#, "β"),
            (#"\\gamma(?![A-Za-z])"#, "γ"),
            (#"\\mu(?![A-Za-z])"#, "μ"),
            (#"\\%"#, "%"),
            (#"\\[,;: ]"#, " "),
            (#"\\quad(?![A-Za-z])"#, " "),
        ]
        for (pattern, replacement) in symbols {
            s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        // Text-style commands: keep just their content.
        let textCommands = #"\\(?:text|mathrm|textrm|mathbf|textbf|mathit|operatorname)\{([^{}]*)\}"#
        while s.range(of: textCommands, options: .regularExpression) != nil {
            s = replaceMatches(of: textCommands, in: s) { $0 }
        }

        // Sub- and superscripts: _{…}, _x, ^{…}, ^x
        s = replaceMatches(of: #"_\{([^{}]*)\}"#, in: s) { toSubscript($0) }
        s = replaceMatches(of: #"_([A-Za-z0-9+\-])"#, in: s) { toSubscript($0) }
        s = replaceMatches(of: #"\^\{([^{}]*)\}"#, in: s) { toSuperscript($0) }
        s = replaceMatches(of: #"\^([0-9+\-°])"#, in: s) { toSuperscript($0) }

        // Leftovers: unknown commands keep their name, braces disappear.
        s = s.replacingOccurrences(of: #"\\([A-Za-z]+)"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Character maps

    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "o": "ₒ", "x": "ₓ", "h": "ₕ", "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ",
        "p": "ₚ", "s": "ₛ", "t": "ₜ",
    ]

    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ", "i": "ⁱ", "°": "°",
    ]

    /// Maps each character to its subscript form, keeping characters that have none.
    static func toSubscript(_ text: String) -> String {
        String(text.map { subscripts[$0] ?? $0 })
    }

    /// Maps each character to its superscript form, keeping characters that have none.
    static func toSuperscript(_ text: String) -> String {
        String(text.map { superscripts[$0] ?? $0 })
    }

    // MARK: - Regex helper

    /// Replaces each match of `pattern`, passing capture `group` (default 1) to `transform`.
    private static func replaceMatches(
        of pattern: String,
        in text: String,
        group: Int = 1,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return text
        }
        let ns = text as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let captured = match.range(at: group)
            result += captured.location == NSNotFound ? "" : transform(ns.substring(with: captured))
            cursor = match.range.location + match.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
