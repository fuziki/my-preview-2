import Core

/// UserDefaultsSettingsStoreProtocolのテスト用モック（インメモリ、UserDefaultsには一切触れない）
public final class MockUserDefaultsSettingsStore: UserDefaultsSettingsStoreProtocol {
    private var storage: [PartialKeyPath<UserDefaultsSettings>: Any] = [:]
    private let fallback = UserDefaultsSettings.default()
    public private(set) var removeAllCallCount = 0

    public init() {}

    public subscript<T: Codable>(dynamicMember keyPath: KeyPath<UserDefaultsSettings, T>) -> T {
        get { (storage[keyPath] as? T) ?? fallback[keyPath: keyPath] }
        set { storage[keyPath] = newValue }
    }

    public func removeAll() {
        removeAllCallCount += 1
        storage.removeAll()
    }
}
