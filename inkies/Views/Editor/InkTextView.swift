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

        init(_ parent: InkTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            
            isUpdatingFromWithin = true
            parent.text = newText
            
            // Re-apply highlighting colors without breaking undo string history
            // We only update attributes, not characters
            let highlighted = InkHighlighter.highlight(newText, theme: parent.appTheme)
            
            // Disable undo registration for attribute updates
            textView.undoManager?.disableUndoRegistration()
            
            // Apply attributes from highlighting to the existing textStorage
            let fullRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
            if fullRange.length > 0 {
                textView.textStorage?.beginEditing()
                // Clear existing attributes
                textView.textStorage?.setAttributes([:], range: fullRange)
                
                // Copy new attributes
                highlighted.enumerateAttributes(in: NSRange(location: 0, length: highlighted.length), options: []) { attrs, range, _ in
                    if range.location + range.length <= (textView.textStorage?.length ?? 0) {
                        textView.textStorage?.addAttributes(attrs, range: range)
                    }
                }
                textView.textStorage?.endEditing()
            }
            
            textView.undoManager?.enableUndoRegistration()
            isUpdatingFromWithin = false
        }
    }
}
