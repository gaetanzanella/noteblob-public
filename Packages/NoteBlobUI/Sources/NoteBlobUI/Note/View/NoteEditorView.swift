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
    let actionVersion: Int
    @FocusState private var isFocused: Bool

    var body: some View {
        NoteTextEditor(editor: editor, toolbarActions: toolbarActions, horizontalInset: horizontalMargin, actionVersion: actionVersion)
        #if os(iOS)
            .ignoresSafeArea()
        #endif
            .focused($isFocused)
    }
}

// MARK: - iOS

#if canImport(UIKit)

private struct NoteTextEditor: UIViewRepresentable {

    private static let verticalInset: CGFloat = 16

    let editor: DocumentEditor
    let toolbarActions: [ToolbarAction]
    let horizontalInset: CGFloat
    let actionVersion: Int

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
        textView.delegate = context.coordinator
        textView.shortcutActions = toolbarActions
        context.coordinator.setupTextEditor(for: textView)


        let accessoryBar = InputAccessoryBar()
        accessoryBar.update(actions: toolbarActions)
        context.coordinator.accessoryBar = accessoryBar
        textView.inputAccessoryView = accessoryBar

        context.coordinator.keyboardController = KeyboardController(scrollView: textView)

        return textView
    }

    func updateUIView(_ textView: NoteUITextView, context: Context) {
        textView.textContainerInset = UIEdgeInsets(
            top: Self.verticalInset,
            left: horizontalInset,
            bottom: Self.verticalInset,
            right: horizontalInset
        )
        textView.shortcutActions = toolbarActions
        context.coordinator.accessoryBar?.update(actions: toolbarActions)
    }

    final class Coordinator: NSObject, UITextViewDelegate, TextInput {
        let editor: DocumentEditor
        weak var textView: UITextView?
        var accessoryBar: InputAccessoryBar?
        var keyboardController: KeyboardController?
        weak var delegate: TextInputDelegate?

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
        func selectedRange() -> NSRange { textView?.selectedRange ?? NSRange(location: 0, length: 0) }
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
    }
}

// MARK: - InputAccessoryBar

private final class InputAccessoryBar: UIView {

    private static let barHeight: CGFloat = 44
    private static let verticalPadding: CGFloat = 4
    private static let horizontalPadding: CGFloat = 8
    private static let cornerRadius: CGFloat = 22

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let pillContainer = UIView()
    private var actionButtons: [(button: UIButton, action: ToolbarAction)] = []

    init() {
        let totalHeight = Self.barHeight + Self.verticalPadding * 2
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: totalHeight))
        autoresizingMask = .flexibleWidth
        setupPill()
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(actions: [ToolbarAction]) {
        for (button, _) in actionButtons {
            button.removeFromSuperview()
        }
        actionButtons.removeAll()

        for action in actions {
            switch action.kind {
            case .button(let systemImage):
                let button = makeButton(systemImage: systemImage, action: action)
                stackView.addArrangedSubview(button)
                actionButtons.append((button, action))
            case .headingMenu(let options):
                let button = makeHeadingMenuButton(options: options, action: action)
                stackView.addArrangedSubview(button)
                actionButtons.append((button, action))
            }
        }
    }

    private func setupPill() {
        pillContainer.backgroundColor = UIColor.secondarySystemBackground
        pillContainer.layer.cornerRadius = Self.cornerRadius
        pillContainer.layer.masksToBounds = true
        addSubview(pillContainer)
        pillContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            pillContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            pillContainer.topAnchor.constraint(equalTo: topAnchor, constant: Self.verticalPadding),
            pillContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.verticalPadding),
        ])
    }

    private func setupViews() {
        scrollView.showsHorizontalScrollIndicator = false
        pillContainer.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: pillContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: pillContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: pillContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pillContainer.bottomAnchor),
        ])

        stackView.axis = .horizontal
        stackView.spacing = 2
        stackView.alignment = .center
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    private func makeButton(systemImage: String, action: ToolbarAction) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemImage)
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in action.action() }, for: .touchUpInside)
        updateButtonAppearance(button, isActive: action.isActive)
        return button
    }

    private func makeHeadingMenuButton(options: [ToolbarAction.HeadingOption], action: ToolbarAction) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "textformat.size")
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        let menuItems = options.map { option in
            UIAction(title: option.title) { _ in option.action() }
        }
        let button = UIButton(configuration: config)
        button.menu = UIMenu(children: menuItems)
        button.showsMenuAsPrimaryAction = true
        updateButtonAppearance(button, isActive: action.isActive)
        return button
    }

    private func updateButtonAppearance(_ button: UIButton, isActive: Bool) {
        button.tintColor = isActive ? .systemBlue : .label
    }
}

// MARK: - NoteUITextView

final class NoteUITextView: UITextView {
    var shortcutActions: [ToolbarAction] = []

    override var keyCommands: [UIKeyCommand]? {
        shortcutActions.compactMap { action -> UIKeyCommand? in
            guard let shortcut = action.keyboardShortcut else { return nil }
            var modifiers: UIKeyModifierFlags = .command
            if shortcut.shift { modifiers.insert(.shift) }
            return UIKeyCommand(
                action: #selector(handleShortcut(_:)),
                input: String(shortcut.key),
                modifierFlags: modifiers,
                propertyList: action.id
            )
        }
    }

    @objc private func handleShortcut(_ command: UIKeyCommand) {
        guard let id = command.propertyList as? String,
              let action = shortcutActions.first(where: { $0.id == id }) else { return }
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
    let horizontalInset: CGFloat
    let actionVersion: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(editor: editor)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.verticalScrollElasticity = .allowed
        let textView = scrollView.documentView as! NSTextView
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        context.coordinator.setupTextEditor(for: textView)
        configureKeyBindings(for: textView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        textView.textContainerInset = NSSize(width: horizontalInset, height: Self.verticalInset)
        context.coordinator.shortcutActions = toolbarActions
    }

    private func configureKeyBindings(for textView: NSTextView, coordinator: Coordinator) {
        coordinator.shortcutActions = toolbarActions
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator, weak textView] event in
            guard let coordinator, let textView,
                  textView.window?.firstResponder === textView else { return event }
            for action in coordinator.shortcutActions {
                guard let shortcut = action.keyboardShortcut,
                      event.matchesShortcut(shortcut) else { continue }
                action.action()
                return nil
            }
            return event
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate, TextInput {
        let editor: DocumentEditor
        weak var textView: NSTextView?
        var shortcutActions: [ToolbarAction] = []
        weak var delegate: TextInputDelegate?

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
        func selectedRange() -> NSRange { textView?.selectedRange() ?? NSRange(location: 0, length: 0) }
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
            delegate?.textWillChange(in: affectedCharRange, replacementString: replacementString ?? "")
            return true
        }

        func textDidChange(_ notification: Notification) {
            delegate?.textDidChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            delegate?.selectionDidChange()
        }
    }
}

private extension NSEvent {
    func matchesShortcut(_ shortcut: ToolbarAction.KeyboardShortcut) -> Bool {
        let charMatch: Bool
        if shortcut.key == "\t" {
            charMatch = keyCode == 48
        } else {
            charMatch = (charactersIgnoringModifiers ?? "") == String(shortcut.key)
        }
        guard charMatch else { return false }
        var expected: NSEvent.ModifierFlags = [.command]
        if shortcut.shift { expected.insert(.shift) }
        return self.modifierFlags.intersection(.deviceIndependentFlagsMask) == expected
    }
}

#endif
