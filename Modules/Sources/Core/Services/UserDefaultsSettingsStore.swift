import Foundation
import os

// MARK: - UserDefaultsStorableSettings

/// UserDefaultsSettingsStoreが永続化できる設定値の型が満たすべきプロトコル。
/// KeyPathと保存キーの対応表を提供する。対応表に無いプロパティはKeyPathから
/// 保存キーを自動生成する（UserDefaultsSettingsStore側で実行時ワーニングを出す）。
public protocol UserDefaultsStorableSettings {
    static var storageKeys: [PartialKeyPath<Self>: String] { get }
}

// MARK: - UserDefaultsSettingsStoreProtocol

/// UserDefaultsに永続化する設定値への型付きアクセスを提供する。
/// プロパティごとにCodableでエンコードして保存し、デフォルト値はValue側に一元化する。
@dynamicMemberLookup
public protocol UserDefaultsSettingsStoreProtocol<Value>: AnyObject {
    associatedtype Value: Codable & UserDefaultsStorableSettings

    subscript<T: Codable>(dynamicMember keyPath: KeyPath<Value, T>) -> T { get set }

    /// 全設定をUserDefaultsから削除する。以後のアクセスはデフォルト値を返す
    func removeAll()
}

// MARK: - UserDefaultsSettingsStore

/// Value.storageKeysの対応表を使ってUserDefaultsへの永続化を行う汎用ストア。
/// Valueには具体的な設定型（UserDefaultsSettingsなど）を指定する。
public final class UserDefaultsSettingsStore<Value: Codable & UserDefaultsStorableSettings>: UserDefaultsSettingsStoreProtocol {
    private let defaults: UserDefaults
    private let defaultValue: Value
    private let logger: Logger

    /// storageKeysに対応が無かったKeyPathに対して自動生成したキーのキャッシュ（removeAllで使う）
    private var generatedKeys: [String] = []

    public init(
        defaultValue: Value,
        defaults: UserDefaults,
        logger: Logger = Logger(subsystem: "Core", category: "UserDefaultsSettingsStore")
    ) {
        self.defaultValue = defaultValue
        self.defaults = defaults
        self.logger = logger
    }

    public subscript<T: Codable>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
        get {
            let key = storageKey(for: keyPath)
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue[keyPath: keyPath]
            }
            return decoded
        }
        set {
            let key = storageKey(for: keyPath)
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }

    public func removeAll() {
        for key in Set(Value.storageKeys.values).union(generatedKeys) {
            defaults.removeObject(forKey: key)
        }
    }

    /// storageKeysに対応が無い場合はKeyPathから保存キーを自動生成し、ワーニングを出す
    private func storageKey<T>(for keyPath: KeyPath<Value, T>) -> String {
        if let key = Value.storageKeys[keyPath] {
            return key
        }
        let generatedKey = "\(Value.self).\(String(describing: keyPath))"
        logger.warning("storageKeysに未登録のプロパティです。自動生成したキーを使用します: \(generatedKey, privacy: .public)")
        generatedKeys.append(generatedKey)
        return generatedKey
    }
}
