import Foundation
import Observation
import Core
import Localization

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
        didSet { settings.viewMode = viewMode }
    }

    /// 保存形式。変更時にUserDefaultsへ自動保存される
    public var saveFormat: SaveFormat {
        didSet { settings.saveFormat = saveFormat }
    }

    /// ソート順。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    public var sortOrder: FileSortOrder {
        didSet {
            settings.sortOrder = sortOrder
            updateSections()
        }
    }

    /// グリッド表示の列数の選択可能範囲
    public static let gridColumnCountRange = 2...5

    /// グリッド表示の列数。変更時にUserDefaultsへ自動保存される（復元時に範囲内へクランプ）
    public var gridColumnCount: Int {
        didSet { settings.gridColumnCount = gridColumnCount }
    }

    /// 復元したグリッド列数をgridColumnCountRange内へクランプする
    private static func clamped(_ value: Int) -> Int {
        min(max(value, gridColumnCountRange.lowerBound), gridColumnCountRange.upperBound)
    }

    /// レーティング機能のオンオフ。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    public var isRatingEnabled: Bool {
        didSet {
            settings.isRatingEnabled = isRatingEnabled
            updateSections()
        }
    }

    /// レーティングフィルター（nilはフィルターなし）。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    public var ratingFilter: RatingFilter? {
        didSet {
            settings.ratingFilter = ratingFilter
            updateSections()
        }
    }

    /// カラーラベルフィルター（選択中ラベルの集合。空はフィルターなし）。
    /// 変更時にUserDefaultsへ自動保存し、セクションを再構築する
    public var colorLabelFilter: Set<PhotoColorLabel> {
        didSet {
            settings.colorLabelFilter = colorLabelFilter
            updateSections()
        }
    }

    /// 最後に閲覧したファイル名（起動をまたいで復元するために永続化する）
    private var lastViewedFileName: String? {
        didSet { settings.lastViewedFileName = lastViewedFileName }
    }

    // MARK: - レーティング・カラーラベル

    /// URLごとのレーティングのキャッシュ（セルの星表示とフィルタ判定に使用）
    private var ratingsByURL: [URL: Int] = [:]

    /// URLごとのカラーラベルのキャッシュ（セルのドット表示とフィルタ判定に使用）
    private var labelsByURL: [URL: PhotoColorLabel] = [:]

    /// 指定URLのレーティング（星0〜5）を返す
    public func rating(for url: URL) -> Int {
        ratingsByURL[url] ?? 0
    }

    /// 指定URLのカラーラベルを返す（未設定はnil）
    public func colorLabel(for url: URL) -> PhotoColorLabel? {
        labelsByURL[url]
    }

    /// 永続化ストアからレーティングとカラーラベルを再読み込みし、フィルタ適用済みセクションを再構築する。
    /// フォトビューアーで変更された後に呼ぶ。
    public func refreshRatingsAndLabels() {
        ratingsByURL = ratingStore.allRatings()
        labelsByURL = colorLabelStore.allLabels()
        updateSections()
    }

    /// レーティングとカラーラベルの両フィルタに適合するかを返す
    private func matchesFilters(_ url: URL) -> Bool {
        if let filter = ratingFilter, !filter.matches(rating(for: url)) { return false }
        if !colorLabelFilter.isEmpty {
            guard let label = colorLabel(for: url), colorLabelFilter.contains(label) else { return false }
        }
        return true
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
        f.locale = L10n.currentLocale
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    /// Section.IDをローカライズされた日付文字列に変換する
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
            (id: section.id, title: L10n.FileBrowser.sectionTitleWithCount(sectionTitle(for: section.id), section.items.count))
        }
        return (showsLastViewed: showsLastViewed, sections: sectionData)
    }

    // MARK: - 依存関係

    private let fileSystemService: any FileSystemServiceProtocol
    private let settings: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>
    private let savedDateStore: any SavedDateStoreProtocol
    private let ratingStore: any PhotoRatingStoreProtocol
    private let colorLabelStore: any ColorLabelStoreProtocol

    // MARK: - 初期化

    public init(
        fileSystemService: any FileSystemServiceProtocol,
        savedDateStore: any SavedDateStoreProtocol,
        ratingStore: any PhotoRatingStoreProtocol,
        colorLabelStore: any ColorLabelStoreProtocol,
        settings: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>
    ) {
        self.fileSystemService = fileSystemService
        self.savedDateStore = savedDateStore
        self.ratingStore = ratingStore
        self.colorLabelStore = colorLabelStore
        self.settings = settings
        // UserDefaultsSettingsStoreから復元する（デフォルト値・クランプはそちらに一元化されている）
        self.viewMode = settings.viewMode
        self.saveFormat = settings.saveFormat
        self.sortOrder = settings.sortOrder
        self.gridColumnCount = Self.clamped(settings.gridColumnCount)
        self.isRatingEnabled = settings.isRatingEnabled
        self.ratingFilter = settings.ratingFilter
        self.colorLabelFilter = settings.colorLabelFilter
        self.lastViewedFileName = settings.lastViewedFileName
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

    /// 設定と閲覧履歴を初期状態に戻し、UserDefaultsの全キーと
    /// 永続化済みの保存日時・レーティング・カラーラベルを削除する
    public func resetToDefaults() {
        settings.removeAll()
        // 削除後のUserDefaultsSettingsStoreから読み直すことで、デフォルト値の重複管理を避ける
        viewMode = settings.viewMode
        saveFormat = settings.saveFormat
        sortOrder = settings.sortOrder
        gridColumnCount = Self.clamped(settings.gridColumnCount)
        isRatingEnabled = settings.isRatingEnabled
        ratingFilter = settings.ratingFilter
        colorLabelFilter = settings.colorLabelFilter
        lastViewedFileName = settings.lastViewedFileName
        lastViewedItemID = nil
        ratingsByURL = [:]
        labelsByURL = [:]
        savedDateStore.removeAll()
        ratingStore.removeAll()
        colorLabelStore.removeAll()
        updateSections()
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
        ratingsByURL = ratingStore.allRatings()
        labelsByURL = colorLabelStore.allLabels()
        updateSections()
        restoreLastViewedItemIDIfNeeded()
        isLoading = false
    }

    /// loadedItemsへレーティング・カラーラベルフィルタを適用後、日付キーでグループ化し、
    /// sortOrderに従ってセクションとアイテムを並べてsectionsを更新する
    private func updateSections() {
        let visibleItems: [FileItem]
        if isRatingEnabled, ratingFilter != nil || !colorLabelFilter.isEmpty {
            visibleItems = loadedItems.filter { matchesFilters($0.url) }
        } else {
            visibleItems = loadedItems
        }
        var sectionMap: [String: [FileItem]] = [:]
        for item in visibleItems {
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
