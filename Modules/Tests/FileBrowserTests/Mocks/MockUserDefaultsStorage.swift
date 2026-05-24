import Core

/// UserDefaultsStorageProtocolのテスト用モック
final class MockUserDefaultsStorage: UserDefaultsStorageProtocol {
    private var store: [String: String] = [:]
    var setCallCount = 0

    func string(forKey key: String) -> String? {
        store[key]
    }

    func set(_ value: String?, forKey key: String) {
        setCallCount += 1
        store[key] = value
    }
}
