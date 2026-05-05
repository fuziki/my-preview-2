import UIKit
import Observation

@Observable
final class PhotoViewerViewModel {

    // MARK: - 出力（Observationを通じてViewControllerが読み取る）

    private(set) var currentIndex: Int
    private(set) var allURLs: [URL]
    private(set) var currentImage: UIImage? = nil
    private(set) var previousOrientation: ImageOrientation? = nil
    private(set) var isLoading: Bool = false
    private(set) var exifInfo: ExifInfo? = nil
    private(set) var saveStatus: SaveStatus = .idle
    private(set) var lastSavedDate: Date? = nil
    var isOverlayVisible: Bool = true

    // MARK: - 派生状態

    var currentURL: URL { allURLs[currentIndex] }
    var currentFileName: String { currentURL.lastPathComponent }
    var canGoPrevious: Bool { currentIndex > 0 }
    var canGoNext: Bool { currentIndex < allURLs.count - 1 }

    // MARK: - 依存関係

    private let imageLoader: any ImageLoaderServiceProtocol
    private let exifService: any ExifServiceProtocol
    private let photoLibrary: any PhotoLibraryServiceProtocol
    private let savedDateStore: any SavedDateStoreProtocol

    // MARK: - 初期化

    init(input: PhotoViewerInput, services: PhotoViewerServices) {
        allURLs = input.allURLs
        currentIndex = input.allURLs.firstIndex(of: input.initialURL) ?? 0
        imageLoader = services.imageLoader
        exifService = services.exifService
        photoLibrary = services.photoLibrary
        savedDateStore = services.savedDateStore
        lastSavedDate = services.savedDateStore.date(for: input.allURLs[currentIndex])
    }

    // MARK: - ライフサイクル

    /// 初期インデックスの画像とEXIFを読み込む。VCの準備完了後に一度だけ呼ぶ。
    func loadInitial() async {
        await loadImageAndExif(for: currentURL)
    }

    // MARK: - ナビゲーション

    func navigatePrevious() async {
        guard canGoPrevious else { return }
        previousOrientation = currentImage?.photoOrientation
        currentIndex -= 1
        saveStatus = .idle
        lastSavedDate = savedDateStore.date(for: currentURL)
        await loadImageAndExif(for: currentURL)
    }

    func navigateNext() async {
        guard canGoNext else { return }
        previousOrientation = currentImage?.photoOrientation
        currentIndex += 1
        saveStatus = .idle
        lastSavedDate = savedDateStore.date(for: currentURL)
        await loadImageAndExif(for: currentURL)
    }

    /// UIPageViewControllerのスワイプ完了後に呼ばれる。
    /// 画像はページアイテムVCで既に表示済みのため、EXIFのみ読み込む。
    func didSwipeTo(index: Int, image: UIImage?) async {
        previousOrientation = nil  // スワイプは常に新しいページアイテムVCを表示するのでズームはリセットされる
        currentIndex = index
        saveStatus = .idle
        currentImage = image
        lastSavedDate = savedDateStore.date(for: currentURL)
        await loadExif(for: currentURL)
    }

    // MARK: - 保存

    func save() async {
        guard currentImage != nil else { return }
        let url = currentURL
        saveStatus = .saving
        do {
            try await photoLibrary.save(fileURL: url)
            let date = Date()
            savedDateStore.setDate(date, for: url)
            lastSavedDate = date
            saveStatus = .success
            try? await Task.sleep(for: .seconds(2))
            // ナビゲーション時は即座に .idle にリセットされるため、まだ .success の場合のみリセット
            if saveStatus == .success {
                saveStatus = .idle
            }
        } catch {
            saveStatus = .failure
        }
    }

    // MARK: - オーバーレイ

    func toggleOverlay() {
        isOverlayVisible.toggle()
    }

    // MARK: - プライベート読み込み

    /// 画像とEXIFを並行して読み込む（ボタンナビゲーションと初回読み込みで使用）。
    private func loadImageAndExif(for url: URL) async {
        isLoading = true
        async let image = imageLoader.loadImage(from: url)
        async let exif = exifService.extractExif(from: url)
        currentImage = await image
        exifInfo = await exif
        isLoading = false
    }

    /// EXIFのみ読み込む（スワイプナビゲーション後に使用。画像は既に表示済み）。
    private func loadExif(for url: URL) async {
        isLoading = true
        exifInfo = await exifService.extractExif(from: url)
        isLoading = false
    }
}
