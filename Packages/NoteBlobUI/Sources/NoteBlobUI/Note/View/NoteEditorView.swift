import SwiftUI
import TextEditorKit

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct NoteEditorView: View {

    @Environment(\.horizontalContentMargin) private var horizontalMargin

    let editor: DocumentEditor
    let toolbarActions: [ToolbarAction]
    let undoRedoActions: [ToolbarAction]
    let menuActions: [ToolbarAction]
    let actionVersion: Int
    let onOpenNoteLink: ((URL) -> Void)?

    var body: some View {
        NoteTextEditor(
            editor: editor,
            toolbarActions: toolbarActions,
            undoRedoActions: undoRedoActions,
            menuActions: menuActions,
            horizontalInset: horizontalMargin,
            actionVersion: actionVersion,
            onOpenNoteLink: onOpenNoteLink
        )
        #if os(iOS)
            .ignoresSafeArea()
        #endif
    }
}

// MARK: - iOS

#if canImport(UIKit)

    private struct NoteTextEditor: UIViewRepresentable {

        private static let verticalInset: CGFloat = 16

        let editor: DocumentEditor
        let toolbarActions: [ToolbarAction]
        let undoRedoActions: [ToolbarAction]
        let menuActions: [ToolbarAction]
        let horizontalInset: CGFloat
        let actionVersion: Int
        let onOpenNoteLink: ((URL) -> Void)?

        func makeCoordinator() -> Coordinator {
            Coordinator(editor: editor)
        }

        func makeUIView(context: Context) -> NoteUITextView {
            let textView = NoteUITextView()
            textView.font = UIFont.monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                weight: .regular
            )
            textView.adjustsFontForContentSizeCategory = true
            textView.backgroundColor = .clear
            textView.textContainer.lineFragmentPadding = 0
            textView.contentInsetAdjustmentBehavior = .always
            textView.alwaysBounceVertical = true
            textView.keyboardDismissMode = .interactive
            // Markdown source: disable input rewrites that mangle literal
            // syntax. Smart dashes/quotes corrupt table separators and link
            // titles; autocapitalize breaks lowercase headings/list items;
            // smart insert/delete fiddles with whitespace around manually-
            // edited syntax. Autocorrect stays on — these are notes, not code.
            textView.smartDashesType = .no
            textView.smartQuotesType = .no
            textView.smartInsertDeleteType = .no
            textView.autocapitalizationType = .none
            textView.delegate = context.coordinator
            textView.shortcutActions = toolbarActions + undoRedoActions
            context.coordinator.onOpenNoteLink = onOpenNoteLink
            context.coordinator.setupTextEditor(for: textView)

            let accessoryBar = InputAccessoryBar()
            accessoryBar.update(
                actions: toolbarActions,
                undoRedoActions: undoRedoActions,
                moreActions: menuActions
            )
            context.coordinator.accessoryBar = accessoryBar
            textView.inputAccessoryView = accessoryBar

            context.coordinator.keyboardController = KeyboardController(scrollView: textView)

            DispatchQueue.main.async {
                if textView.text.isEmpty {
                    textView.becomeFirstResponder()
                }
            }

            return textView
        }

        func updateUIView(_ textView: NoteUITextView, context: Context) {
            context.coordinator.onOpenNoteLink = onOpenNoteLink
            textView.textContainerInset = UIEdgeInsets(
                top: Self.verticalInset,
                left: horizontalInset,
                bottom: Self.verticalInset,
                right: horizontalInset
            )
            textView.shortcutActions = toolbarActions + undoRedoActions
            context.coordinator.accessoryBar?.update(
                actions: toolbarActions,
                undoRedoActions: undoRedoActions,
                moreActions: menuActions
            )
        }

        final class Coordinator: NSObject, UITextViewDelegate, TextInput {
            let editor: DocumentEditor
            weak var textView: UITextView?
            var accessoryBar: InputAccessoryBar?
            var keyboardController: KeyboardController?
            weak var delegate: TextInputDelegate?
            var onOpenNoteLink: ((URL) -> Void)?

            init(editor: DocumentEditor) {
                self.editor = editor
            }

            @MainActor
            func setupTextEditor(for textView: UITextView) {
                self.textView = textView
                editor.attach(to: self)
            }

            // MARK: - TextInput

            func text() -> String { textView?.text ?? "" }
            func selectedRange() -> NSRange {
                textView?.selectedRange ?? NSRange(location: 0, length: 0)
            }
            func setText(_ text: String) { textView?.text = text }
            func setSelectedRange(_ range: NSRange) { textView?.selectedRange = range }
            func replaceCharacters(in range: NSRange, with string: String) {
                textView?.textStorage.replaceCharacters(in: range, with: string)
            }

            // MARK: - UITextViewDelegate

            func textView(
                _ textView: UITextView,
                shouldChangeTextIn range: NSRange,
                replacementText text: String
            ) -> Bool {
                delegate?.textWillChange(in: range, replacementString: text)
                return true
            }

            func textViewDidChange(_ textView: UITextView) {
                delegate?.textDidChange()
            }

            func textViewDidChangeSelection(_ textView: UITextView) {
                delegate?.selectionDidChange()
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
    }

    // MARK: - InputAccessoryBar

    private final class InputAccessoryBar: UIView {

        private static let barHeight: CGFloat = 52
        private static let verticalPadding: CGFloat = 4
        private static let horizontalPadding: CGFloat = 8
        private static let pillSpacing: CGFloat = 6
        private static let middleInnerPadding: CGFloat = 6

        private let leadingGlass: UIVisualEffectView
        private let middleGlass: UIVisualEffectView
        private let trailingGlass: UIVisualEffectView

        private let middleScrollView = UIScrollView()
        private let middleStackView = UIStackView()
        private let rootStackView = UIStackView()

        private var middleButtons: [UIButton] = []
        private var leadingButton: UIButton?
        private var trailingButton: UIButton?

        init() {
            leadingGlass = InputAccessoryBar.makeGlassView()
            middleGlass = InputAccessoryBar.makeGlassView()
            trailingGlass = InputAccessoryBar.makeGlassView()
            let totalHeight = Self.barHeight + Self.verticalPadding * 2
            super.init(
                frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: totalHeight))
            autoresizingMask = .flexibleWidth
            setupPills()
            setupMiddleScroll()
        }

        required init?(coder: NSCoder) { fatalError() }

        private static func makeGlassView() -> UIVisualEffectView {
            let glass = UIGlassEffect()
            glass.isInteractive = true
            let view = UIVisualEffectView(effect: glass)
            view.cornerConfiguration = .capsule()
            return view
        }

        func update(
            actions: [ToolbarAction],
            undoRedoActions: [ToolbarAction],
            moreActions: [ToolbarAction]
        ) {
            // Middle: format action buttons.
            for button in middleButtons { button.removeFromSuperview() }
            middleButtons.removeAll()
            for action in actions where !action.isHidden {
                let button: UIButton
                switch action.kind {
                case .button(let systemImage):
                    button = makeButton(systemImage: systemImage, action: action)
                case .menu(let systemImage, let options):
                    button = makeOptionsMenuButton(
                        systemImage: systemImage, options: options, action: action)
                }
                middleStackView.addArrangedSubview(button)
                middleButtons.append(button)
            }

            // Leading: undo/redo menu.
            leadingButton?.removeFromSuperview()
            leadingButton = nil
            if !undoRedoActions.isEmpty {
                let button = makeUndoRedoMenuButton(actions: undoRedoActions)
                leadingGlass.contentView.addSubview(button)
                pinButton(button, in: leadingGlass)
                leadingButton = button
            }
            leadingGlass.isHidden = leadingButton == nil

            // Trailing: "more" menu.
            trailingButton?.removeFromSuperview()
            trailingButton = nil
            if !moreActions.isEmpty {
                let button = makeMoreMenuButton(actions: moreActions)
                trailingGlass.contentView.addSubview(button)
                pinButton(button, in: trailingGlass)
                trailingButton = button
            }
            trailingGlass.isHidden = trailingButton == nil
        }

        private func setupPills() {
            rootStackView.axis = .horizontal
            rootStackView.alignment = .fill
            rootStackView.distribution = .fill
            rootStackView.spacing = Self.pillSpacing
            addSubview(rootStackView)
            rootStackView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                rootStackView.leadingAnchor.constraint(
                    equalTo: leadingAnchor, constant: Self.horizontalPadding),
                rootStackView.trailingAnchor.constraint(
                    equalTo: trailingAnchor, constant: -Self.horizontalPadding),
                rootStackView.topAnchor.constraint(
                    equalTo: topAnchor, constant: Self.verticalPadding),
                rootStackView.bottomAnchor.constraint(
                    equalTo: bottomAnchor, constant: -Self.verticalPadding),
            ])

            // UIVisualEffectView has no intrinsic content size, so the stack
            // would collapse a pill without explicit width. Side pills are
            // circular (width == bar height); middle stretches with low
            // hugging.
            leadingGlass.widthAnchor.constraint(equalToConstant: Self.barHeight).isActive = true
            trailingGlass.widthAnchor.constraint(equalToConstant: Self.barHeight).isActive = true
            middleGlass.setContentHuggingPriority(.defaultLow, for: .horizontal)

            rootStackView.addArrangedSubview(leadingGlass)
            rootStackView.addArrangedSubview(middleGlass)
            rootStackView.addArrangedSubview(trailingGlass)
        }

        private func setupMiddleScroll() {
            middleScrollView.showsHorizontalScrollIndicator = false
            middleGlass.contentView.addSubview(middleScrollView)
            middleScrollView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                middleScrollView.leadingAnchor.constraint(
                    equalTo: middleGlass.contentView.leadingAnchor),
                middleScrollView.trailingAnchor.constraint(
                    equalTo: middleGlass.contentView.trailingAnchor),
                middleScrollView.topAnchor.constraint(equalTo: middleGlass.contentView.topAnchor),
                middleScrollView.bottomAnchor.constraint(
                    equalTo: middleGlass.contentView.bottomAnchor),
            ])

            middleStackView.axis = .horizontal
            middleStackView.spacing = 2
            middleStackView.alignment = .center
            middleScrollView.addSubview(middleStackView)
            middleStackView.translatesAutoresizingMaskIntoConstraints = false
            // Width pinned to contentLayoutGuide so the stack defines the
            // scrollable content size; height pinned to frameLayoutGuide so it
            // matches the visible strip even when the stack's intrinsic content
            // width would leave the content guide's height ambiguous (which
            // makes the layout engine collapse the stack on iPad).
            NSLayoutConstraint.activate([
                middleStackView.leadingAnchor.constraint(
                    equalTo: middleScrollView.contentLayoutGuide.leadingAnchor,
                    constant: Self.middleInnerPadding),
                middleStackView.trailingAnchor.constraint(
                    equalTo: middleScrollView.contentLayoutGuide.trailingAnchor,
                    constant: -Self.middleInnerPadding),
                middleStackView.topAnchor.constraint(
                    equalTo: middleScrollView.frameLayoutGuide.topAnchor),
                middleStackView.bottomAnchor.constraint(
                    equalTo: middleScrollView.frameLayoutGuide.bottomAnchor),
                middleStackView.heightAnchor.constraint(
                    equalTo: middleScrollView.frameLayoutGuide.heightAnchor),
            ])
        }

        private func pinButton(_ button: UIButton, in host: UIVisualEffectView) {
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: host.contentView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: host.contentView.trailingAnchor),
                button.topAnchor.constraint(equalTo: host.contentView.topAnchor),
                button.bottomAnchor.constraint(equalTo: host.contentView.bottomAnchor),
            ])
        }

        private func makeButton(systemImage: String, action: ToolbarAction) -> UIButton {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: systemImage)
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 8, leading: 10, bottom: 8, trailing: 10)
            let button = UIButton(configuration: config)
            button.addAction(UIAction { _ in action.action() }, for: .touchUpInside)
            button.isEnabled = action.isEnabled
            updateButtonAppearance(button, isActive: action.isActive)
            return button
        }

        private func makeUndoRedoMenuButton(actions: [ToolbarAction]) -> UIButton {
            makeMenuButton(systemImage: "arrow.uturn.backward", actions: actions)
        }

        private func makeMoreMenuButton(actions: [ToolbarAction]) -> UIButton {
            makeMenuButton(systemImage: "ellipsis.circle", actions: actions)
        }

        private func makeMenuButton(systemImage: String, actions: [ToolbarAction]) -> UIButton {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: systemImage)
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 8, leading: 10, bottom: 8, trailing: 10)
            let menuItems: [UIMenuElement] = actions.map { action in
                let image: UIImage? = {
                    if case .button(let systemImage) = action.kind {
                        return UIImage(systemName: systemImage)
                    }
                    return nil
                }()
                let uiAction = UIAction(
                    title: String.localized(String.LocalizationValue(action.localizedTitle)),
                    image: image
                ) { _ in action.action() }
                if !action.isEnabled { uiAction.attributes.insert(.disabled) }
                return uiAction
            }
            let button = UIButton(configuration: config)
            button.menu = UIMenu(children: menuItems)
            button.showsMenuAsPrimaryAction = true
            button.tintColor = .label
            return button
        }

        private func makeOptionsMenuButton(
            systemImage: String,
            options: [ToolbarAction.MenuOption],
            action: ToolbarAction
        ) -> UIButton {
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: systemImage)
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 8, leading: 10, bottom: 8, trailing: 10)
            let menuItems = options.map { option in
                UIAction(
                    title: option.title,
                    image: option.systemImage.flatMap { UIImage(systemName: $0) },
                    attributes: option.isEnabled ? [] : [.disabled],
                    state: option.isActive ? .on : .off
                ) { _ in option.action() }
            }
            let button = UIButton(configuration: config)
            button.menu = UIMenu(children: menuItems)
            button.showsMenuAsPrimaryAction = true
            button.isEnabled = action.isEnabled
            updateButtonAppearance(button, isActive: action.isActive)
            return button
        }

        private func updateButtonAppearance(_ button: UIButton, isActive: Bool) {
            if isActive {
                button.tintColor = .systemBlue
                button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
                button.layer.cornerRadius = 8
                button.layer.cornerCurve = .continuous
            } else {
                button.tintColor = .label
                button.backgroundColor = nil
            }
        }
    }

    // MARK: - NoteUITextView

    final class NoteUITextView: UITextView {
        var shortcutActions: [ToolbarAction] = []

        override var keyCommands: [UIKeyCommand]? {
            shortcutActions.compactMap { action -> UIKeyCommand? in
                guard let shortcut = action.keyboardShortcut else { return nil }
                var modifiers: UIKeyModifierFlags = []
                if shortcut.command { modifiers.insert(.command) }
                if shortcut.shift { modifiers.insert(.shift) }
                let command = UIKeyCommand(
                    action: #selector(handleShortcut(_:)),
                    input: String(shortcut.key),
                    modifierFlags: modifiers,
                    propertyList: action.id
                )
                command.wantsPriorityOverSystemBehavior = true
                return command
            }
        }

        @objc private func handleShortcut(_ command: UIKeyCommand) {
            guard let id = command.propertyList as? String,
                let action = shortcutActions.first(where: { $0.id == id })
            else { return }
            action.action()
        }
    }

