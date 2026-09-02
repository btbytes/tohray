import AppKit
import Markdown

struct MarkdownTheme {
    var bodyFont = NSFont.readingFont(ofSize: 17)
    var textColor = NSColor.labelColor
    var delimiterColor = NSColor.tertiaryLabelColor
    var quoteColor = NSColor.secondaryLabelColor
    var linkColor = NSColor.linkColor
    var codeBackgroundColor = NSColor.textColor.withAlphaComponent(0.06)
    var blockIndent: CGFloat = 18
    var lineSpacing: CGFloat = 5

    func headingFontSize(forLevel level: Int) -> CGFloat {
        switch level {
        case 1: return bodyFont.pointSize + 12
        case 2: return bodyFont.pointSize + 8
        case 3: return bodyFont.pointSize + 5
        case 4: return bodyFont.pointSize + 3
        case 5: return bodyFont.pointSize + 1
        default: return bodyFont.pointSize
        }
    }
}

extension NSFont {
    /// New York, the system serif face, reads more comfortably than the UI font
    /// for long-form prose.
    static func readingFont(ofSize size: CGFloat) -> NSFont {
        let fallback = NSFont.systemFont(ofSize: size)
        guard let descriptor = fallback.fontDescriptor.withDesign(.serif) else { return fallback }
        return NSFont(descriptor: descriptor, size: size) ?? fallback
    }
}

/// Applies markdown styling to the raw markdown text held by an `NSTextStorage`,
/// leaving the characters untouched so the text stays editable and round-trips
/// back to the server as markdown.
struct MarkdownHighlighter {
    var theme = MarkdownTheme()

    var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.lineSpacing
        paragraphStyle.paragraphSpacing = theme.lineSpacing * 1.5
        return [
            .font: theme.bodyFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    func highlight(_ storage: NSTextStorage) {
        let text = storage.string
        let fullRange = NSRange(location: 0, length: storage.length)

        var collector = StyleCollector(text: text, positions: SourcePositionMap(text: text))
        collector.visit(Document(parsing: text))

        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: fullRange)
        for span in collector.spans {
            apply(span.style, to: storage, in: span.range.clamped(to: fullRange))
        }
        for range in collector.delimiterRanges {
            storage.addAttribute(.foregroundColor, value: theme.delimiterColor, range: range.clamped(to: fullRange))
        }
        storage.endEditing()
    }

    private func apply(_ style: MarkdownStyle, to storage: NSTextStorage, in range: NSRange) {
        guard range.length > 0 else { return }

        switch style {
        case .heading(let level):
            let size = theme.headingFontSize(forLevel: level)
            transformFonts(in: range, of: storage) { font in
                Self.font(font, withSize: size, addingTraits: .bold)
            }
        case .bold:
            transformFonts(in: range, of: storage) { Self.font($0, addingTraits: .bold) }
        case .italic:
            transformFonts(in: range, of: storage) { Self.font($0, addingTraits: .italic) }
        case .strikethrough:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .code:
            transformFonts(in: range, of: storage) { Self.monospacedFont(matching: $0) }
            storage.addAttribute(.backgroundColor, value: theme.codeBackgroundColor, range: range)
        case .codeBlock:
            transformFonts(in: range, of: storage) { Self.monospacedFont(matching: $0) }
            storage.addAttribute(.backgroundColor, value: theme.codeBackgroundColor, range: range)
            storage.addAttribute(.paragraphStyle, value: indentedParagraphStyle(), range: range)
        case .link:
            storage.addAttribute(.foregroundColor, value: theme.linkColor, range: range)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .quote:
            storage.addAttribute(.foregroundColor, value: theme.quoteColor, range: range)
            storage.addAttribute(.paragraphStyle, value: indentedParagraphStyle(), range: range)
        }
    }

    private func indentedParagraphStyle() -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.lineSpacing
        paragraphStyle.paragraphSpacing = theme.lineSpacing * 1.5
        paragraphStyle.firstLineHeadIndent = theme.blockIndent
        paragraphStyle.headIndent = theme.blockIndent
        return paragraphStyle
    }

    private func transformFonts(in range: NSRange, of storage: NSTextStorage, transform: (NSFont) -> NSFont) {
        storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = value as? NSFont ?? theme.bodyFont
            storage.addAttribute(.font, value: transform(font), range: subrange)
        }
    }

    private static func font(
        _ font: NSFont,
        withSize size: CGFloat? = nil,
        addingTraits traits: NSFontDescriptor.SymbolicTraits
    ) -> NSFont {
        let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits))
        return NSFont(descriptor: descriptor, size: size ?? font.pointSize) ?? font
    }

    private static func monospacedFont(matching font: NSFont) -> NSFont {
        let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
        return NSFont.monospacedSystemFont(ofSize: font.pointSize * 0.9, weight: isBold ? .bold : .regular)
    }
}

