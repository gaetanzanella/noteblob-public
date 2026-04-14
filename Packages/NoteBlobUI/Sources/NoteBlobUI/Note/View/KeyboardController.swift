#if canImport(UIKit)
import UIKit

@MainActor
final class KeyboardController {

    private weak var scrollView: UIScrollView?

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let scrollView else { return }
        let duration = notification.keyboardAnimationDuration
        let curve = notification.keyboardAnimationCurve

        UIView.animate(withDuration: duration, delay: 0, options: curve) {
            // Reset to zero — contentInsetAdjustmentBehavior handles safe area
            scrollView.contentInset.bottom = 0
            scrollView.verticalScrollIndicatorInsets.bottom = 0
        }
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let scrollView,
              let endFrame = notification.keyboardEndFrame,
              let window = scrollView.window else { return }

        let duration = notification.keyboardAnimationDuration
        let curve = notification.keyboardAnimationCurve

        let scrollViewFrame = scrollView.convert(scrollView.bounds, to: window)
        let overlap = scrollViewFrame.maxY - endFrame.minY

        // contentInsetAdjustmentBehavior = .always adds safeAreaInsets.bottom
        // automatically, so subtract it to avoid double-counting.
        let safeAreaBottom = scrollView.safeAreaInsets.bottom
        let bottomInset = max(0, overlap - safeAreaBottom)

        UIView.animate(withDuration: duration, delay: 0, options: curve) {
            scrollView.contentInset.bottom = bottomInset
            scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }
}

// MARK: - Notification helpers

private extension Notification {
    var keyboardEndFrame: CGRect? {
        userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
    }

    var keyboardAnimationDuration: TimeInterval {
        (userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
    }

    var keyboardAnimationCurve: UIView.AnimationOptions {
        guard let rawValue = userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return .curveEaseInOut
        }
        return UIView.AnimationOptions(rawValue: rawValue << 16)
    }
}
#endif
