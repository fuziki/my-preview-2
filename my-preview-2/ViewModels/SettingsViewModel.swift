import Foundation
import Observation

// MARK: - SettingsViewModel

@Observable
final class SettingsViewModel {

    // MARK: - 設定値（変更時に自動でUserDefaultsに保存される）

    var viewMode: ViewMode {
        didSet { storage.set(viewMode.rawValue, forKey: .viewMode) }
    }

    var saveFormat: SaveFormat {
        didSet { storage.set(saveFormat.rawValue, forKey: .saveFormat) }
    }

    // MARK: - 依存関係

    private let storage: any UserDefaultsStorageProtocol

    // MARK: - 初期化

    init(storage: any UserDefaultsStorageProtocol = UserDefaultsStorage.shared) {
        self.storage = storage
        // UserDefaultsから復元する
        self.viewMode = ViewMode(rawValue: storage.string(forKey: .viewMode) ?? "") ?? .list
        self.saveFormat = SaveFormat(rawValue: storage.string(forKey: .saveFormat) ?? "") ?? .jpegAndRaw
    }
}
