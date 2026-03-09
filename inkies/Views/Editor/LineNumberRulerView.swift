import AppKit
import SwiftUI

class LineNumberRulerView: NSRulerView {
    private var font: NSFont {
        return .monospacedSystemFont(ofSize: 12, weight: .regular)
    }
    
    private var textColor: NSColor {
        return NSColor.secondaryLabelColor
    }

    var issues: [InkIssue] = []

// No custom draw override to prevent layout interference

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let contentRect = textView.visibleRect
        let textRange = layoutManager.glyphRange(forBoundingRect: contentRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: textRange, actualGlyphRange: nil)
        
        let contents = (textView.string as NSString)
        var lineCount = 1
        
        // Find starting line number
        contents.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineCount += 1
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor.withAlphaComponent(0.6)
        ]

        var glyphIndex = textRange.location
        while glyphIndex < NSMaxRange(textRange) {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let lineRange = contents.lineRange(for: NSRange(location: charIndex, length: 0))
            let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            
            let y = lineRect.origin.y + textView.textContainerInset.height - contentRect.origin.y
            let label = "\(lineCount)" as NSString
            let labelSize = label.size(withAttributes: attributes)
            
            // Check for issues on this line
            let lineIssues = issues.filter { $0.lineNumber == lineCount }
            if !lineIssues.isEmpty {
                let hasError = lineIssues.contains { $0.type == .error }
                let markerColor = hasError ? NSColor.systemRed : NSColor.systemYellow
                markerColor.set()
                
                let markerSize: CGFloat = 6
                let markerRect = NSRect(
                    x: 6,
                    y: y + (lineRect.height - markerSize) / 2,
                    width: markerSize,
                    height: markerSize
                )
                let markerPath = NSBezierPath(ovalIn: markerRect)
                markerPath.fill()
            }

            // Minimalist alignment: right aligned with standard padding
            let labelRect = NSRect(
                x: ruleThickness - labelSize.width - 8,
                y: y + (lineRect.height - labelSize.height) / 2,
                width: labelSize.width,
                height: labelSize.height
            )
            
            label.draw(in: labelRect, withAttributes: attributes)
            
            lineCount += 1
            glyphIndex = NSMaxRange(layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil))
        }
    }
}