private enum MarkdownStyle {
    case heading(level: Int)
    case bold
    case italic
    case strikethrough
    case code
    case codeBlock
    case link
    case quote
}

private struct StyledSpan {
    let range: NSRange
    let style: MarkdownStyle
}

/// Walks the parsed document and records which source ranges need which styling.
/// Block nodes are visited before their inline children, so nested styles layer
/// correctly when they are applied in order.
private struct StyleCollector: MarkupWalker {
    let text: NSString
    let positions: SourcePositionMap

    private(set) var spans: [StyledSpan] = []
    private(set) var delimiterRanges: [NSRange] = []

    init(text: String, positions: SourcePositionMap) {
        self.text = text as NSString
        self.positions = positions
    }

    mutating func visitHeading(_ heading: Heading) {
        if let range = nsRange(of: heading) {
            spans.append(StyledSpan(range: range, style: .heading(level: heading.level)))
            dimHeadingMarkers(in: range)
        }
        descendInto(heading)
    }

    mutating func visitStrong(_ strong: Strong) {
        record(.bold, for: strong)
        descendInto(strong)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        record(.italic, for: emphasis)
        descendInto(emphasis)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        record(.strikethrough, for: strikethrough)
        descendInto(strikethrough)
    }

    mutating func visitLink(_ link: Link) {
        record(.link, for: link)
        descendInto(link)
    }

    mutating func visitImage(_ image: Image) {
        record(.link, for: image)
        descendInto(image)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        guard let range = nsRange(of: inlineCode) else { return }
        spans.append(StyledSpan(range: range, style: .code))
        dimBacktickRuns(in: range)
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        guard let range = nsRange(of: codeBlock) else { return }
        spans.append(StyledSpan(range: range, style: .codeBlock))
        dimFenceLines(in: range)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        if let range = nsRange(of: blockQuote) {
            spans.append(StyledSpan(range: range, style: .quote))
            dimLinePrefixes(in: range, marker: ">")
        }
        descendInto(blockQuote)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        if let range = nsRange(of: listItem) {
            dimListMarker(in: range)
        }
        descendInto(listItem)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        if let range = nsRange(of: thematicBreak) {
            delimiterRanges.append(range)
        }
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        if let range = nsRange(of: html) {
            delimiterRanges.append(range)
        }
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        if let range = nsRange(of: inlineHTML) {
            delimiterRanges.append(range)
        }
    }

    // MARK: - Range helpers

    private func nsRange(of markup: Markup) -> NSRange? {
        markup.range.flatMap(positions.nsRange(for:))
    }

    private mutating func record(_ style: MarkdownStyle, for markup: Markup) {
        guard let range = nsRange(of: markup) else { return }
        spans.append(StyledSpan(range: range, style: style))
        dimGapsAroundChildren(of: markup, in: range)
    }

    /// Everything inside a node that no child covers is punctuation: the `**` of
    /// bold text, or the `](url)` of a link.
    private mutating func dimGapsAroundChildren(of markup: Markup, in range: NSRange) {
        let childRanges = markup.children
            .compactMap(nsRange(of:))
            .sorted { $0.location < $1.location }

        var cursor = range.location
        for childRange in childRanges {
            if childRange.location > cursor {
                delimiterRanges.append(NSRange(location: cursor, length: childRange.location - cursor))
            }
            cursor = max(cursor, childRange.upperBound)
        }
        if cursor < range.upperBound {
            delimiterRanges.append(NSRange(location: cursor, length: range.upperBound - cursor))
        }
    }

    private mutating func dimHeadingMarkers(in range: NSRange) {
        var index = skippingSpaces(from: range.location, limit: range.upperBound)
        let hashStart = index
        while index < range.upperBound, character(at: index) == "#" {
            index += 1
        }
        if index > hashStart {
            let markerEnd = skippingSpaces(from: index, limit: range.upperBound)
            delimiterRanges.append(NSRange(location: hashStart, length: markerEnd - hashStart))
            return
        }

        // Setext heading: dim the trailing `===` or `---` underline.
        let lastLine = text.lineRange(for: NSRange(location: max(range.location, range.upperBound - 1), length: 0))
        if lastLine.location > range.location {
            delimiterRanges.append(NSRange(location: lastLine.location, length: range.upperBound - lastLine.location))
        }
    }

