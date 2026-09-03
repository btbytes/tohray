import AppKit
import SwiftUI

/// A plain-text markdown editor that styles the markdown in place as you type.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var focusOnAppear: Bool = false
    var coordinatorRef: CoordinatorReference? = nil
    var onCommandReturn: (() -> Void)? = nil
    var onCommandP: (() -> Void)? = nil
    var onCommandI: (() -> Void)? = nil

    /// Lets an external owner reach the live `NSTextView` (to insert text at the
    /// cursor) after the coordinator has been created by SwiftUI.
    final class CoordinatorReference {
        weak var coordinator: Coordinator?
        init() {}
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(text: $text)
        coordinatorRef?.coordinator = coordinator
        return coordinator
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
        textView.onCommandI = onCommandI

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
        context.coordinator.onCommandI = onCommandI
        coordinatorRef?.coordinator = context.coordinator
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }
        textView.onCommandReturn = onCommandReturn
        textView.onCommandP = onCommandP
        textView.onCommandI = onCommandI

        guard textView.string != text else { return }
        textView.string = text
        context.coordinator.highlight(textView)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onCommandI: (() -> Void)? = nil
        private var textView: NSTextView?
        private let highlighter = MarkdownHighlighter()

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.textView = textView
            text.wrappedValue = textView.string
            highlight(textView)
        }

        func highlight(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            highlighter.highlight(storage)
            textView.typingAttributes = highlighter.baseAttributes
        }

        /// Inserts `string` at the current cursor position (replacing any
        /// selection) and moves the caret after it, then updates the binding.
        func insertMarkdown(_ string: String) {
            guard let textView, let storage = textView.textStorage else { return }
            let insertion = textView.selectedRange()
            let safeRange = NSRange(location: 0, length: storage.length)
            let clamped = NSIntersectionRange(insertion, safeRange)

            textView.shouldChangeText(in: clamped, replacementString: string)
            storage.replaceCharacters(in: clamped, with: string)
            textView.didChangeText()

            let newLocation = clamped.location + (string as NSString).length
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))

            text.wrappedValue = textView.string
            highlight(textView)
        }

        /// `makeNSView` runs before the view joins a window, so first responder
        /// status has to be claimed once the window exists.
        func takeFocus(_ textView: NSTextView, attemptsRemaining: Int = 20) {
            self.textView = textView
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
    var onCommandI: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if isCommandReturn(event) {
            onCommandReturn?()
            return
        }
        if isCommandP(event) {
            onCommandP?()
            return
        }
        if isCommandI(event) {
            onCommandI?()
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

    private func isCommandI(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.option)
            && event.keyCode == 34
    }
}
