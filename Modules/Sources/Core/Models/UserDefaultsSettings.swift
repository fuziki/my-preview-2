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

// MARK: - DirectoryLastViewedEntry

/// ディレクトリパスと、そのディレクトリで最後に閲覧したファイル名の組
public struct DirectoryLastViewedEntry: Codable, Equatable {
    public let directoryPath: String
    public let fileName: String

    public init(directoryPath: String, fileName: String) {
        self.directoryPath = directoryPath
        self.fileName = fileName
    }
}

extension [DirectoryLastViewedEntry] {
    /// directoryPathの最終閲覧ファイル名を更新（末尾へ移動）し、
    /// limit件を超えた分は先頭＝最も古いディレクトリから削除する
    public func updatingLastViewed(directoryPath: String, fileName: String, limit: Int) -> [DirectoryLastViewedEntry] {
        var entries = self
        entries.removeAll { $0.directoryPath == directoryPath }
        entries.append(DirectoryLastViewedEntry(directoryPath: directoryPath, fileName: fileName))
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
        return entries
    }
}

// MARK: - UserDefaultsSettings

/// UserDefaultsへ永続化する設定値をまとめて保持する。
/// UserDefaultsSettingsStoreがこの型のプロパティ単位でCodableエンコードして保存する。
public struct UserDefaultsSettings: Codable, UserDefaultsStorableSettings {
    /// 最後に表示した写真をディレクトリパスごとに保持できる上限件数
    public static let maxLastViewedDirectoryCount = 10

    public var viewMode: ViewMode
    public var saveFormat: SaveFormat
    public var sortOrder: FileSortOrder
    public var gridColumnCount: Int
    public var isRatingEnabled: Bool
    public var ratingFilter: RatingFilter?
    public var colorLabelFilter: Set<PhotoColorLabel>
    public var lastViewedEntries: [DirectoryLastViewedEntry]

    init(
        viewMode: ViewMode,
        saveFormat: SaveFormat,
        sortOrder: FileSortOrder,
        gridColumnCount: Int,
        isRatingEnabled: Bool,
        ratingFilter: RatingFilter?,
        colorLabelFilter: Set<PhotoColorLabel>,
        lastViewedEntries: [DirectoryLastViewedEntry]
    ) {
        self.viewMode = viewMode
        self.saveFormat = saveFormat
        self.sortOrder = sortOrder
        self.gridColumnCount = gridColumnCount
        self.isRatingEnabled = isRatingEnabled
        self.ratingFilter = ratingFilter
        self.colorLabelFilter = colorLabelFilter
        self.lastViewedEntries = lastViewedEntries
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
            lastViewedEntries: []
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
            \.lastViewedEntries: "UserDefaultsSettingsStore.lastViewedEntries",
        ]
    }
}