    private mutating func dimBacktickRuns(in range: NSRange) {
        var start = range.location
        while start < range.upperBound, character(at: start) == "`" {
            start += 1
        }
        if start > range.location {
            delimiterRanges.append(NSRange(location: range.location, length: start - range.location))
        }

        var end = range.upperBound
        while end > start, character(at: end - 1) == "`" {
            end -= 1
        }
        if end < range.upperBound {
            delimiterRanges.append(NSRange(location: end, length: range.upperBound - end))
        }
    }

    private mutating func dimFenceLines(in range: NSRange) {
        for lineRange in lineRanges(in: range) {
            let start = skippingSpaces(from: lineRange.location, limit: lineRange.upperBound)
            let marker = character(at: start)
            guard marker == "`" || marker == "~" else { continue }
            delimiterRanges.append(lineRange)
        }
    }

    private mutating func dimLinePrefixes(in range: NSRange, marker: Character) {
        for lineRange in lineRanges(in: range) {
            var index = skippingSpaces(from: lineRange.location, limit: lineRange.upperBound)
            guard character(at: index) == marker else { continue }
            index += 1
            let markerEnd = skippingSpaces(from: index, limit: lineRange.upperBound)
            delimiterRanges.append(NSRange(location: lineRange.location, length: markerEnd - lineRange.location))
        }
    }

    private mutating func dimListMarker(in range: NSRange) {
        var index = skippingSpaces(from: range.location, limit: range.upperBound)
        guard let marker = character(at: index) else { return }

        if marker == "-" || marker == "*" || marker == "+" {
            index += 1
        } else if marker.isNumber {
            while index < range.upperBound, character(at: index)?.isNumber == true {
                index += 1
            }
            guard let separator = character(at: index), separator == "." || separator == ")" else { return }
            index += 1
        } else {
            return
        }

        let markerEnd = skippingSpaces(from: index, limit: range.upperBound)
        delimiterRanges.append(NSRange(location: range.location, length: markerEnd - range.location))
    }

    private func lineRanges(in range: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        var location = range.location
        while location < range.upperBound, location < text.length {
            let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
            let end = min(lineRange.upperBound, range.upperBound)
            ranges.append(NSRange(location: lineRange.location, length: max(0, end - lineRange.location)))
            location = max(lineRange.upperBound, location + 1)
        }
        return ranges
    }

    private func skippingSpaces(from index: Int, limit: Int) -> Int {
        var index = index
        while index < limit, let character = character(at: index), character == " " || character == "\t" {
            index += 1
        }
        return index
    }

    private func character(at index: Int) -> Character? {
        guard index >= 0, index < text.length else { return nil }
        guard let scalar = Unicode.Scalar(text.character(at: index)) else { return nil }
        return Character(scalar)
    }
}

/// swift-markdown reports positions as 1-based line numbers with UTF-8 byte
/// columns; `NSTextStorage` wants UTF-16 offsets, so precompute the mapping once
/// per parse instead of walking the string for every node.
struct SourcePositionMap {
    private let lineStartUTF8Offsets: [Int]
    private let utf16OffsetsByUTF8Offset: [Int]

    init(text: String) {
        var lineStarts = [0]
        var utf16Offsets: [Int] = []
        utf16Offsets.reserveCapacity(text.utf8.count + 1)

        var utf8Offset = 0
        var utf16Offset = 0
        for scalar in text.unicodeScalars {
            // Bytes inside a multi-byte scalar map to the scalar's own offset.
            for _ in 0..<scalar.utf8.count {
                utf16Offsets.append(utf16Offset)
            }
            utf8Offset += scalar.utf8.count
            utf16Offset += scalar.utf16.count
            if scalar == "\n" {
                lineStarts.append(utf8Offset)
            }
        }
        utf16Offsets.append(utf16Offset)

        self.lineStartUTF8Offsets = lineStarts
        self.utf16OffsetsByUTF8Offset = utf16Offsets
    }

    func nsRange(for sourceRange: SourceRange) -> NSRange? {
        guard let start = utf16Offset(for: sourceRange.lowerBound),
              let end = utf16Offset(for: sourceRange.upperBound),
              end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private func utf16Offset(for location: SourceLocation) -> Int? {
        let lineIndex = location.line - 1
        guard lineIndex >= 0, lineIndex < lineStartUTF8Offsets.count else { return nil }
        let utf8Offset = lineStartUTF8Offsets[lineIndex] + max(0, location.column - 1)
        guard utf8Offset < utf16OffsetsByUTF8Offset.count else { return nil }
        return utf16OffsetsByUTF8Offset[utf8Offset]
    }
}

private extension NSRange {
    func clamped(to bounds: NSRange) -> NSRange {
        let start = min(max(location, bounds.location), bounds.upperBound)
        let end = min(max(upperBound, bounds.location), bounds.upperBound)
        return NSRange(location: start, length: end - start)
    }
}
