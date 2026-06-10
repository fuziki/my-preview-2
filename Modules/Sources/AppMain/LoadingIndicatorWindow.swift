import UIKit
import Observation
import Core

final class LoadingIndicatorWindow: UIWindow {

    init(windowScene: UIWindowScene, tracker: FileLoadingTracker) {
        super.init(windowScene: windowScene)
        rootViewController = LoadingIndicatorViewController(tracker: tracker)
        windowLevel = .alert + 1
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isHidden = false
    }

    required init?(coder: NSCoder) { fatalError() }
}

private final class LoadingIndicatorViewController: UIViewController {

    private let tracker: FileLoadingTracker
    private let dotView = UIView()
    private var observationTask: Task<Void, Never>?
    private var streamContinuation: AsyncStream<Bool>.Continuation?

    init(tracker: FileLoadingTracker) {
        self.tracker = tracker
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        dotView.backgroundColor = .systemBlue
        dotView.layer.cornerRadius = 4
        dotView.alpha = 0
        dotView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dotView)

        NSLayoutConstraint.activate([
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),
            dotView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -24),
            dotView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        startObserving()
    }

    private func startObserving() {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        streamContinuation = continuation
        trackObservation(continuation: continuation)

        observationTask = Task { [weak self] in
            for await isLoading in stream {
                guard let self else { break }
                UIView.animate(withDuration: 0.2) {
                    self.dotView.alpha = isLoading ? 1 : 0
                }
            }
        }
    }

    // onChange は @Sendable nonisolated なので、Task { @MainActor in } 経由で再帰する
    private func trackObservation(continuation: AsyncStream<Bool>.Continuation) {
        _ = withObservationTracking {
            continuation.yield(tracker.isLoading)
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                self.trackObservation(continuation: continuation)
            }
        }
    }

    deinit {
        streamContinuation?.finish()
        observationTask?.cancel()
    }
}
