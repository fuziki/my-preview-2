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

/// UserDefaultsへ永続化する設定値とそのデフォルト値をまとめて保持する。
/// UserDefaultsSettingsStoreがこの型のプロパティ単位でCodableエンコードして保存する。
public struct UserDefaultsSettings: Codable {
    public var viewMode: ViewMode = .grid
    public var saveFormat: SaveFormat = .jpeg
    public var sortOrder: FileSortOrder = .dateAscending
    public var gridColumnCount: Int = 3
    public var isRatingEnabled: Bool = true
    public var ratingFilter: RatingFilter?
    public var colorLabelFilter: Set<PhotoColorLabel> = []
    public var lastViewedFileName: String?

    // Codable準拠により暗黙のmemberwiseイニシャライザが生成されないため明示的に定義する
    public init(
        viewMode: ViewMode = .grid,
        saveFormat: SaveFormat = .jpeg,
        sortOrder: FileSortOrder = .dateAscending,
        gridColumnCount: Int = 3,
        isRatingEnabled: Bool = true,
        ratingFilter: RatingFilter? = nil,
        colorLabelFilter: Set<PhotoColorLabel> = [],
        lastViewedFileName: String? = nil
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

    /// UserDefaultsへの保存キー名。プロパティのリネームに追従させないため明示的に固定する
    static let keyNames: [PartialKeyPath<UserDefaultsSettings>: String] = [
        \.viewMode: "viewMode",
        \.saveFormat: "saveFormat",
        \.sortOrder: "sortOrder",
        \.gridColumnCount: "gridColumnCount",
        \.isRatingEnabled: "isRatingEnabled",
        \.ratingFilter: "ratingFilter",
        \.colorLabelFilter: "colorLabelFilter",
        \.lastViewedFileName: "lastViewedFileName",
    ]
}

// MARK: - UserDefaultsSettingsStoreProtocol

/// UserDefaultsに永続化するアプリ設定への型付きアクセスを提供する。
/// プロパティごとにCodableでエンコードして保存し、デフォルト値はUserDefaultsSettings()に一元化する。
@dynamicMemberLookup
public protocol UserDefaultsSettingsStoreProtocol: AnyObject {
    subscript<T: Codable>(dynamicMember keyPath: KeyPath<UserDefaultsSettings, T>) -> T { get set }

    /// 全設定をUserDefaultsから削除する。以後のアクセスはデフォルト値を返す
    func removeAll()
}

// MARK: - UserDefaultsSettingsStore

public final class UserDefaultsSettingsStore: UserDefaultsSettingsStoreProtocol {
    private let defaults: UserDefaults
    private let fallback = UserDefaultsSettings()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public subscript<T: Codable>(dynamicMember keyPath: KeyPath<UserDefaultsSettings, T>) -> T {
        get {
            guard let key = UserDefaultsSettings.keyNames[keyPath],
                  let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                return fallback[keyPath: keyPath]
            }
            return decoded
        }
        set {
            guard let key = UserDefaultsSettings.keyNames[keyPath],
                  let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }

    public func removeAll() {
        for key in UserDefaultsSettings.keyNames.values {
            defaults.removeObject(forKey: key)
        }
    }
}
