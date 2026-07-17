import Foundation
import Observation
import Core

@Observable
public final class FileBrowserViewModel {
    public private(set) var sections: [FileBrowserSection] = []
    public var items: [FileItem] { sections.flatMap(\.items) }
    private var loadedItems: [FileItem] = []
    public private(set) var hasFolder: Bool = false
    public private(set) var isLoading: Bool = false
    public private(set) var folderName: String? = nil
    private var rootURL: URL? = nil

    // MARK: - 永続化された状態（UserDefaultsと双方向同期）

    /// 表示モード。変更時にUserDefaultsへ自動保存される
    public var viewMode: ViewMode {
        didSet { storage.set(viewMode.rawValue, forKey: .viewMode) }
    }

    /// 保存形式。変更時にUserDefaultsへ自動保存される
    public var saveFormat: SaveFormat {
        didSet { storage.set(saveFormat.rawValue, forKey: .saveFormat) }
    }

    /// ソート順。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    public var sortOrder: FileSortOrder {
        didSet {
            storage.set(sortOrder.rawValue, forKey: .sortOrder)
            updateSections()
        }
    }

    /// グリッド表示の列数の選択可能範囲
    public static let gridColumnCountRange = 2...5

    /// グリッド表示の列数。変更時にUserDefaultsへ自動保存される（復元時に範囲内へクランプ）
    public var gridColumnCount: Int {
        didSet { storage.set(String(gridColumnCount), forKey: .gridColumnCount) }
    }

    /// 最後に閲覧したファイル名（起動をまたいで復元するために永続化する）
    private var lastViewedFileName: String? {
        didSet { storage.set(lastViewedFileName, forKey: .lastViewedFileName) }
    }

    // MARK: - 派生状態

    /// 最後に閲覧したアイテム（現在のitemsの中に該当するものがあれば返す）
    public var lastViewedItem: FileItem? {
        guard let fileName = lastViewedFileName else { return nil }
        return items.first(where: { $0.name == fileName })
    }

    // MARK: - 最後に閲覧したアイテムID

    /// 最後に閲覧していたアイテムのID（「最後に表示」バッジ・メニュー・スクロールに使用）
    public private(set) var lastViewedItemID: FileItem.ID?

    // MARK: - hasFolder変化検出

    /// hasFolderの前回チェック時の値（変化検出に使用）
    private var lastKnownHasFolder: Bool = false

    /// hasFolderが前回から変化したかを返し、内部状態を更新する
    public func consumeHasFolderChanged() -> Bool {
        let changed = hasFolder != lastKnownHasFolder
        lastKnownHasFolder = hasFolder
        return changed
    }

    // MARK: - 日付フォーマッタ

    private let sectionKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let sectionDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    /// Section.IDをローカライズされた日本語日付文字列に変換する
    public func sectionTitle(for id: FileBrowserSection.ID) -> String {
        if let date = sectionKeyFormatter.date(from: id.dateKey) {
            return sectionDisplayFormatter.string(from: date)
        }
        return id.dateKey
    }

    /// Section.IDからSectionの実態を引く
    public func section(for id: FileBrowserSection.ID) -> FileBrowserSection? {
        sections.first(where: { $0.id == id })
    }

    // MARK: - メニューデータ

    /// セクションヘッダーのメニュー用データを返す
    public func makeMenuData() -> (showsLastViewed: Bool, sections: [(id: FileBrowserSection.ID, title: String)]) {
        let showsLastViewed: Bool
        if let itemID = lastViewedItemID {
            showsLastViewed = sections.contains(where: { $0.items.contains(where: { $0.id == itemID }) })
        } else {
            showsLastViewed = false
        }
        let sectionData = sections.map { section in
            (id: section.id, title: "\(sectionTitle(for: section.id)) (\(section.items.count)枚)")
        }
        return (showsLastViewed: showsLastViewed, sections: sectionData)
    }

    // MARK: - 依存関係

    private let fileSystemService: any FileSystemServiceProtocol
    private let storage: any UserDefaultsStorageProtocol

    // MARK: - 初期化

    public init(
        fileSystemService: any FileSystemServiceProtocol,
        storage: any UserDefaultsStorageProtocol = UserDefaultsStorage.shared
    ) {
        self.fileSystemService = fileSystemService
        self.storage = storage
        // UserDefaultsから復元する
        self.viewMode = ViewMode(rawValue: storage.string(forKey: .viewMode) ?? "") ?? .list
        self.saveFormat = SaveFormat(rawValue: storage.string(forKey: .saveFormat) ?? "") ?? .jpegAndRaw
        self.sortOrder = FileSortOrder(rawValue: storage.string(forKey: .sortOrder) ?? "") ?? .dateAscending
        let storedColumnCount = Int(storage.string(forKey: .gridColumnCount) ?? "") ?? 3
        self.gridColumnCount = min(
            max(storedColumnCount, Self.gridColumnCountRange.lowerBound),
            Self.gridColumnCountRange.upperBound
        )
        self.lastViewedFileName = storage.string(forKey: .lastViewedFileName)
    }

    // MARK: - アクション

    public func selectFolder(_ url: URL) async {
        rootURL?.stopAccessingSecurityScopedResource()
        guard url.startAccessingSecurityScopedResource() else { return }
        rootURL = url
        folderName = url.lastPathComponent
        hasFolder = true
        await loadItems()
    }

    /// 閲覧したURLをUserDefaultsに保存し、lastViewedItemIDも更新する
    public func saveLastViewed(url: URL) {
        lastViewedFileName = url.lastPathComponent
        lastViewedItemID = items.first(where: { $0.url == url })?.id
    }

    // MARK: - プライベート

    private func loadItems() async {
        guard let url = rootURL else { return }
        isLoading = true
        loadedItems = await fileSystemService.scanForJPEGs(in: url)
        updateSections()
        restoreLastViewedItemIDIfNeeded()
        isLoading = false
    }

    /// loadedItemsを日付キーでグループ化し、sortOrderに従ってセクションとアイテムを並べてsectionsを更新する
    private func updateSections() {
        var sectionMap: [String: [FileItem]] = [:]
        for item in loadedItems {
            let date = item.captureDate ?? Date.distantFuture
            let key = sectionKeyFormatter.string(from: date)
            if sectionMap[key] == nil { sectionMap[key] = [] }
            sectionMap[key]!.append(item)
        }
        let ascending = sortOrder == .dateAscending
        // "yyyy-MM-dd"形式は辞書順＝日付順なので文字列比較でソートできる
        let sortedKeys = sectionMap.keys.sorted(by: ascending ? (<) : (>))
        sections = sortedKeys.map { key in
            let items = (sectionMap[key] ?? []).sorted {
                let a = $0.captureDate ?? Date.distantFuture
                let b = $1.captureDate ?? Date.distantFuture
                return ascending ? a < b : a > b
            }
            return FileBrowserSection(id: .init(dateKey: key), items: items)
        }
    }

    /// lastViewedItemIDが未設定の場合に限りlastViewedItemから復元する（初回ロード時に使用）
    private func restoreLastViewedItemIDIfNeeded() {
        guard lastViewedItemID == nil else { return }
        lastViewedItemID = lastViewedItem?.id
    }
}
