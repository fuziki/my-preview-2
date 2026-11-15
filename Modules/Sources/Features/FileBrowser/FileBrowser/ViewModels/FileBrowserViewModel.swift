import Foundation
import Observation
import Core
import Localization

@Observable
final class FileBrowserViewModel {
    private(set) var sections: [FileBrowserSection] = []
    var items: [FileItem] { sections.flatMap(\.items) }
    private var loadedItems: [FileItem] = []
    private(set) var hasFolder: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var folderName: String? = nil
    private var rootURL: URL? = nil

    // MARK: - 永続化された状態（UserDefaultsと双方向同期）

    /// 表示モード。変更時にUserDefaultsへ自動保存される
    var viewMode: ViewMode {
        didSet { settings.viewMode = viewMode }
    }

    /// 保存形式。変更時にUserDefaultsへ自動保存される
    var saveFormat: SaveFormat {
        didSet { settings.saveFormat = saveFormat }
    }

    /// ソート順。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    var sortOrder: FileSortOrder {
        didSet {
            settings.sortOrder = sortOrder
            updateSections()
        }
    }

    /// グリッド表示の列数の選択可能範囲
    static let gridColumnCountRange = 2...5

    /// グリッド表示の列数。変更時にUserDefaultsへ自動保存される（復元時に範囲内へクランプ）
    var gridColumnCount: Int {
        didSet { settings.gridColumnCount = gridColumnCount }
    }

    /// 復元したグリッド列数をgridColumnCountRange内へクランプする
    private static func clamped(_ value: Int) -> Int {
        min(max(value, gridColumnCountRange.lowerBound), gridColumnCountRange.upperBound)
    }

    /// レーティング機能のオンオフ。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    var isRatingEnabled: Bool {
        didSet {
            settings.isRatingEnabled = isRatingEnabled
            updateSections()
        }
    }

    /// レーティングフィルター（nilはフィルターなし）。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    var ratingFilter: RatingFilter? {
        didSet {
            settings.ratingFilter = ratingFilter
            updateSections()
        }
    }

    /// カラーラベルフィルター（選択中ラベルの集合。空はフィルターなし）。
    /// 変更時にUserDefaultsへ自動保存し、セクションを再構築する
    var colorLabelFilter: Set<PhotoColorLabel> {
        didSet {
            settings.colorLabelFilter = colorLabelFilter
            updateSections()
        }
    }

    /// 保存状態フィルター（nilはフィルターなし）。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    var savedFilter: SavedFilter? {
        didSet {
            settings.savedFilter = savedFilter
            updateSections()
        }
    }

    /// 撮影日時フィルター（nilはフィルターなし）。変更時にUserDefaultsへ自動保存し、セクションを再構築する
    var captureDateFilter: CaptureDateFilter? {
        didSet {
            settings.captureDateFilter = captureDateFilter
            updateSections()
        }
    }

    /// PiP自動送りの間隔（秒）の選択可能範囲
    static let pipAutoAdvanceIntervalSecondsRange = UserDefaultsSettings.pipAutoAdvanceIntervalSecondsRange
    /// 前後ボタン長押し中の連続ナビゲーション間隔（ミリ秒）の選択可能範囲
    static let buttonAutoAdvanceIntervalMillisecondsRange = UserDefaultsSettings.buttonAutoAdvanceIntervalMillisecondsRange

    /// PiP再生中に自動的に次の写真へ進める間隔（秒）。変更時にUserDefaultsへ自動保存される
    var pipAutoAdvanceIntervalSeconds: Int {
        didSet { settings.pipAutoAdvanceIntervalSeconds = pipAutoAdvanceIntervalSeconds }
    }

    /// 前後ボタン長押し中に自動的に次/前の写真へ進める間隔（ミリ秒）。変更時にUserDefaultsへ自動保存される
    var buttonAutoAdvanceIntervalMilliseconds: Int {
        didSet { settings.buttonAutoAdvanceIntervalMilliseconds = buttonAutoAdvanceIntervalMilliseconds }
    }

    /// 現在のディレクトリで最後に閲覧したファイル名（ディレクトリパスごとに永続化されたものから引く）
    private var lastViewedFileName: String? {
        guard let directoryPath = rootURL?.path else { return nil }
        return settings.lastViewedEntries.first(where: { $0.directoryPath == directoryPath })?.fileName
    }

    // MARK: - レーティング・カラーラベル

    /// URLごとのレーティングのキャッシュ（セルの星表示とフィルタ判定に使用）
    private var ratingsByURL: [URL: Int] = [:]

    /// URLごとのカラーラベルのキャッシュ（セルのドット表示とフィルタ判定に使用）
    private var labelsByURL: [URL: PhotoColorLabel] = [:]

    /// URLごとの保存日時のキャッシュ（フィルタ判定に使用）
    private var savedDatesByURL: [URL: Date] = [:]

    /// 指定URLのレーティング（星0〜5）を返す
    func rating(for url: URL) -> Int {
        ratingsByURL[url] ?? 0
    }

    /// 指定URLのカラーラベルを返す（未設定はnil）
    func colorLabel(for url: URL) -> PhotoColorLabel? {
        labelsByURL[url]
    }

    /// 永続化ストアからレーティング・カラーラベル・保存日時を再読み込みし、フィルタ適用済みセクションを再構築する。
    /// フォトビューアーで変更された後に呼ぶ。
    func refreshRatingsAndLabels() {
        ratingsByURL = ratingStore.allRatings()
        labelsByURL = colorLabelStore.allLabels()
        savedDatesByURL = savedDateStore.allDates()
        updateSections()
    }

    /// 指定URLの保存日時キャッシュのみを更新し、フィルタ適用済みセクションを再構築する。
    /// 全て保存フローで1枚保存するたびに呼ばれる。保存日時以外（レーティング・カラーラベル）は
    /// 変化しないため、refreshRatingsAndLabels() のような全ストア再読み込みは行わない。
    func markSaved(url: URL, date: Date) {
        savedDatesByURL[url] = date
        updateSections()
    }

    /// レーティング・カラーラベル・保存状態の全フィルタに適合するかを返す
    private func matchesFilters(_ item: FileItem) -> Bool {
        let url = item.url
        if let filter = ratingFilter, !filter.matches(rating(for: url)) { return false }
        if !colorLabelFilter.isEmpty {
            guard let label = colorLabel(for: url), colorLabelFilter.contains(label) else { return false }
        }
        if let savedFilter, !savedFilter.matches(savedDate: savedDatesByURL[url]) { return false }
        if let captureDateFilter, !captureDateFilter.matches(captureDate: item.captureDate) { return false }
        return true
    }

    // MARK: - 派生状態

    /// 最後に閲覧したアイテム（現在のitemsの中に該当するものがあれば返す）
    var lastViewedItem: FileItem? {
        guard let fileName = lastViewedFileName else { return nil }
        return items.first(where: { $0.name == fileName })
    }

    /// レーティング・カラーラベル・保存状態・撮影日時フィルタが有効かどうか（updateSectionsの適用条件と同一）
    var isFilterActive: Bool {
        isRatingEnabled && (ratingFilter != nil || !colorLabelFilter.isEmpty || savedFilter != nil || isCaptureDateFilterActive)
    }

    /// 撮影日時フィルタに開始・終了のいずれかが設定されているか
    var isCaptureDateFilterActive: Bool {
        captureDateFilter.map { !$0.isEmpty } ?? false
    }

    // MARK: - 最後に閲覧したアイテムID

    /// 最後に閲覧していたアイテムのID（「最後に表示」バッジ・メニュー・スクロールに使用）
    private(set) var lastViewedItemID: FileItem.ID?

    // MARK: - hasFolder変化検出

    /// hasFolderの前回チェック時の値（変化検出に使用）
    private var lastKnownHasFolder: Bool = false

    /// hasFolderが前回から変化したかを返し、内部状態を更新する
    func consumeHasFolderChanged() -> Bool {
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
    func sectionTitle(for id: FileBrowserSection.ID) -> String {
        if let date = sectionKeyFormatter.date(from: id.dateKey) {
            return sectionDisplayFormatter.string(from: date)
        }
        return id.dateKey
    }

    /// Section.IDからSectionの実態を引く
    func section(for id: FileBrowserSection.ID) -> FileBrowserSection? {
        sections.first(where: { $0.id == id })
    }

    // MARK: - メニューデータ

    /// セクションヘッダーのメニュー用データを返す
    func makeMenuData() -> (showsLastViewed: Bool, sections: [(id: FileBrowserSection.ID, title: String)]) {
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
    /// フィルター済み写真リストの唯一の真実（SSOT）。PhotoViewerと共有する
    private let photoCollectionStore: any PhotoCollectionStoreProtocol

    // MARK: - 初期化

    init(dependencies: FileBrowserDependencies) {
        self.fileSystemService = dependencies.fileSystemService
        self.savedDateStore = dependencies.savedDateStore
        self.ratingStore = dependencies.ratingStore
        self.colorLabelStore = dependencies.colorLabelStore
        self.settings = dependencies.settings
        self.photoCollectionStore = dependencies.photoCollectionStore
        // UserDefaultsSettingsStoreから復元する（デフォルト値・クランプはそちらに一元化されている）
        self.viewMode = settings.viewMode
        self.saveFormat = settings.saveFormat
        self.sortOrder = settings.sortOrder
        self.gridColumnCount = Self.clamped(settings.gridColumnCount)
        self.isRatingEnabled = settings.isRatingEnabled
        self.ratingFilter = settings.ratingFilter
        self.colorLabelFilter = settings.colorLabelFilter
        self.savedFilter = settings.savedFilter
        self.captureDateFilter = settings.captureDateFilter
        self.pipAutoAdvanceIntervalSeconds = settings.pipAutoAdvanceIntervalSeconds
        self.buttonAutoAdvanceIntervalMilliseconds = settings.buttonAutoAdvanceIntervalMilliseconds
    }

    // MARK: - アクション

    func selectFolder(_ url: URL) async {
        rootURL?.stopAccessingSecurityScopedResource()
        guard url.startAccessingSecurityScopedResource() else { return }
        rootURL = url
        folderName = url.lastPathComponent
        hasFolder = true
        await loadItems()
    }

    /// 設定と閲覧履歴を初期状態に戻し、UserDefaultsの全キーと
    /// 永続化済みの保存日時・レーティング・カラーラベルを削除する
    func resetToDefaults() {
        settings.removeAll()
        // 削除後のUserDefaultsSettingsStoreから読み直すことで、デフォルト値の重複管理を避ける
        viewMode = settings.viewMode
        saveFormat = settings.saveFormat
        sortOrder = settings.sortOrder
        gridColumnCount = Self.clamped(settings.gridColumnCount)
        isRatingEnabled = settings.isRatingEnabled
        ratingFilter = settings.ratingFilter
        colorLabelFilter = settings.colorLabelFilter
        savedFilter = settings.savedFilter
        captureDateFilter = settings.captureDateFilter
        pipAutoAdvanceIntervalSeconds = settings.pipAutoAdvanceIntervalSeconds
        buttonAutoAdvanceIntervalMilliseconds = settings.buttonAutoAdvanceIntervalMilliseconds
        lastViewedItemID = nil
        ratingsByURL = [:]
        labelsByURL = [:]
        savedDatesByURL = [:]
        savedDateStore.removeAll()
        ratingStore.removeAll()
        colorLabelStore.removeAll()
        updateSections()
    }

    /// 閲覧したURLをディレクトリパスごとにUserDefaultsに保存し、lastViewedItemIDも更新する
    func saveLastViewed(url: URL) {
        guard let directoryPath = rootURL?.path else { return }
        settings.lastViewedEntries = settings.lastViewedEntries.updatingLastViewed(
            directoryPath: directoryPath,
            fileName: url.lastPathComponent,
            limit: UserDefaultsSettings.maxLastViewedDirectoryCount
        )
        lastViewedItemID = items.first(where: { $0.url == url })?.id
    }

    // MARK: - プライベート

    private func loadItems() async {
        guard let url = rootURL else { return }
        isLoading = true
        loadedItems = await fileSystemService.scanForJPEGs(in: url)
        ratingsByURL = ratingStore.allRatings()
        labelsByURL = colorLabelStore.allLabels()
        savedDatesByURL = savedDateStore.allDates()
        updateSections()
        restoreLastViewedItemIDIfNeeded()
        isLoading = false
    }

    /// loadedItemsへレーティング・カラーラベルフィルタを適用し、sortOrderに従って並べたURL列を
    /// photoCollectionStore（SSOT）へ公開したうえで、store.urlsの順序から日付キーでグループ化してsectionsを構築する。
    private func updateSections() {
        let visibleItems: [FileItem]
        if isFilterActive {
            visibleItems = loadedItems.filter { matchesFilters($0) }
        } else {
            visibleItems = loadedItems
        }
        let ascending = sortOrder == .dateAscending
        let sortedItems = visibleItems.sorted {
            let a = $0.captureDate ?? Date.distantFuture
            let b = $1.captureDate ?? Date.distantFuture
            return ascending ? a < b : a > b
        }
        photoCollectionStore.setURLs(sortedItems.map(\.url))

        // store.urls（SSOT）の順にFileItemを引き直し、日付キーでグルーピングしてsectionsを構築する
        let itemsByURL = Dictionary(uniqueKeysWithValues: loadedItems.map { ($0.url, $0) })
        let orderedItems = photoCollectionStore.urls.compactMap { itemsByURL[$0] }
        var sectionMap: [String: [FileItem]] = [:]
        var sectionOrder: [String] = []
        for item in orderedItems {
            let date = item.captureDate ?? Date.distantFuture
            let key = sectionKeyFormatter.string(from: date)
            if sectionMap[key] == nil {
                sectionMap[key] = []
                sectionOrder.append(key)
            }
            sectionMap[key]!.append(item)
        }
        sections = sectionOrder.map { key in
            FileBrowserSection(id: .init(dateKey: key), items: sectionMap[key] ?? [])
        }
    }

    /// lastViewedItemIDが未設定の場合に限りlastViewedItemから復元する（初回ロード時に使用）
    private func restoreLastViewedItemIDIfNeeded() {
        guard lastViewedItemID == nil else { return }
        lastViewedItemID = lastViewedItem?.id
    }
}
