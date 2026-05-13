import UIKit

protocol HapticsServiceProtocol: AnyObject {
    func notifySuccess()
    func notifyError()
}

final class HapticsService: HapticsServiceProtocol {
    func notifySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func notifyError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
