import Foundation

// MARK: - ViewMode

public enum ViewMode: String, Codable {
    case list, grid
}

// MARK: - FileSortOrder

public enum FileSortOrder: String, Codable {
    case dateDescending  // 新しい順
    case dateAscending   // 古い順（デフォルト）
}

// MARK: - SaveFormat

public enum SaveFormat: String, Codable {
    case jpeg
    case jpegAndRaw

    public var displayName: String {
        switch self {
        case .jpeg: "JPEG"
        case .jpegAndRaw: "JPEG + RAW"
        }
    }
}

// MARK: - UserDefaultsSettings

/// UserDefaultsへ永続化する設定値をまとめて保持する。
/// UserDefaultsSettingsStoreがこの型のプロパティ単位でCodableエンコードして保存する。
public struct UserDefaultsSettings: Codable {
    public var viewMode: ViewMode
    public var saveFormat: SaveFormat
    public var sortOrder: FileSortOrder
    public var gridColumnCount: Int
    public var isRatingEnabled: Bool
    public var ratingFilter: RatingFilter?
    public var colorLabelFilter: Set<PhotoColorLabel>
    public var lastViewedFileName: String?

    public init(
        viewMode: ViewMode,
        saveFormat: SaveFormat,
        sortOrder: FileSortOrder,
        gridColumnCount: Int,
        isRatingEnabled: Bool,
        ratingFilter: RatingFilter?,
        colorLabelFilter: Set<PhotoColorLabel>,
        lastViewedFileName: String?
    ) {
        self.viewMode = viewMode
        self.saveFormat = saveFormat
        self.sortOrder = sortOrder
        self.gridColumnCount = gridColumnCount
        self.isRatingEnabled = isRatingEnabled
        self.ratingFilter = ratingFilter
        self.colorLabelFilter = colorLabelFilter
        self.lastViewedFileName = lastViewedFileName
    }

    /// デフォルト値の定義箇所はここのみ
    public static func `default`() -> Self {
        Self(
            viewMode: .grid,
            saveFormat: .jpeg,
            sortOrder: .dateAscending,
            gridColumnCount: 3,
            isRatingEnabled: true,
            ratingFilter: nil,
            colorLabelFilter: [],
            lastViewedFileName: nil
        )
    }

}

// MARK: - UserDefaultsSettingsStoreProtocol

/// UserDefaultsに永続化するアプリ設定への型付きアクセスを提供する。
/// プロパティごとにCodableでエンコードして保存し、デフォルト値はUserDefaultsSettings.default()に一元化する。
@dynamicMemberLookup
public protocol UserDefaultsSettingsStoreProtocol: AnyObject {
    subscript<T: Codable>(dynamicMember keyPath: KeyPath<UserDefaultsSettings, T>) -> T { get set }

    /// 全設定をUserDefaultsから削除する。以後のアクセスはデフォルト値を返す
    func removeAll()
}

// MARK: - UserDefaultsSettingsStore

public final class UserDefaultsSettingsStore: UserDefaultsSettingsStoreProtocol {
    /// KeyPathと保存キーの対応表。プロパティ名を変えてもここを更新しない限り
    /// 保存キーは変わらない（=既存ユーザーの設定を壊さない）
    private static let storageKeys: [PartialKeyPath<UserDefaultsSettings>: String] = [
        \UserDefaultsSettings.viewMode: "UserDefaultsSettingsStore.viewMode",
        \UserDefaultsSettings.saveFormat: "UserDefaultsSettingsStore.saveFormat",
        \UserDefaultsSettings.sortOrder: "UserDefaultsSettingsStore.sortOrder",
        \UserDefaultsSettings.gridColumnCount: "UserDefaultsSettingsStore.gridColumnCount",
        \UserDefaultsSettings.isRatingEnabled: "UserDefaultsSettingsStore.isRatingEnabled",
        \UserDefaultsSettings.ratingFilter: "UserDefaultsSettingsStore.ratingFilter",
        \UserDefaultsSettings.colorLabelFilter: "UserDefaultsSettingsStore.colorLabelFilter",
        \UserDefaultsSettings.lastViewedFileName: "UserDefaultsSettingsStore.lastViewedFileName",
    ]

    // テストでのみ使用できる（storageKeysが全プロパティを網羅しているかの検証用）
    static var storageKeysForTest: [PartialKeyPath<UserDefaultsSettings>: String] { storageKeys }

    private let defaults: UserDefaults
    private let fallback = UserDefaultsSettings.default()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public subscript<T: Codable>(dynamicMember keyPath: KeyPath<UserDefaultsSettings, T>) -> T {
        get {
            guard let key = Self.storageKeys[keyPath],
                  let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                return fallback[keyPath: keyPath]
            }
            return decoded
        }
        set {
            guard let key = Self.storageKeys[keyPath],
                  let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }

    public func removeAll() {
        for key in Self.storageKeys.values {
            defaults.removeObject(forKey: key)
        }
    }
}
