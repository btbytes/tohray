import AppKit
import SwiftUI

/// A plain-text markdown editor that styles the markdown in place as you type.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var focusOnAppear: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.allowsUndo = true
        // Top inset keeps the first line clear of the hidden-title-bar traffic lights.
        textView.textContainerInset = NSSize(width: 18, height: 30)
        textView.backgroundColor = .textBackgroundColor
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0

        // Markdown is punctuation-heavy, so macOS text substitutions would
        // silently corrupt what gets posted.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.string = text
        context.coordinator.highlight(textView)

        if focusOnAppear {
            context.coordinator.takeFocus(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text

        guard textView.string != text else { return }
        textView.string = text
        context.coordinator.highlight(textView)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        private let highlighter = MarkdownHighlighter()

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            highlight(textView)
        }

        func highlight(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            highlighter.highlight(storage)
            textView.typingAttributes = highlighter.baseAttributes
        }

        /// `makeNSView` runs before the view joins a window, so first responder
        /// status has to be claimed once the window exists.
        func takeFocus(_ textView: NSTextView, attemptsRemaining: Int = 20) {
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                if let window = textView.window {
                    window.makeFirstResponder(textView)
                } else if attemptsRemaining > 0 {
                    self.takeFocus(textView, attemptsRemaining: attemptsRemaining - 1)
                }
            }
        }
    }
}
