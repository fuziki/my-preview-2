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

// MARK: - PhotoViewerOrientationLock

/// フォトビューア画面のみに適用される画面回転設定。他の画面は常に端末の設定に従う
public enum PhotoViewerOrientationLock: String, Codable {
    case followSystem  // 端末の設定に追従（デフォルト）
    case portrait       // 縦画面固定
    case landscape       // 横画面固定

    /// ボタンタップ時に遷移する次の状態
    public var next: PhotoViewerOrientationLock {
        switch self {
        case .followSystem: .portrait
        case .portrait: .landscape
        case .landscape: .followSystem
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
    /// PiP自動送り間隔（秒）として設定できる範囲
    public static let pipAutoAdvanceIntervalSecondsRange = 1...30

    public var viewMode: ViewMode
    public var saveFormat: SaveFormat
    public var sortOrder: FileSortOrder
    public var gridColumnCount: Int
    public var isRatingEnabled: Bool
    public var ratingFilter: RatingFilter?
    public var colorLabelFilter: Set<PhotoColorLabel>
    public var savedFilter: SavedFilter?
    public var lastViewedEntries: [DirectoryLastViewedEntry]
    public var orientationLock: PhotoViewerOrientationLock
    /// PiP再生中に自動的に次の写真へ進める間隔（秒）
    public var pipAutoAdvanceIntervalSeconds: Int

    init(
        viewMode: ViewMode,
        saveFormat: SaveFormat,
        sortOrder: FileSortOrder,
        gridColumnCount: Int,
        isRatingEnabled: Bool,
        ratingFilter: RatingFilter?,
        colorLabelFilter: Set<PhotoColorLabel>,
        savedFilter: SavedFilter?,
        lastViewedEntries: [DirectoryLastViewedEntry],
        orientationLock: PhotoViewerOrientationLock,
        pipAutoAdvanceIntervalSeconds: Int
    ) {
        self.viewMode = viewMode
        self.saveFormat = saveFormat
        self.sortOrder = sortOrder
        self.gridColumnCount = gridColumnCount
        self.isRatingEnabled = isRatingEnabled
        self.ratingFilter = ratingFilter
        self.colorLabelFilter = colorLabelFilter
        self.savedFilter = savedFilter
        self.lastViewedEntries = lastViewedEntries
        self.orientationLock = orientationLock
        self.pipAutoAdvanceIntervalSeconds = pipAutoAdvanceIntervalSeconds
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
            savedFilter: nil,
            lastViewedEntries: [],
            orientationLock: .followSystem,
            pipAutoAdvanceIntervalSeconds: 5
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
            \.savedFilter: "UserDefaultsSettingsStore.savedFilter",
            \.lastViewedEntries: "UserDefaultsSettingsStore.lastViewedEntries",
            \.orientationLock: "UserDefaultsSettingsStore.orientationLock",
            \.pipAutoAdvanceIntervalSeconds: "UserDefaultsSettingsStore.pipAutoAdvanceIntervalSeconds",
        ]
    }
}
