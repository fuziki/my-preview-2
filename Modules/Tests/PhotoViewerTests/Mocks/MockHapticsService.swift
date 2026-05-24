import Core

/// HapticsServiceProtocolのテスト用モック
final class MockHapticsService: HapticsServiceProtocol {
    var notifySuccessCallCount = 0
    var notifyErrorCallCount = 0

    func notifySuccess() {
        notifySuccessCallCount += 1
    }

    func notifyError() {
        notifyErrorCallCount += 1
    }
}
