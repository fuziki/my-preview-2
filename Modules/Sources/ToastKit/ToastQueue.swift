import Foundation

@MainActor
final class ToastQueue {
    static let shared = ToastQueue()

    private var queue: [ToastItem] = []
    private var isPresenting = false

    func enqueue(_ item: ToastItem) {
        queue.append(item)
        dequeueIfNeeded()
    }

    private func dequeueIfNeeded() {
        guard !isPresenting, !queue.isEmpty else { return }
        let item = queue.removeFirst()
        isPresenting = true
        ToastWindowManager.shared.present(item: item) { [weak self] in
            guard let self else { return }
            self.isPresenting = false
            let spacing = ToastKit.configuration.interItemSpacing
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(spacing))
                self.dequeueIfNeeded()
            }
        }
    }
}
