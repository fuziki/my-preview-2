import Foundation
import Observation

@Observable
final class FileBrowserViewModel {
    private(set) var items: [FileItem] = []
    private(set) var hasFolder: Bool = false
    private(set) var isLoading: Bool = false
    private var rootURL: URL? = nil

    // MARK: - 永続化された状態（UserDefaultsと双方向同期）

    /// 表示モード。変更時にUserDefaultsへ自動保存される
    var viewMode: ViewMode {
        didSet { storage.set(viewMode.rawValue, forKey: .viewMode) }
    }

    /// 最後に閲覧したファイル名（起動をまたいで復元するために永続化する）
    private var lastViewedFileName: String? {
        didSet { storage.set(lastViewedFileName, forKey: .lastViewedFileName) }
    }

    // MARK: - 派生状態

    /// 最後に閲覧したアイテム（現在のitemsの中に該当するものがあれば返す）
    var lastViewedItem: FileItem? {
        guard let fileName = lastViewedFileName else { return nil }
        return items.first(where: { $0.name == fileName })
    }

    // MARK: - セクションデータ（日付でグループ化したアイテム）

    /// "yyyy-MM-dd" キーの順序付きリスト
    private(set) var sectionDateKeys: [String] = []

    /// 各日付セクションのアイテムID
    private(set) var sectionItems: [String: [FileItem.ID]] = [:]

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
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    /// "yyyy-MM-dd" キーをローカライズされた日本語日付文字列に変換する
    func sectionTitle(for dateKey: String) -> String {
        if let date = sectionKeyFormatter.date(from: dateKey) {
            return sectionDisplayFormatter.string(from: date)
        }
        return dateKey
    }

    // MARK: - メニューデータ

    /// セクションヘッダーのメニュー用データを返す
    /// - Returns: 「最後に表示」を表示するか、セクション一覧（キーとタイトルのペア）
    func makeMenuData() -> (showsLastViewed: Bool, sections: [(key: String, title: String)]) {
        let showsLastViewed: Bool
        if let id = lastViewedItemID {
            showsLastViewed = sectionItems.values.contains(where: { $0.contains(id) })
        } else {
            showsLastViewed = false
        }
        let sections = sectionDateKeys.map { key in
            let count = sectionItems[key]?.count ?? 0
            return (key: key, title: "\(sectionTitle(for: key)) (\(count)枚)")
        }
        return (showsLastViewed: showsLastViewed, sections: sections)
    }

    // MARK: - 依存関係

    private let fileSystemService: any FileSystemServiceProtocol
    private let storage: any UserDefaultsStorageProtocol

    // MARK: - 初期化

    init(
        fileSystemService: any FileSystemServiceProtocol,
        storage: any UserDefaultsStorageProtocol = UserDefaultsStorage.shared
    ) {
        self.fileSystemService = fileSystemService
        self.storage = storage
        // UserDefaultsから復元する
        self.viewMode = ViewMode(rawValue: storage.string(forKey: .viewMode) ?? "") ?? .list
        self.lastViewedFileName = storage.string(forKey: .lastViewedFileName)
    }

    // MARK: - アクション

    func selectFolder(_ url: URL) async {
        rootURL?.stopAccessingSecurityScopedResource()
        guard url.startAccessingSecurityScopedResource() else { return }
        rootURL = url
        hasFolder = true
        await loadItems()
    }

    /// 閲覧したURLをUserDefaultsに保存し、lastViewedItemIDも更新する
    func saveLastViewed(url: URL) {
        lastViewedFileName = url.lastPathComponent
        lastViewedItemID = items.first(where: { $0.url == url })?.id
    }

    // MARK: - プライベート

    private func loadItems() async {
        guard let url = rootURL else { return }
        isLoading = true
        items = await fileSystemService.scanForJPEGs(in: url)
        updateSections()
        restoreLastViewedItemIDIfNeeded()
        isLoading = false
    }

    /// アイテムを日付キーでグループ化してsectionDateKeys・sectionItemsを更新する
    private func updateSections() {
        var dateMap: [String: [FileItem.ID]] = [:]
        var dateOrder: [String] = []
        for item in items {
            let date = item.captureDate ?? Date.distantFuture
            let key = sectionKeyFormatter.string(from: date)
            if dateMap[key] == nil {
                dateOrder.append(key)
                dateMap[key] = []
            }
            dateMap[key]!.append(item.id)
        }
        sectionDateKeys = dateOrder
        sectionItems = dateMap
    }

    /// lastViewedItemIDが未設定の場合に限りlastViewedItemから復元する（初回ロード時に使用）
    private func restoreLastViewedItemIDIfNeeded() {
        guard lastViewedItemID == nil else { return }
        lastViewedItemID = lastViewedItem?.id
    }
}
