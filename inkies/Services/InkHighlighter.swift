import AppKit
import SwiftUI

class InkHighlighter {
    // 规则结构:预编译后的正则 + 颜色 + 是否粗体
    private struct Rule {
        let regex: NSRegularExpression
        let color: NSColor
        let bold: Bool
    }

    private static let baseFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    private static let boldFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .bold)

    // 规则按"先涂底,后覆盖"的语义排列。
    // NSAttributedString 后写的属性会覆盖先写的,因此:
    //   1) 先涂所有语法符号
    //   2) 再涂 tag(#...)
    //   3) 再涂字符串("..."),让字符串内的语法不再着色
    //   4) 最后涂注释(// 和 /* */),让注释内一切高亮被还原为灰
    private static let rules: [Rule] = {
        let patterns: [(String, NSColor, Bool)] = [
            // ---- 1. 结构 ----
            // Knot:  === name ===  或  === name
            (#"^\s*={2,}\s*\w+\s*(?:={2,}\s*)?$"#, .systemPurple, true),
            // Stitch:  = name  (单等号,行首)
            (#"^\s*=\s*\w+\s*$"#, .systemPurple, true),

            // ---- 2. Choices ----
            // *   或  + ,允许嵌套层级(* * *)
            (#"^\s*[\*\+]+\s*"#, .systemGreen, true),
            // Choice label:  (label_name)
            (#"\([A-Za-z_]\w*\)"#, .systemTeal, false),

            // ---- 3. Gather ----
            // 行首单 dash,后面不接 dash / > / =
            (#"^\s*-(?![\->=])"#, .systemOrange, true),

            // ---- 4. Diversions ----
            // Tunnel return  ->->
            (#"->->"#, .systemBlue, true),
            // 普通跳转  -> name 或 -> name.stitch
            (#"->\s*\w+(?:\.\w+)*"#, .systemBlue, true),
            // 线程  <-
            (#"<-"#, .systemBlue, true),

            // ---- 5. Glue ----
            (#"<>"#, .systemPink, true),

            // ---- 6. 文本插值 / 序列  {...} ----
            // 不跨行、不递归,够用即可
            (#"\{[^{}\n]*\}"#, .systemTeal, false),

            // ---- 7. Logic 行  ~ ... ----
            (#"^\s*~.*"#, .systemRed, false),

            // ---- 8. 关键字 ----
            (#"\b(VAR|CONST|LIST|temp|INCLUDE|EXTERNAL|END|DONE|START|true|false|not|and|or|mod|ref|return)\b"#, .systemRed, true),

            // ---- 9. Tags(行内或独立) ----
            // 必须在字符串之前,这样字符串里的 # 会被字符串再覆盖回来
            (#"#[^\n]*"#, .systemGray, false),

            // ---- 10. 字符串 ----
            (#""[^"\n]*""#, .systemBrown, false),

            // ---- 11. 注释(最后,覆盖一切) ----
            (#"//[^\n]*"#, .systemGray, false),
            (#"/\*[\s\S]*?\*/"#, .systemGray, false),
        ]
        return patterns.compactMap { pattern, color, bold in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                return nil
            }
            return Rule(regex: regex, color: color, bold: bold)
        }
    }()

    static func highlight(_ text: String, theme: AppTheme) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(text.startIndex..., in: text)

        // 默认样式
        let defaultColor: NSColor = theme == .dark ? .white : .black
        attributedString.addAttribute(.font, value: baseFont, range: range)
        attributedString.addAttribute(.foregroundColor, value: defaultColor, range: range)

        for rule in rules {
            let font = rule.bold ? boldFont : baseFont
            rule.regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: rule.color, range: matchRange)
                    attributedString.addAttribute(.font, value: font, range: matchRange)
                }
            }
        }

        return attributedString
    }
}
