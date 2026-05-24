import UIKit

public protocol HapticsServiceProtocol {
    func notifySuccess()
    func notifyError()
}

public final class HapticsService: HapticsServiceProtocol {
    public init() {}

    public func notifySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public func notifyError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
