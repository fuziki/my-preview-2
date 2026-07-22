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

    /// UserDefaultsへの保存キーの列挙に使う（削除時など、全プロパティを走査したい場合のみ使用）
    static let allKeyPaths: [PartialKeyPath<UserDefaultsSettings>] = [
        \.viewMode,
        \.saveFormat,
        \.sortOrder,
        \.gridColumnCount,
        \.isRatingEnabled,
        \.ratingFilter,
        \.colorLabelFilter,
        \.lastViewedFileName,
    ]
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
    private let defaults: UserDefaults
    private let fallback = UserDefaultsSettings.default()

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public subscript<T: Codable>(dynamicMember keyPath: KeyPath<UserDefaultsSettings, T>) -> T {
        get {
            guard let data = defaults.data(forKey: Self.key(for: keyPath)),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                return fallback[keyPath: keyPath]
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Self.key(for: keyPath))
        }
    }

    public func removeAll() {
        for keyPath in UserDefaultsSettings.allKeyPaths {
            defaults.removeObject(forKey: Self.key(for: keyPath))
        }
    }

    /// KeyPathのdebug descriptionにプレフィックスを付けてUserDefaultsのキー名とする
    private static func key(for keyPath: PartialKeyPath<UserDefaultsSettings>) -> String {
        "UserDefaultsSettingsStore.\(String(describing: keyPath))"
    }
}