#endif

// MARK: - macOS

#if canImport(AppKit)

    private struct NoteTextEditor: NSViewRepresentable {

        private static let verticalInset: CGFloat = 16

        let editor: DocumentEditor
        let toolbarActions: [ToolbarAction]
        let undoRedoActions: [ToolbarAction]
        let menuActions: [ToolbarAction]
        let horizontalInset: CGFloat
        let actionVersion: Int
        let onOpenNoteLink: ((URL) -> Void)?

        func makeCoordinator() -> Coordinator {
            Coordinator(editor: editor)
        }

        func makeNSView(context: Context) -> NSScrollView {
            let scrollView = NSScrollView()
            scrollView.verticalScrollElasticity = .allowed
            scrollView.hasVerticalScroller = true
            scrollView.drawsBackground = false

            let textView = NoteNSTextView()
            textView.minSize = NSSize(width: 0, height: 0)
            textView.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.font = NSFont.monospacedSystemFont(
                ofSize: NSFont.systemFontSize, weight: .regular)
            textView.drawsBackground = false
            textView.isRichText = false
            textView.allowsUndo = false
            textView.textContainer?.lineFragmentPadding = 0
            // Markdown source: disable input rewrites that mangle literal
            // syntax. Smart dashes/quotes corrupt table separators and link
            // titles; text-replacement rewrites identifiers; auto link
            // detection produces attributed-text artifacts in plain markdown.
            // Spelling correction stays on — these are notes, not code.
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticLinkDetectionEnabled = false
            textView.delegate = context.coordinator
            textView.shortcutActions = toolbarActions + undoRedoActions

            scrollView.documentView = textView
            context.coordinator.onOpenNoteLink = onOpenNoteLink
            context.coordinator.setupTextEditor(for: textView)

            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }

            return scrollView
        }

        func updateNSView(_ scrollView: NSScrollView, context: Context) {
            context.coordinator.onOpenNoteLink = onOpenNoteLink
            guard let textView = scrollView.documentView as? NoteNSTextView else { return }
            textView.textContainerInset = NSSize(width: horizontalInset, height: Self.verticalInset)
            textView.shortcutActions = toolbarActions + undoRedoActions
        }

        final class Coordinator: NSObject, NSTextViewDelegate, TextInput {
            let editor: DocumentEditor
            weak var textView: NSTextView?
            weak var delegate: TextInputDelegate?
            var onOpenNoteLink: ((URL) -> Void)?

            init(editor: DocumentEditor) {
                self.editor = editor
            }

            @MainActor
            func setupTextEditor(for textView: NSTextView) {
                self.textView = textView
                editor.attach(to: self)
            }

            // MARK: - TextInput

            func text() -> String { textView?.string ?? "" }
            func selectedRange() -> NSRange {
                textView?.selectedRange() ?? NSRange(location: 0, length: 0)
            }
            func setText(_ text: String) { textView?.string = text }
            func setSelectedRange(_ range: NSRange) { textView?.setSelectedRange(range) }
            func replaceCharacters(in range: NSRange, with string: String) {
                textView?.textStorage?.replaceCharacters(in: range, with: string)
            }

            // MARK: - NSTextViewDelegate

            func textView(
                _ textView: NSTextView,
                shouldChangeTextIn affectedCharRange: NSRange,
                replacementString: String?
            ) -> Bool {
                delegate?.textWillChange(
                    in: affectedCharRange, replacementString: replacementString ?? "")
                return true
            }

            func textDidChange(_ notification: Notification) {
                delegate?.textDidChange()
            }

            func textViewDidChangeSelection(_ notification: Notification) {
                delegate?.selectionDidChange()
            }

            func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int)
                -> Bool
            {
                guard let url = link as? URL, url.scheme == nil else { return false }
                onOpenNoteLink?(url)
                return true
            }
        }
    }

    // MARK: - NoteNSTextView

    final class NoteNSTextView: NSTextView {
        var shortcutActions: [ToolbarAction] = []

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            for action in shortcutActions {
                guard let shortcut = action.keyboardShortcut,
                    event.matchesShortcut(shortcut)
                else { continue }
                action.action()
                return true
            }
            return super.performKeyEquivalent(with: event)
        }
    }

    extension NSEvent {
        fileprivate func matchesShortcut(_ shortcut: ToolbarAction.KeyboardShortcut) -> Bool {
            let charMatch: Bool
            if shortcut.key == "\t" {
                charMatch = keyCode == 48
            } else if shortcut.key == "\u{1B}" {
                charMatch = keyCode == 53
            } else {
                charMatch =
                    (charactersIgnoringModifiers ?? "").lowercased()
                    == String(shortcut.key).lowercased()
            }
            guard charMatch else { return false }
            var expected: NSEvent.ModifierFlags = []
            if shortcut.command { expected.insert(.command) }
            if shortcut.shift { expected.insert(.shift) }
            return self.modifierFlags.intersection(.deviceIndependentFlagsMask) == expected
        }
    }

#endif
