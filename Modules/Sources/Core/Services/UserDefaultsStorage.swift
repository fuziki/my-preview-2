import Foundation

// MARK: - AppStorageKey

/// UserDefaultsで使用するキーを一元管理する
public enum AppStorageKey: String, CaseIterable {
    // 表示設定
    case viewMode = "AppSettings.viewMode"
    case saveFormat = "AppSettings.saveFormat"
    case sortOrder = "AppSettings.sortOrder"
    case gridColumnCount = "AppSettings.gridColumnCount"
    // ファイルブラウザ状態
    case lastViewedFileName = "FileBrowser.lastViewedFileName"
}

// MARK: - UserDefaultsStorageProtocol

public protocol UserDefaultsStorageProtocol {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    func removeObject(forKey key: String)
}

public extension UserDefaultsStorageProtocol {
    func string(forKey key: AppStorageKey) -> String? {
        string(forKey: key.rawValue)
    }

    func set(_ value: String?, forKey key: AppStorageKey) {
        set(value, forKey: key.rawValue)
    }

    /// アプリが管理する全キーをUserDefaultsから削除する
    func removeAll() {
        for key in AppStorageKey.allCases {
            removeObject(forKey: key.rawValue)
        }
    }
}

// MARK: - UserDefaultsStorage

public final class UserDefaultsStorage: UserDefaultsStorageProtocol {
    public static let shared = UserDefaultsStorage()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func set(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
