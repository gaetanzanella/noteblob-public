import BeautifulMermaid
import Foundation
import Markdown
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#endif

struct MarkdownAttributedStringParser {

    func parse(_ source: String) -> NSAttributedString {
        let document = Document(parsing: source)
        var visitor = AttributedStringVisitor()
        visitor.visit(document)
        let result = visitor.result
        // Trim trailing whitespace left by block-level "\n" appends
        while result.length > 0, result.string.last?.isWhitespace == true {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        return result
    }
}

// MARK: - State

private struct RenderState {
    var font: PlatformFont?
    var foregroundColor: PlatformColor = .label
    var paragraphStyle: NSParagraphStyle?
    var backgroundColor: PlatformColor?
    var link: URL?
    var isInsideListItem = false

    var attributes: [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: foregroundColor
        ]
        if let font { attrs[.font] = font }
        if let paragraphStyle { attrs[.paragraphStyle] = paragraphStyle }
        if let backgroundColor { attrs[.backgroundColor] = backgroundColor }
        if let link { attrs[.link] = link }
        return attrs
    }

}

// MARK: - Visitor

private struct AttributedStringVisitor: MarkupWalker {

    private(set) var result = NSMutableAttributedString()
    private var state = RenderState()

    // MARK: - Block elements

    mutating func visitHeading(_ heading: Heading) {
        let saved = state
        let textStyle: PlatformFont.TextStyle = switch heading.level {
        case 1: .title1
        case 2: .title2
        case 3: .title3
        default: .headline
        }
        state.font = applyBold(to: PlatformFont.preferredFont(forTextStyle: textStyle))
        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = heading.level <= 2 ? 16 : 10
        para.paragraphSpacing = 4
        state.paragraphStyle = para
        descendInto(heading)
        append("\n")
        state = saved
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        let saved = state
        if state.font == nil {
            state.font = PlatformFont.preferredFont(forTextStyle: .body)
        }
        let para = NSMutableParagraphStyle()
        if let existing = state.paragraphStyle as? NSMutableParagraphStyle {
            para.headIndent = existing.headIndent
            para.firstLineHeadIndent = existing.firstLineHeadIndent
            para.tabStops = existing.tabStops
            para.defaultTabInterval = existing.defaultTabInterval
        }
        para.paragraphSpacing = state.isInsideListItem ? (state.paragraphStyle as? NSMutableParagraphStyle)?.paragraphSpacing ?? 8 : 8
        state.paragraphStyle = para
        descendInto(paragraph)
        append("\n")
        state = saved
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        if codeBlock.language == "mermaid" {
            let code = codeBlock.code.hasSuffix("\n") ? String(codeBlock.code.dropLast()) : codeBlock.code
            let markdown = "```mermaid\n\(code)\n```"
            let attachment = SwiftUITextAttachment(markdown: markdown)
            let attrAttachment = NSMutableAttributedString(attachment: attachment)
            if let font = state.font {
                attrAttachment.addAttribute(.font, value: font, range: NSRange(location: 0, length: attrAttachment.length))
            }
            result.append(attrAttachment)
            append("\n")
            return
        }
        let saved = state
        let code = codeBlock.code.hasSuffix("\n") ? String(codeBlock.code.dropLast()) : codeBlock.code
        state.font = applyMonospaced(to: PlatformFont.preferredFont(forTextStyle: .body))
        state.foregroundColor = .secondaryLabel
        state.backgroundColor = PlatformColor.secondarySystemFill
        let para = NSMutableParagraphStyle()
        para.headIndent = 12
        para.firstLineHeadIndent = 12
        para.tailIndent = -12
        para.paragraphSpacingBefore = 8
        para.paragraphSpacing = 8
        state.paragraphStyle = para
        append(code)
        append("\n")
        state = saved
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        let saved = state
        state.foregroundColor = .secondaryLabel
        let para = NSMutableParagraphStyle()
        para.headIndent = 16
        para.firstLineHeadIndent = 16
        para.paragraphSpacingBefore = 4
        state.paragraphStyle = para
        descendInto(blockQuote)
        state = saved
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        let attachment = SwiftUITextAttachment(markdown: "---")
        let attrAttachment = NSMutableAttributedString(attachment: attachment)
        if let font = state.font {
            attrAttachment.addAttribute(.font, value: font, range: NSRange(location: 0, length: attrAttachment.length))
        }
        result.append(attrAttachment)
        append("\n")
    }

