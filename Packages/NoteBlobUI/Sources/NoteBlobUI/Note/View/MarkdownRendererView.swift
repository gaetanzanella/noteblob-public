import SwiftUI

struct MarkdownRendererView: View {

    @Environment(\.horizontalContentMargin) private var horizontalMargin

    private let source: String
    private let mode: PreviewMode

    init(source: String, mode: PreviewMode = .formatted) {
        self.source = source
        self.mode = mode
    }

    public var body: some View {
        #if canImport(UIKit)
            UIMarkdownRendererView(source: source, mode: mode, horizontalInset: horizontalMargin)
                .ignoresSafeArea()
        #else
            NSMarkdownRendererView(source: source, mode: mode, horizontalInset: horizontalMargin)
        #endif
    }
}

#if canImport(UIKit)
    import UIKit

    private struct UIMarkdownRendererView: UIViewRepresentable {

        private static let verticalInset: CGFloat = 16

        let source: String
        let mode: PreviewMode
        let horizontalInset: CGFloat

        func makeUIView(context: Context) -> UITextView {
            let textView = UITextView()
            textView.isEditable = false
            textView.backgroundColor = .clear
            textView.adjustsFontForContentSizeCategory = true
            textView.contentInsetAdjustmentBehavior = .always
            textView.alwaysBounceVertical = true
            return textView
        }

        func updateUIView(_ textView: UITextView, context: Context) {
            textView.textContainerInset = UIEdgeInsets(
                top: Self.verticalInset,
                left: horizontalInset,
                bottom: Self.verticalInset,
                right: horizontalInset
            )
            switch mode {
            case .raw:
                textView.font = UIFont.monospacedSystemFont(
                    ofSize: UIFont.preferredFont(
                        forTextStyle: .body
                    ).pointSize, weight: .regular)
                textView.textColor = .label
                textView.text = source
            case .formatted:
                textView.attributedText = MarkdownAttributedStringParser().parse(source)
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    private struct NSMarkdownRendererView: NSViewRepresentable {

        private static let verticalInset: CGFloat = 16

        let source: String
        let mode: PreviewMode
        let horizontalInset: CGFloat

        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSTextView.scrollableTextView()
            scrollView.verticalScrollElasticity = .allowed
            let textView = scrollView.documentView as! NSTextView
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = false
            textView.textContainer?.lineFragmentPadding = 0
            return scrollView
        }

        func updateNSView(_ scrollView: NSScrollView, context: Context) {
            let textView = scrollView.documentView as! NSTextView
            textView.textContainerInset = NSSize(width: horizontalInset, height: Self.verticalInset)
            switch mode {
            case .raw:
                let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 0
                paragraphStyle.paragraphSpacing = 0
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: NSColor.labelColor,
                ]
                textView.textStorage?.setAttributedString(
                    NSAttributedString(string: source, attributes: attrs))
            case .formatted:
                textView.textStorage?.setAttributedString(
                    MarkdownAttributedStringParser().parse(source))
            }
        }
    }
#endif
