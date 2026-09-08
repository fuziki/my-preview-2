import Foundation
import Observation
import Core

// MARK: - FileBrowserBulkSaveViewModel

/// 「全て保存」の進捗オーバーレイ専用ViewModel。FileBrowserViewModelとは独立した状態を持つ。
/// 1枚保存が完了するたびに保存先URLと保存日時を添えてonURLSavedを呼び、呼び出し元
/// （FileBrowserViewController）がFileBrowserViewModelへ反映することで、
/// 裏のファイルリスト（保存状態フィルタ含む）へリアルタイムに反映される。
/// 完了・中断・失敗のいずれかで処理が終わるとonFinishedを呼び、呼び出し元
/// （FileBrowserBulkSaveViewController）が画面を閉じる。
/// FileBrowserBulkSaveViewController内でのみ生成されるため、モジュール外には公開しない。
@Observable
final class FileBrowserBulkSaveViewModel {
    let totalCount: Int
    private(set) var completedCount: Int = 0

    /// 保存が完了・中断・失敗したときに呼ばれる。VC側でinit後に設定する
    var onFinished: (() -> Void)?

    private let urls: [URL]
    private let photoLibrary: any PhotoLibraryServiceProtocol
    private let savedDateStore: any SavedDateStoreProtocol
    private let hapticsService: any HapticsServiceProtocol
    private let onURLSaved: (URL, Date) -> Void
    private var isCancelled = false

    init(
        urls: [URL],
        dependencies: FileBrowserBulkSaveDependencies,
        onURLSaved: @escaping (URL, Date) -> Void
    ) {
        self.urls = urls
        self.totalCount = urls.count
        self.photoLibrary = dependencies.photoLibrary
        self.savedDateStore = dependencies.savedDateStore
        self.hapticsService = dependencies.hapticsService
        self.onURLSaved = onURLSaved
    }

    /// 対象URLを順に保存する。中断されるか、いずれかの保存に失敗した場合はそこで打ち切る。
    /// 触覚フィードバックはループ全体の終了時に1回だけ発行する（中断は無音）。
    func start() async {
        for url in urls {
            guard !isCancelled else {
                onFinished?()
                return
            }
            do {
                try await photoLibrary.save(fileURL: url)
            } catch {
                hapticsService.notifyError()
                onFinished?()
                return
            }
            // 単体保存と同様、最終保存時刻を上書きする
            let savedDate = Date()
            savedDateStore.setDate(savedDate, for: url)
            completedCount += 1
            onURLSaved(url, savedDate)
        }
        hapticsService.notifySuccess()
        onFinished?()
    }

    /// 中断ボタンから呼ばれる。次の写真の保存を開始する前にループを止める
    func cancel() {
        isCancelled = true
    }
}