    // MARK: - Lists

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        let depth = listDepth(from: unorderedList)
        let markers = ["\u{2022}", "\u{25E6}", "\u{2023}"]
        let bulletMarker = markers[min(depth, markers.count - 1)]
        let indent = CGFloat(depth + 1) * 20
        for item in unorderedList.listItems {
            let saved = state
            state.paragraphStyle = listParagraphStyle(indent: indent)
            if let checkbox = item.checkbox {
                appendCheckbox(checked: checkbox == .checked)
                append("\t")
            } else {
                append("\(bulletMarker)\t")
            }
            visit(item)
            state = saved
        }
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let depth = listDepth(from: orderedList)
        let indent = CGFloat(depth + 1) * 20
        for (index, item) in orderedList.listItems.enumerated() {
            let saved = state
            let number = Int(orderedList.startIndex) + index
            state.paragraphStyle = listParagraphStyle(indent: indent)
            append("\(number).\t")
            visit(item)
            state = saved
        }
    }

    private func listParagraphStyle(indent: CGFloat) -> NSMutableParagraphStyle {
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = indent - 16
        para.headIndent = indent
        para.paragraphSpacing = 2
        para.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
        para.defaultTabInterval = indent
        return para
    }

    mutating func visitListItem(_ listItem: ListItem) {
        let saved = state
        state.isInsideListItem = true
        descendInto(listItem)
        state = saved
    }

    // MARK: - Tables

    mutating func visitTable(_ table: Markdown.Table) {
        let markdown = table.format()
        let attachment = SwiftUITextAttachment(markdown: markdown)
        let attrAttachment = NSMutableAttributedString(attachment: attachment)
        if let font = state.font {
            attrAttachment.addAttribute(.font, value: font, range: NSRange(location: 0, length: attrAttachment.length))
        }
        result.append(attrAttachment)
        append("\n")
    }

    // MARK: - Inline elements

    mutating func visitText(_ text: Markdown.Text) {
        append(text.string)
    }

    mutating func visitStrong(_ strong: Strong) {
        let saved = state
        let base = state.font ?? PlatformFont.preferredFont(forTextStyle: .body)
        state.font = applyBold(to: base)
        descendInto(strong)
        state = saved
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        let saved = state
        let base = state.font ?? PlatformFont.preferredFont(forTextStyle: .body)
        state.font = applyItalic(to: base)
        descendInto(emphasis)
        state = saved
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        let saved = state
        state.font = applyMonospaced(to: PlatformFont.preferredFont(forTextStyle: .body))
        state.foregroundColor = .secondaryLabel
        state.backgroundColor = PlatformColor.secondarySystemFill
        append(inlineCode.code)
        state = saved
    }

    mutating func visitLink(_ link: Markdown.Link) {
        let saved = state
        if let destination = link.destination {
            state.link = URL(string: destination)
        }
        descendInto(link)
        state = saved
    }

    mutating func visitImage(_ image: Markdown.Image) {
        let saved = state
        state.foregroundColor = .secondaryLabel
        let alt = image.plainText
        if !alt.isEmpty {
            append("[\(alt)]")
        }
        state = saved
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        append("\n")
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        append(" ")
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        let start = result.length
        descendInto(strikethrough)
        let range = NSRange(location: start, length: result.length - start)
        result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
    }

    // MARK: - Helpers

    private mutating func append(_ string: String) {
        result.append(NSAttributedString(string: string, attributes: state.attributes))
    }

    #if canImport(UIKit)
    private mutating func appendCheckbox(checked: Bool) {
        let imageName = checked ? "checkmark.circle.fill" : "circle"
        let color: UIColor = checked ? .systemGreen : .secondaryLabel
        let font = state.font ?? PlatformFont.preferredFont(forTextStyle: .body)
        let size = font.pointSize
        var config = UIImage.SymbolConfiguration(pointSize: size)
        config = config.applying(UIImage.SymbolConfiguration(paletteColors: [color]))
        let image = UIImage(systemName: imageName, withConfiguration: config)!
        let attachment = NSTextAttachment(image: image)
        let yOffset = (font.capHeight - size) / 2
        attachment.bounds = CGRect(x: 0, y: yOffset, width: size, height: size)
        result.append(NSAttributedString(attachment: attachment))
    }
    #else
    private mutating func appendCheckbox(checked: Bool) {
        let imageName = checked ? "checkmark.circle.fill" : "circle"
        let color: NSColor = checked ? .systemGreen : .secondaryLabelColor
        let font = state.font ?? PlatformFont.preferredFont(forTextStyle: .body)
        let size = font.pointSize
        let colors: [NSColor] = checked ? [.white, .systemGreen] : [color]
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(.init(paletteColors: colors))
        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)!
            .withSymbolConfiguration(config)!
        let attachment = NSTextAttachment()
        attachment.image = image
        let yOffset = (font.capHeight - size) / 2
        attachment.bounds = CGRect(x: 0, y: yOffset, width: size, height: size)
        result.append(NSAttributedString(attachment: attachment))
    }
    #endif

    private func listDepth(from node: Markup) -> Int {
        var depth = 0
        var current = node.parent
        while let p = current {
            if p is UnorderedList || p is OrderedList { depth += 1 }
            current = p.parent
        }
        return depth
    }

    private func applyBold(to font: PlatformFont) -> PlatformFont {
        #if canImport(UIKit)
        let descriptor = font.fontDescriptor
        let traits = descriptor.symbolicTraits.union(.traitBold)
        return UIFont(descriptor: descriptor.withSymbolicTraits(traits) ?? descriptor, size: font.pointSize)
        #else
        return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        #endif
    }

    private func applyMonospaced(to font: PlatformFont) -> PlatformFont {
        #if canImport(UIKit)
        let descriptor = font.fontDescriptor.withDesign(.monospaced) ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: font.pointSize)
        #else
        let descriptor = font.fontDescriptor.withDesign(.monospaced) ?? font.fontDescriptor
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
        #endif
    }

    private func applyItalic(to font: PlatformFont) -> PlatformFont {
        #if canImport(UIKit)
        let descriptor = font.fontDescriptor
        let traits = descriptor.symbolicTraits.union(.traitItalic)
        return UIFont(descriptor: descriptor.withSymbolicTraits(traits) ?? descriptor, size: font.pointSize)
        #else
        return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        #endif
    }
}

