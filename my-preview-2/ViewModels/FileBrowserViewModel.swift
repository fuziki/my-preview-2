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

    /// 閲覧したURLをUserDefaultsに保存する
    func saveLastViewed(url: URL) {
        lastViewedFileName = url.lastPathComponent
    }

    // MARK: - プライベート

    private func loadItems() async {
        guard let url = rootURL else { return }
        isLoading = true
        items = await fileSystemService.scanForJPEGs(in: url)
        isLoading = false
    }
}
