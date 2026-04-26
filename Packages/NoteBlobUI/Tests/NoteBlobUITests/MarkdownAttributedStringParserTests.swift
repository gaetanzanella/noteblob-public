import AppKit
import Foundation
import Testing

@testable import NoteBlobUI

struct MarkdownAttributedStringParserTests {

    private let parser = MarkdownAttributedStringParser()

    @Test func allElements() {
        let source = """
            # Title

            Hello **bold** and *italic* and `code` and ~~removed~~ and [link](http://example.com).

            > Quote

            ```
            let x = 1
            ```

            - Item 1
            - Item 2

            1. First
            2. Second
            """
        let result = parser.parse(source)
        let b = AttributedStringBuilder()

        let para = b.paragraphStyle()
        let headingPara = b.headingParagraphStyle(level: 1)
        let codePara = b.codeParagraphStyle()
        let quotePara = b.quoteParagraphStyle()
        let listPara = b.listParagraphStyle(depth: 0)
        let itemPara = b.listItemParagraphStyle(depth: 0, spacing: 2)

        let exp = b.expected(
            // # Title
            ("Title", b.attrs(font: b.headingFont(forTextStyle: .title1), paragraphStyle: headingPara)),
            ("\n", b.attrs(font: b.headingFont(forTextStyle: .title1), paragraphStyle: headingPara)),
            // Paragraph with inline elements
            ("Hello ", b.attrs(font: b.bodyFont, paragraphStyle: para)),
            ("bold", b.attrs(font: b.boldBodyFont, paragraphStyle: para)),
            (" and ", b.attrs(font: b.bodyFont, paragraphStyle: para)),
            ("italic", b.attrs(font: b.italicBodyFont, paragraphStyle: para)),
            (" and ", b.attrs(font: b.bodyFont, paragraphStyle: para)),
            ("code", b.attrs(font: b.monospacedBodyFont, color: b.secondaryLabel, backgroundColor: b.secondaryFill, paragraphStyle: para)),
            (" and ", b.attrs(font: b.bodyFont, paragraphStyle: para)),
            ("removed", b.attrs(font: b.bodyFont, paragraphStyle: para, strikethrough: true)),
            (" and ", b.attrs(font: b.bodyFont, paragraphStyle: para)),
            ("link", b.attrs(font: b.bodyFont, paragraphStyle: para, link: URL(string: "http://example.com"))),
            (".", b.attrs(font: b.bodyFont, paragraphStyle: para)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: para)),
            // > Quote
            ("Quote", b.attrs(font: b.bodyFont, color: b.secondaryLabel, paragraphStyle: quotePara)),
            ("\n", b.attrs(font: b.bodyFont, color: b.secondaryLabel, paragraphStyle: quotePara)),
            // Code block
            ("let x = 1", b.attrs(font: b.monospacedBodyFont, color: b.secondaryLabel, backgroundColor: b.secondaryFill, paragraphStyle: codePara)),
            ("\n", b.attrs(font: b.monospacedBodyFont, color: b.secondaryLabel, backgroundColor: b.secondaryFill, paragraphStyle: codePara)),
            // Unordered list
            ("\u{2022}\t", b.attrs(paragraphStyle: listPara)),
            ("Item 1", b.attrs(font: b.bodyFont, paragraphStyle: itemPara)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: itemPara)),
            ("\u{2022}\t", b.attrs(paragraphStyle: listPara)),
            ("Item 2", b.attrs(font: b.bodyFont, paragraphStyle: itemPara)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: itemPara)),
            // Ordered list
            ("1.\t", b.attrs(paragraphStyle: listPara)),
            ("First", b.attrs(font: b.bodyFont, paragraphStyle: itemPara)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: itemPara)),
            ("2.\t", b.attrs(paragraphStyle: listPara)),
            ("Second", b.attrs(font: b.bodyFont, paragraphStyle: itemPara))
        )
        b.assertEqual(result, exp)
    }

    @Test func multipleLevels() {
        let source = """
            # H1

            ## H2

            ### H3

            #### H4

            - A
              - B
                - C

            1. One
               1. Two
                  1. Three
            """
        let result = parser.parse(source)
        let b = AttributedStringBuilder()

        let h1Para = b.headingParagraphStyle(level: 1)
        let h2Para = b.headingParagraphStyle(level: 2)
        let h3Para = b.headingParagraphStyle(level: 3)
        let h4Para = b.headingParagraphStyle(level: 4)

        let h1Font = b.headingFont(forTextStyle: .title1)
        let h2Font = b.headingFont(forTextStyle: .title2)
        let h3Font = b.headingFont(forTextStyle: .title3)
        let h4Font = b.headingFont(forTextStyle: .headline)

        let listPara0 = b.listParagraphStyle(depth: 0)
        let listPara1 = b.listParagraphStyle(depth: 1)
        let listPara2 = b.listParagraphStyle(depth: 2)
        let itemPara0 = b.listItemParagraphStyle(depth: 0, spacing: 2)
        let itemPara1 = b.listItemParagraphStyle(depth: 1, spacing: 2)
        let itemPara2 = b.listItemParagraphStyle(depth: 2, spacing: 2)

        let exp = b.expected(
            // # H1
            ("H1", b.attrs(font: h1Font, paragraphStyle: h1Para)),
            ("\n", b.attrs(font: h1Font, paragraphStyle: h1Para)),
            // ## H2
            ("H2", b.attrs(font: h2Font, paragraphStyle: h2Para)),
            ("\n", b.attrs(font: h2Font, paragraphStyle: h2Para)),
            // ### H3
            ("H3", b.attrs(font: h3Font, paragraphStyle: h3Para)),
            ("\n", b.attrs(font: h3Font, paragraphStyle: h3Para)),
            // #### H4
            ("H4", b.attrs(font: h4Font, paragraphStyle: h4Para)),
            ("\n", b.attrs(font: h4Font, paragraphStyle: h4Para)),
            // Nested unordered list
            ("\u{2022}\t", b.attrs(paragraphStyle: listPara0)),
            ("A", b.attrs(font: b.bodyFont, paragraphStyle: itemPara0)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: itemPara0)),
            ("\u{25E6}\t", b.attrs(paragraphStyle: listPara1)),
            ("B", b.attrs(font: b.bodyFont, paragraphStyle: itemPara1)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: itemPara1)),
            ("\u{2023}\t", b.attrs(paragraphStyle: listPara2)),
            ("C", b.attrs(font: b.bodyFont, paragraphStyle: itemPara2)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: itemPara2)),
            // Nested ordered list
            ("1.\t", b.attrs(paragraphStyle: listPara0)),
            ("One", b.attrs(font: b.bodyFont, paragraphStyle: itemPara0)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: itemPara0)),
            ("1.\t", b.attrs(paragraphStyle: listPara1)),
            ("Two", b.attrs(font: b.bodyFont, paragraphStyle: itemPara1)),
            ("\n", b.attrs(font: b.bodyFont, paragraphStyle: itemPara1)),
            ("1.\t", b.attrs(paragraphStyle: listPara2)),
            ("Three", b.attrs(font: b.bodyFont, paragraphStyle: itemPara2))
        )
        b.assertEqual(result, exp)
    }

    @Test func relativePathLinkIsTappable() {
        let result = parser.parse("[note](folder/other.md)")
        var foundLink: URL?
        result.enumerateAttribute(.link, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if let url = value as? URL { foundLink = url }
        }
        #expect(foundLink == URL(string: "folder/other.md"))
        #expect(foundLink?.scheme == nil)
    }
}

