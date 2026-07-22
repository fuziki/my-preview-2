import Core

/// UserDefaultsStorageProtocolのテスト用フェイク（インメモリ）
final class FakeUserDefaultsStorage: UserDefaultsStorageProtocol {
    private var store: [String: String] = [:]

    func string(forKey key: String) -> String? {
        store[key]
    }

    func set(_ value: String?, forKey key: String) {
        store[key] = value
    }

    func removeObject(forKey key: String) {
        store[key] = nil
    }
}
