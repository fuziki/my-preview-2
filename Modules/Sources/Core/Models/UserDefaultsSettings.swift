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
public struct UserDefaultsSettings: Codable, UserDefaultsStorableSettings {
    public var viewMode: ViewMode
    public var saveFormat: SaveFormat
    public var sortOrder: FileSortOrder
    public var gridColumnCount: Int
    public var isRatingEnabled: Bool
    public var ratingFilter: RatingFilter?
    public var colorLabelFilter: Set<PhotoColorLabel>
    public var lastViewedFileName: String?

    init(
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

    /// KeyPathと保存キーの対応表。プロパティ名を変えてもここを更新しない限り
    /// 保存キーは変わらない（=既存ユーザーの設定を壊さない）
    public static var storageKeys: [PartialKeyPath<UserDefaultsSettings>: String] {
        [
            \.viewMode: "UserDefaultsSettingsStore.viewMode",
            \.saveFormat: "UserDefaultsSettingsStore.saveFormat",
            \.sortOrder: "UserDefaultsSettingsStore.sortOrder",
            \.gridColumnCount: "UserDefaultsSettingsStore.gridColumnCount",
            \.isRatingEnabled: "UserDefaultsSettingsStore.isRatingEnabled",
            \.ratingFilter: "UserDefaultsSettingsStore.ratingFilter",
            \.colorLabelFilter: "UserDefaultsSettingsStore.colorLabelFilter",
            \.lastViewedFileName: "UserDefaultsSettingsStore.lastViewedFileName",
        ]
    }
}
