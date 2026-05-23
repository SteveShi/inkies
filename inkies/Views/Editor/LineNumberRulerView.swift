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

    // 缓存换行符位置数组与对应文本长度,避免每次滚动都重新枚举整段前缀文本
    private var cachedNewlineOffsets: [Int] = []
    private var cachedTextLength: Int = -1
    private var cachedTextHash: Int = 0

    /// 二分查找 charIndex 所在行号(行号从 1 开始)
    private func lineNumber(forCharIndex charIndex: Int) -> Int {
        // cachedNewlineOffsets 保存的是每个 '\n' 的位置;行号 = 不大于 charIndex 的换行符个数 + 1
        var lo = 0
        var hi = cachedNewlineOffsets.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if cachedNewlineOffsets[mid] < charIndex {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo + 1
    }

    private func rebuildNewlineCacheIfNeeded(_ contents: NSString) {
        let length = contents.length
        // 用长度+hashValue 简单判断是否需要重建;hashValue 对超大字符串也是常数级摊销
        let hash = (contents as String).hashValue
        if length == cachedTextLength && hash == cachedTextHash {
            return
        }
        var offsets: [Int] = []
        offsets.reserveCapacity(max(16, length / 40))
        let buffer = contents
        for i in 0..<length {
            if buffer.character(at: i) == 0x0A { // '\n'
                offsets.append(i)
            }
        }
        cachedNewlineOffsets = offsets
        cachedTextLength = length
        cachedTextHash = hash
    }

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
        rebuildNewlineCacheIfNeeded(contents)
        // 用缓存的换行偏移做二分,O(log N) 取代原来的 O(N) 枚举
        var lineCount = lineNumber(forCharIndex: charRange.location)
        
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
