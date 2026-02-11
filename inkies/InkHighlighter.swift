import AppKit
import SwiftUI

class InkHighlighter {
    static func highlight(_ text: String, theme: AppTheme) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(text.startIndex..., in: text)

        let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)

        // Default style
        let defaultColor = theme == .dark ? NSColor.textColor : NSColor.textColor
        attributedString.addAttribute(.font, value: baseFont, range: range)
        attributedString.addAttribute(.foregroundColor, value: defaultColor, range: range)

        // Define rules: (Regex, Color, Font)
        let rules: [(String, NSColor, NSFont)] = [
            // 1. Comments
            ("//.*", .systemGray, baseFont),
            ("/\\*[\\s\\S]*?\\*/", .systemGray, baseFont),

            // 2. Knots and Stitches
            ("^\\s*={2,}.*", .systemPurple, boldFont),
            ("^\\s*-{2,}.*", .systemPurple, boldFont),

            // 3. Choices
            ("^\\s*\\*+.*", .systemGreen, baseFont),
            ("^\\s*\\++.*", .systemGreen, baseFont),

            // 4. Gathers
            ("^\\s*-{1}+[^->].*", .systemOrange, baseFont),

            // 5. Diversions
            ("->\\s*\\w+", .systemBlue, boldFont),
            ("<-", .systemBlue, boldFont),

            // 6. Tags
            ("#.*", .systemGray, baseFont),

            // 7. Logic and Variables
            ("~.*", .systemRed, baseFont),
            ("\\b(VAR|temp|LIST|CONST)\\b", .systemRed, boldFont),

            // 8. Strings (within logic typically)
            ("\".*?\"", .systemBrown, baseFont),
        ]

        for (pattern, color, font) in rules {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            {
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let matchRange = match?.range {
                        attributedString.addAttribute(
                            .foregroundColor, value: color, range: matchRange)
                        attributedString.addAttribute(.font, value: font, range: matchRange)
                    }
                }
            }
        }

        return attributedString
    }
}