// MARK: - Table View

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(header).font(.body.bold())
                }
            }
            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell).font(.body)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - SwiftUI Text Attachment

private struct MarkdownBlockView: View {
    let source: String

    var body: some View {
        let document = Document(parsing: source)
        if let table = document.children.first(where: { $0 is Markdown.Table }) as? Markdown.Table {
            MarkdownTableView(
                headers: Array(table.head.cells).map(\.plainText),
                rows: table.body.rows.map { Array($0.cells).map(\.plainText) }
            )
        } else if let codeBlock = document.children.first(where: { $0 is CodeBlock }) as? CodeBlock,
                  codeBlock.language == "mermaid" {
            MermaidBlockView(source: codeBlock.code)
        } else {
            Divider().padding(.vertical, 8)
        }
    }
}

#if canImport(UIKit)
private final class SwiftUITextAttachment: NSTextAttachment, @unchecked Sendable {

    init(markdown: String) {
        super.init(data: markdown.data(using: .utf8), ofType: "public.utf8-plain-text")
        self.allowsTextAttachmentView = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.allowsTextAttachmentView = true
    }

    var markdown: String {
        contents.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    override var usesTextAttachmentView: Bool { true }

    override func viewProvider(
        for parentView: UIView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        SwiftUITextAttachmentViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}

private final class SwiftUITextAttachmentViewProvider: NSTextAttachmentViewProvider {

    override init(
        textAttachment: NSTextAttachment,
        parentView: UIView?,
        textLayoutManager: NSTextLayoutManager?,
        location: any NSTextLocation
    ) {
        super.init(
            textAttachment: textAttachment,
            parentView: parentView,
            textLayoutManager: textLayoutManager,
            location: location
        )
        tracksTextAttachmentViewBounds = true
    }

    private var markdown: String {
        (textAttachment as? SwiftUITextAttachment)?.markdown ?? ""
    }

    private func makeContent() -> some View {
        MarkdownBlockView(source: markdown)
    }

    override func loadView() {
        let hostingView = UIHostingController(rootView: makeContent()).view!
        hostingView.backgroundColor = .clear
        self.view = hostingView
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        let width = proposedLineFragment.width
        let hostingController = UIHostingController(rootView: makeContent())
        let size = hostingController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGRect(x: 0, y: 0, width: width, height: size.height)
    }
}

private struct MermaidBlockView: UIViewRepresentable {
    let source: String

    func makeUIView(context: Context) -> BeautifulMermaid.MermaidView {
        let view = BeautifulMermaid.MermaidView()
        view.source = source
        return view
    }

    func updateUIView(_ view: BeautifulMermaid.MermaidView, context: Context) {
        view.source = source
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BeautifulMermaid.MermaidView, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}

#elseif canImport(AppKit)
private final class SwiftUITextAttachment: NSTextAttachment, @unchecked Sendable {

    init(markdown: String) {
        super.init(data: markdown.data(using: .utf8), ofType: "public.utf8-plain-text")
        self.allowsTextAttachmentView = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.allowsTextAttachmentView = true
    }

    var markdown: String {
        contents.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    override var usesTextAttachmentView: Bool { true }

    override func viewProvider(
        for parentView: NSView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        SwiftUITextAttachmentViewProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}

private final class SwiftUITextAttachmentViewProvider: NSTextAttachmentViewProvider {

    override init(
        textAttachment: NSTextAttachment,
        parentView: NSView?,
        textLayoutManager: NSTextLayoutManager?,
        location: any NSTextLocation
    ) {
        super.init(
            textAttachment: textAttachment,
            parentView: parentView,
            textLayoutManager: textLayoutManager,
            location: location
        )
        tracksTextAttachmentViewBounds = true
    }

    private var markdown: String {
        (textAttachment as? SwiftUITextAttachment)?.markdown ?? ""
    }

    private func makeContent() -> some View {
        MarkdownBlockView(source: markdown)
    }

    override func loadView() {
        let hostingView = NSHostingView(rootView: makeContent())
        self.view = hostingView
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        let width = proposedLineFragment.width
        let hostingView = NSHostingView(rootView: makeContent().frame(maxWidth: width))
        let size = hostingView.fittingSize
        return CGRect(x: 0, y: 0, width: width, height: size.height)
    }
}

private struct MermaidBlockView: NSViewRepresentable {
    let source: String

    func makeNSView(context: Context) -> BeautifulMermaid.MermaidView {
        let view = BeautifulMermaid.MermaidView()
        view.source = source
        return view
    }

    func updateNSView(_ view: BeautifulMermaid.MermaidView, context: Context) {
        view.source = source
    }
}
#endif

// MARK: - PlatformColor helpers

#if canImport(UIKit)
private extension UIColor {
    static var secondarySystemFill: UIColor { .secondarySystemBackground }
}
#elseif canImport(AppKit)
private extension NSColor {
    static var secondaryLabel: NSColor { .secondaryLabelColor }
    static var separator: NSColor { .separatorColor }
    static var label: NSColor { .labelColor }
    static var secondarySystemFill: NSColor { .controlBackgroundColor }
}
#endif
