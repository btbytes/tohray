import Markdown
import SwiftUI
import WebKit

enum MarkdownHTML {
    static func document(from markdown: String) -> String {
        let body = markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "<p class=\"empty\">Nothing to preview yet.</p>"
            : HTMLFormatter.format(markdown)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root { color-scheme: light dark; }
        html, body { margin: 0; padding: 0; }
        body {
            font-family: "New York", "Iowan Old Style", Palatino, "Palatino Linotype", serif;
            font-size: 17px;
            line-height: 1.55;
            padding: 28px 36px 48px;
            max-width: 42em;
            margin: 0 auto;
            color: CanvasText;
            background: Canvas;
        }
        h1, h2, h3, h4, h5, h6 { line-height: 1.25; font-weight: 600; }
        h1 { font-size: 1.7em; }
        h2 { font-size: 1.45em; }
        h3 { font-size: 1.25em; }
        p { margin: 0.8em 0; }
        a { color: LinkText; }
        code, pre {
            font-family: ui-monospace, Menlo, "SF Mono", monospace;
            font-size: 0.9em;
        }
        code {
            background: color-mix(in srgb, CanvasText 8%, Canvas);
            padding: 0.12em 0.35em;
            border-radius: 4px;
        }
        pre {
            background: color-mix(in srgb, CanvasText 8%, Canvas);
            padding: 12px 16px;
            border-radius: 8px;
            overflow-x: auto;
        }
        pre code { background: none; padding: 0; }
        blockquote {
            margin: 0.8em 0;
            padding: 0.1em 0 0.1em 1em;
            border-left: 3px solid color-mix(in srgb, CanvasText 25%, Canvas);
            color: color-mix(in srgb, CanvasText 72%, Canvas);
        }
        ul, ol { padding-left: 1.4em; }
        hr { border: none; border-top: 1px solid color-mix(in srgb, CanvasText 18%, Canvas); }
        img { max-width: 100%; }
        .empty { color: color-mix(in srgb, CanvasText 45%, Canvas); font-style: italic; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

struct MarkdownPreviewView: View {
    let markdown: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            HTMLPreview(html: MarkdownHTML.document(from: markdown))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

private struct HTMLPreview: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .textBackgroundColor
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadedHTML: String?
    }
}

extension Notification.Name {
    static let toggleMarkdownPreview = Notification.Name("toggleMarkdownPreview")
    static let openSettings = Notification.Name("openSettings")
}
