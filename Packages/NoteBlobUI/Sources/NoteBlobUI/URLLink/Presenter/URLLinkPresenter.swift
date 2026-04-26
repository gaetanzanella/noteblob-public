import Foundation

// MARK: - Navigation

public struct URLLinkNavigationPayload {
    public let onConfirmed: (String, URL) -> Void

    public init(onConfirmed: @escaping (String, URL) -> Void) {
        self.onConfirmed = onConfirmed
    }
}

enum URLLinkViewAction {
    case updateTitle(String)
    case updateURL(String)
    case confirm
}

// MARK: - ViewModel

struct URLLinkViewModel {
    let title: String
    let urlString: String
    let isConfirmEnabled: Bool
}

// MARK: - State

private struct URLLinkState {
    var title: String = ""
    var urlString: String = ""
}

// MARK: - Presenter

@Observable
@MainActor
public final class URLLinkPresenter {

    private var state = URLLinkState()
    private let onConfirmed: (String, URL) -> Void

    public init(onConfirmed: @escaping (String, URL) -> Void) {
        self.onConfirmed = onConfirmed
    }

    func viewModel() -> URLLinkViewModel {
        URLLinkViewModel(
            title: state.title,
            urlString: state.urlString,
            isConfirmEnabled: normalizedURL() != nil
        )
    }

    func on(_ action: URLLinkViewAction) {
        switch action {
        case .updateTitle(let title):
            state.title = title
        case .updateURL(let urlString):
            state.urlString = urlString
        case .confirm:
            guard let url = normalizedURL() else { return }
            onConfirmed(state.title, url)
        }
    }

    private func normalizedURL() -> URL? {
        let trimmed = state.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        guard url.host?.isEmpty == false else { return nil }
        return url
    }
}
