import Core

/// HapticsServiceProtocolのテスト用モック
public final class MockHapticsService: HapticsServiceProtocol {
    public private(set) var notifySuccessCallCount = 0
    public private(set) var notifyErrorCallCount = 0

    public init() {}

    public func notifySuccess() {
        notifySuccessCallCount += 1
    }

    public func notifyError() {
        notifyErrorCallCount += 1
    }
}
