import SwiftUI
import AppKit

struct InkTextView: NSViewRepresentable {
    @Binding var text: String
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    var issues: [InkIssue] = []

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        let textView = NSTextView()
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = true
        textView.isSelectable = true
        
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        // Background and coloring
        textView.backgroundColor = appTheme == .dark
            ? NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0) : .textBackgroundColor
        textView.insertionPointColor = appTheme == .dark ? .white : .black

        scrollView.documentView = textView
        textView.delegate = context.coordinator
        
        let ruler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        ruler.clientView = textView
        ruler.ruleThickness = 40
        scrollView.verticalRulerView = ruler
        
        // Initial text
        let attributed = InkHighlighter.highlight(text, theme: appTheme)
        textView.textStorage?.setAttributedString(attributed)
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            // Only update if text is fundamentally different to avoid loop
            let selectedRange = textView.selectedRange()
            
            // We use shouldChangeText in formal updates to maintain undo if possible,
            // but for external sync we just set it.
            let attributed = InkHighlighter.highlight(text, theme: appTheme)
            textView.textStorage?.setAttributedString(attributed)
            textView.setSelectedRange(selectedRange)
        }

        // Update theme-based colors if changed
        let targetBg = appTheme == .dark
            ? NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0) : .textBackgroundColor
        if textView.backgroundColor != targetBg {
            textView.backgroundColor = targetBg
            textView.insertionPointColor = appTheme == .dark ? .white : .black
            
            // Re-highlight on theme change without breaking undo character history
            let highlighted = InkHighlighter.highlight(textView.string, theme: appTheme)
            
            textView.undoManager?.disableUndoRegistration()
            let fullRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
            if fullRange.length > 0 {
                textView.textStorage?.beginEditing()
                textView.textStorage?.setAttributes([:], range: fullRange)
                highlighted.enumerateAttributes(in: NSRange(location: 0, length: highlighted.length), options: []) { attrs, range, _ in
                    if range.location + range.length <= (textView.textStorage?.length ?? 0) {
                        textView.textStorage?.addAttributes(attrs, range: range)
                    }
                }
                textView.textStorage?.endEditing()
            }
            textView.undoManager?.enableUndoRegistration()
        }
        
        // Update ruler issues
        if let ruler = nsView.verticalRulerView as? LineNumberRulerView {
            if ruler.issues != issues {
                ruler.issues = issues
                ruler.needsDisplay = true
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InkTextView
        var isUpdatingFromWithin = false
        private var highlightWorkItem: DispatchWorkItem?

        init(_ parent: InkTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string

            isUpdatingFromWithin = true
            parent.text = newText
            isUpdatingFromWithin = false

            // 性能修复:对高亮做 150ms 防抖,避免每次按键都全文枚举属性导致大文档卡顿。
            highlightWorkItem?.cancel()
            let theme = parent.appTheme
            let workItem = DispatchWorkItem { [weak self, weak textView] in
                guard let self = self, let textView = textView else { return }
                // textView.string 在主线程读取,确保读到最新文本
                let current = textView.string
                let highlighted = InkHighlighter.highlight(current, theme: theme)
                self.applyAttributes(from: highlighted, to: textView)
            }
            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
        }

        /// 仅复制属性,不触碰字符,避免破坏 undo 历史与插入点位置。
        private func applyAttributes(from highlighted: NSAttributedString, to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let storageLength = storage.length
            // 字符数若不一致(用户在防抖期间继续输入),放弃这次高亮,等下一次防抖触发
            guard highlighted.length == storageLength, storageLength > 0 else { return }

            textView.undoManager?.disableUndoRegistration()
            storage.beginEditing()
            let fullRange = NSRange(location: 0, length: storageLength)
            storage.setAttributes([:], range: fullRange)
            highlighted.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
                storage.addAttributes(attrs, range: range)
            }
            storage.endEditing()
            textView.undoManager?.enableUndoRegistration()
        }
    }
}