// MARK: - Builder

struct AttributedStringBuilder {

    let bodyFont = NSFont.preferredFont(forTextStyle: .body)
    let labelColor = NSColor.labelColor
    let secondaryLabel = NSColor.secondaryLabelColor
    let secondaryFill = NSColor.controlBackgroundColor

    var boldBodyFont: NSFont {
        NSFontManager.shared.convert(bodyFont, toHaveTrait: .boldFontMask)
    }

    var italicBodyFont: NSFont {
        NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
    }

    var monospacedBodyFont: NSFont {
        let descriptor = bodyFont.fontDescriptor.withDesign(.monospaced) ?? bodyFont.fontDescriptor
        return NSFont(descriptor: descriptor, size: bodyFont.pointSize) ?? bodyFont
    }

    func headingFont(forTextStyle style: NSFont.TextStyle) -> NSFont {
        let base = NSFont.preferredFont(forTextStyle: style)
        return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
    }

    func expected(_ parts: (String, [NSAttributedString.Key: Any])...) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (text, attrs) in parts {
            result.append(NSAttributedString(string: text, attributes: attrs))
        }
        return result
    }

    func attrs(
        font: NSFont? = nil,
        color: NSColor? = nil,
        backgroundColor: NSColor? = nil,
        paragraphStyle: NSParagraphStyle? = nil,
        link: URL? = nil,
        strikethrough: Bool = false
    ) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color ?? labelColor
        ]
        if let font { attrs[.font] = font }
        if let backgroundColor { attrs[.backgroundColor] = backgroundColor }
        if let paragraphStyle { attrs[.paragraphStyle] = paragraphStyle }
        if let link { attrs[.link] = link }
        if strikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return attrs
    }

    func paragraphStyle(spacing: CGFloat = 8) -> NSMutableParagraphStyle {
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = spacing
        return para
    }

    func headingParagraphStyle(level: Int) -> NSMutableParagraphStyle {
        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = level <= 2 ? 16 : 10
        para.paragraphSpacing = 4
        return para
    }

    func codeParagraphStyle() -> NSMutableParagraphStyle {
        let para = NSMutableParagraphStyle()
        para.headIndent = 12
        para.firstLineHeadIndent = 12
        para.tailIndent = -12
        para.paragraphSpacingBefore = 8
        para.paragraphSpacing = 8
        return para
    }

    func quoteParagraphStyle() -> NSMutableParagraphStyle {
        let para = NSMutableParagraphStyle()
        para.headIndent = 16
        para.firstLineHeadIndent = 16
        para.paragraphSpacing = 8
        return para
    }

    func listParagraphStyle(depth: Int) -> NSMutableParagraphStyle {
        let indent = CGFloat(depth + 1) * 20
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = indent - 16
        para.headIndent = indent
        para.paragraphSpacing = 2
        para.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
        para.defaultTabInterval = indent
        return para
    }

    func listItemParagraphStyle(depth: Int, spacing: CGFloat = 8) -> NSMutableParagraphStyle {
        let indent = CGFloat(depth + 1) * 20
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = indent - 16
        para.headIndent = indent
        para.paragraphSpacing = spacing
        para.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
        para.defaultTabInterval = indent
        return para
    }

    func assertEqual(_ actual: NSAttributedString, _ expected: NSAttributedString, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(actual.string == expected.string, "Text mismatch", sourceLocation: sourceLocation)
        guard actual.string == expected.string else { return }
        let fullRange = NSRange(location: 0, length: actual.length)
        let checkedKeys: [NSAttributedString.Key] = [
            .font, .foregroundColor, .backgroundColor, .paragraphStyle, .link, .strikethroughStyle
        ]
        for key in checkedKeys {
            actual.enumerateAttribute(key, in: fullRange) { actualValue, range, _ in
                let expectedValue = expected.attribute(key, at: range.location, effectiveRange: nil)
                let rangeStr = "\(range.location)..<\(range.location + range.length)"
                let substring = (actual.string as NSString).substring(with: range)
                if let a = actualValue, let e = expectedValue {
                    #expect(
                        "\(a)" == "\(e)",
                        "Attribute \(key.rawValue) mismatch at \(rangeStr) (\"\(substring)\"): \(a) != \(e)",
                        sourceLocation: sourceLocation
                    )
                } else if actualValue != nil || expectedValue != nil {
                    #expect(
                        actualValue == nil && expectedValue == nil,
                        "Attribute \(key.rawValue) presence mismatch at \(rangeStr) (\"\(substring)\"): actual=\(String(describing: actualValue)), expected=\(String(describing: expectedValue))",
                        sourceLocation: sourceLocation
                    )
                }
            }
        }
    }
}
