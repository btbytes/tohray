import AppKit
import SwiftUI

/// A plain-text markdown editor that styles the markdown in place as you type.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var focusOnAppear: Bool = false
    var onCommandReturn: (() -> Void)? = nil
    var onCommandP: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        // Top inset keeps the first line clear of the hidden-title-bar traffic lights.
        textView.textContainerInset = NSSize(width: 18, height: 30)
        textView.backgroundColor = .textBackgroundColor
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.onCommandReturn = onCommandReturn
        textView.onCommandP = onCommandP

        // Markdown is punctuation-heavy, so macOS text substitutions would
        // silently corrupt what gets posted.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        textView.frame = scrollView.contentView.bounds

        textView.string = text
        context.coordinator.highlight(textView)

        if focusOnAppear {
            context.coordinator.takeFocus(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }
        textView.onCommandReturn = onCommandReturn
        textView.onCommandP = onCommandP

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

/// Intercepts editor-local shortcuts that NSTextView would otherwise swallow.
final class MarkdownTextView: NSTextView {
    var onCommandReturn: (() -> Void)?
    var onCommandP: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if isCommandReturn(event) {
            onCommandReturn?()
            return
        }
        if isCommandP(event) {
            onCommandP?()
            return
        }
        super.keyDown(with: event)
    }

    private func isCommandReturn(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command)
            && (event.keyCode == 36 || event.keyCode == 76)
    }

    private func isCommandP(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.shift)
            && !event.modifierFlags.contains(.option)
            && event.keyCode == 35
    }
}
