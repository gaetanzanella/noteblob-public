import SwiftUI

struct MarkdownRendererView: View {

    @Environment(\.horizontalContentMargin) private var horizontalMargin

    let source: String
    let mode: PreviewMode
    /// Called when the user activates an internal (scheme-less) link. The
    /// URL's path component identifies the target note. External URLs are
    /// left to the system to open.
    let onOpenNoteLink: ((URL) -> Void)?

    public var body: some View {
        #if canImport(UIKit)
            UIMarkdownRendererView(
                source: source,
                mode: mode,
                horizontalInset: horizontalMargin,
                onOpenNoteLink: onOpenNoteLink
            )
            .ignoresSafeArea()
        #else
            NSMarkdownRendererView(
                source: source,
                mode: mode,
                horizontalInset: horizontalMargin,
                onOpenNoteLink: onOpenNoteLink
            )
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
        let onOpenNoteLink: ((URL) -> Void)?

        func makeCoordinator() -> LinkCoordinator {
            LinkCoordinator(onOpenNoteLink: onOpenNoteLink)
        }

        func makeUIView(context: Context) -> UITextView {
            let textView = UITextView()
            textView.isEditable = false
            textView.backgroundColor = .clear
            textView.adjustsFontForContentSizeCategory = true
            textView.contentInsetAdjustmentBehavior = .always
            textView.alwaysBounceVertical = true
            textView.delegate = context.coordinator
            return textView
        }

        func updateUIView(_ textView: UITextView, context: Context) {
            context.coordinator.onOpenNoteLink = onOpenNoteLink
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

    final class LinkCoordinator: NSObject, UITextViewDelegate {
        var onOpenNoteLink: ((URL) -> Void)?

        init(onOpenNoteLink: ((URL) -> Void)?) {
            self.onOpenNoteLink = onOpenNoteLink
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            guard URL.scheme == nil else { return true }
            onOpenNoteLink?(URL)
            return false
        }
    }

#elseif canImport(AppKit)
    import AppKit

    private struct NSMarkdownRendererView: NSViewRepresentable {

        private static let verticalInset: CGFloat = 16

        let source: String
        let mode: PreviewMode
        let horizontalInset: CGFloat
        let onOpenNoteLink: ((URL) -> Void)?

        func makeCoordinator() -> LinkCoordinator {
            LinkCoordinator(onOpenNoteLink: onOpenNoteLink)
        }

        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSTextView.scrollableTextView()
            scrollView.verticalScrollElasticity = .allowed
            let textView = scrollView.documentView as! NSTextView
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = false
            textView.textContainer?.lineFragmentPadding = 0
            textView.delegate = context.coordinator
            return scrollView
        }

        func updateNSView(_ scrollView: NSScrollView, context: Context) {
            context.coordinator.onOpenNoteLink = onOpenNoteLink
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

    final class LinkCoordinator: NSObject, NSTextViewDelegate {
        var onOpenNoteLink: ((URL) -> Void)?

        init(onOpenNoteLink: ((URL) -> Void)?) {
            self.onOpenNoteLink = onOpenNoteLink
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL, url.scheme == nil else { return false }
            onOpenNoteLink?(url)
            return true
        }
    }
#endif
