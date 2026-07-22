import Foundation

// MARK: - ViewMode

public enum ViewMode: String {
    case list, grid
}

// MARK: - FileSortOrder

public enum FileSortOrder: String {
    case dateDescending  // 新しい順
    case dateAscending   // 古い順（デフォルト）
}

// MARK: - SaveFormat

public enum SaveFormat: String {
    case jpeg
    case jpegAndRaw

    public var displayName: String {
        switch self {
        case .jpeg: "JPEG"
        case .jpegAndRaw: "JPEG + RAW"
        }
    }
}

// MARK: - UserDefaultsSettingsStoreProtocol

/// UserDefaultsに永続化するアプリ設定への型付きアクセスを提供する。
/// デフォルト値・フォールバック・値のクランプ処理をこのプロトコルの実装に一元化し、
/// 利用側（ViewModelやサービス）が個別にrawValue変換やデフォルト値を持たないようにする。
public protocol UserDefaultsSettingsStoreProtocol: AnyObject {
    var viewMode: ViewMode { get set }
    var saveFormat: SaveFormat { get set }
    var sortOrder: FileSortOrder { get set }
    var gridColumnCount: Int { get set }
    var isRatingEnabled: Bool { get set }
    var ratingFilter: RatingFilter? { get set }
    var colorLabelFilter: Set<PhotoColorLabel> { get set }
    var lastViewedFileName: String? { get set }

    /// 全設定をUserDefaultsから削除する。以後のアクセスはデフォルト値を返す
    func removeAll()
}

// MARK: - UserDefaultsSettingsStore

public final class UserDefaultsSettingsStore: UserDefaultsSettingsStoreProtocol {
    /// グリッド表示の列数の選択可能範囲
    public static let gridColumnCountRange = 2...5

    private let storage: any UserDefaultsStorageProtocol

    public init(storage: any UserDefaultsStorageProtocol) {
        self.storage = storage
    }

    public var viewMode: ViewMode {
        get { ViewMode(rawValue: storage.string(forKey: .viewMode) ?? "") ?? .grid }
        set { storage.set(newValue.rawValue, forKey: .viewMode) }
    }

    public var saveFormat: SaveFormat {
        get { SaveFormat(rawValue: storage.string(forKey: .saveFormat) ?? "") ?? .jpeg }
        set { storage.set(newValue.rawValue, forKey: .saveFormat) }
    }

    public var sortOrder: FileSortOrder {
        get { FileSortOrder(rawValue: storage.string(forKey: .sortOrder) ?? "") ?? .dateAscending }
        set { storage.set(newValue.rawValue, forKey: .sortOrder) }
    }

    public var gridColumnCount: Int {
        get {
            let stored = Int(storage.string(forKey: .gridColumnCount) ?? "") ?? 3
            return min(max(stored, Self.gridColumnCountRange.lowerBound), Self.gridColumnCountRange.upperBound)
        }
        set { storage.set(String(newValue), forKey: .gridColumnCount) }
    }

    public var isRatingEnabled: Bool {
        get { (storage.string(forKey: .isRatingEnabled) ?? "true") == "true" }
        set { storage.set(newValue ? "true" : "false", forKey: .isRatingEnabled) }
    }

    public var ratingFilter: RatingFilter? {
        get { RatingFilter(rawValue: storage.string(forKey: .ratingFilter) ?? "") }
        set { storage.set(newValue?.rawValue, forKey: .ratingFilter) }
    }

    public var colorLabelFilter: Set<PhotoColorLabel> {
        get { Set(colorLabelFilterRawValue: storage.string(forKey: .colorLabelFilter) ?? "") }
        set { storage.set(newValue.isEmpty ? nil : newValue.colorLabelFilterRawValue, forKey: .colorLabelFilter) }
    }

    public var lastViewedFileName: String? {
        get { storage.string(forKey: .lastViewedFileName) }
        set { storage.set(newValue, forKey: .lastViewedFileName) }
    }

    public func removeAll() {
        storage.removeAll()
    }
}
