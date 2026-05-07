import Foundation

// MARK: - AppStorageKey

/// UserDefaultsで使用するキーを一元管理する
enum AppStorageKey: String {
    // 表示設定
    case viewMode = "AppSettings.viewMode"
    case saveFormat = "AppSettings.saveFormat"
    // ファイルブラウザ状態
    case lastViewedFileName = "FileBrowser.lastViewedFileName"
}

// MARK: - UserDefaultsStorageProtocol

protocol UserDefaultsStorageProtocol: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
}

extension UserDefaultsStorageProtocol {
    func string(forKey key: AppStorageKey) -> String? {
        string(forKey: key.rawValue)
    }

    func set(_ value: String?, forKey key: AppStorageKey) {
        set(value, forKey: key.rawValue)
    }
}

// MARK: - UserDefaultsStorage

final class UserDefaultsStorage: UserDefaultsStorageProtocol {
    static let shared = UserDefaultsStorage()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
