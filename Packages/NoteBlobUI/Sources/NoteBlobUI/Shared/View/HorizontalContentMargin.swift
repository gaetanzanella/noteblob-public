import SwiftUI

private struct HorizontalContentMarginKey: EnvironmentKey {
    static let defaultValue: CGFloat = 16
}

extension EnvironmentValues {
    var horizontalContentMargin: CGFloat {
        get { self[HorizontalContentMarginKey.self] }
        set { self[HorizontalContentMarginKey.self] = newValue }
    }
}

// MARK: - Readable Content Guide Provider

#if canImport(UIKit)
    import UIKit

    struct ReadableContentMarginModifier: ViewModifier {
        static let minimumMargin: CGFloat = 16

        @State private var margin: CGFloat = minimumMargin

        func body(content: Content) -> some View {
            content
                .environment(\.horizontalContentMargin, margin)
                .background(
                    ReadableContentMarginReader(margin: $margin)
                )
        }
    }

    private struct ReadableContentMarginReader: UIViewRepresentable {
        @Binding var margin: CGFloat

        func makeUIView(context: Context) -> ReadableGuideView {
            ReadableGuideView()
        }

        func updateUIView(_ uiView: ReadableGuideView, context: Context) {
            uiView.onMarginChange = { newMargin in
                margin = newMargin
            }
        }
    }

    private final class ReadableGuideView: UIView {
        var onMarginChange: ((CGFloat) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let superview else { return }
            let leadingMargin = max(
                ReadableContentMarginModifier.minimumMargin,
                superview.readableContentGuide.layoutFrame.minX
            )
            DispatchQueue.main.async { [weak self] in
                self?.onMarginChange?(leadingMargin)
            }
        }
    }

#elseif canImport(AppKit)
    import AppKit

    struct ReadableContentMarginModifier: ViewModifier {
        private static let maxContentWidth: CGFloat = 1200
        private static let minimumMargin: CGFloat = 40

        @State private var margin: CGFloat = 40

        func body(content: Content) -> some View {
            content
                .environment(\.horizontalContentMargin, margin)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { width in
                    margin = max(Self.minimumMargin, (width - Self.maxContentWidth) / 2)
                }
        }
    }
#endif

extension View {
    func readableContentMargin() -> some View {
        modifier(ReadableContentMarginModifier())
    }
}
