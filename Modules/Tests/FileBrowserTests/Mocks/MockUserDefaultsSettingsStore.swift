import Core

/// UserDefaultsSettingsStoreProtocolのテスト用モック（インメモリ、UserDefaultsには一切触れない）
final class MockUserDefaultsSettingsStore: UserDefaultsSettingsStoreProtocol {
    private var storage: [PartialKeyPath<UserDefaultsSettings>: Any] = [:]
    private let fallback = UserDefaultsSettings()
    var removeAllCallCount = 0

    subscript<T: Codable>(dynamicMember keyPath: KeyPath<UserDefaultsSettings, T>) -> T {
        get { (storage[keyPath] as? T) ?? fallback[keyPath: keyPath] }
        set { storage[keyPath] = newValue }
    }

    func removeAll() {
        removeAllCallCount += 1
        storage.removeAll()
    }
}
