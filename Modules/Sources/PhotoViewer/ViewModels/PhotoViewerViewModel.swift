import UIKit
import Observation
import Core

@Observable
public final class PhotoViewerViewModel {

    // MARK: - 出力（Observationを通じてViewControllerが読み取る）

    public private(set) var currentIndex: Int
    public private(set) var allURLs: [URL]
    public private(set) var currentImage: UIImage? = nil
    public private(set) var previousOrientation: ImageOrientation? = nil
    public private(set) var isLoading: Bool = false
    public private(set) var exifInfo: ExifInfo? = nil
    public private(set) var saveStatus: SaveStatus = .idle
    public private(set) var lastSavedDate: Date? = nil
    public var isOverlayVisible: Bool = true

    // MARK: - 派生状態

    public var currentURL: URL { allURLs[currentIndex] }
    public var currentFileName: String { currentURL.lastPathComponent }
    public var canGoPrevious: Bool { currentIndex > 0 }
    public var canGoNext: Bool { currentIndex < allURLs.count - 1 }

    // MARK: - 依存関係

    private let imageLoader: any ImageLoaderServiceProtocol
    private let exifService: any ExifServiceProtocol
    private let photoLibrary: any PhotoLibraryServiceProtocol
    private let savedDateStore: any SavedDateStoreProtocol
    private let hapticsService: any HapticsServiceProtocol

    // MARK: - 初期化

    public init(input: PhotoViewerInput, services: PhotoViewerServices) {
        allURLs = input.allURLs
        currentIndex = input.allURLs.firstIndex(of: input.initialURL) ?? 0
        imageLoader = services.imageLoader
        exifService = services.exifService
        photoLibrary = services.photoLibrary
        savedDateStore = services.savedDateStore
        hapticsService = services.hapticsService
        lastSavedDate = services.savedDateStore.date(for: input.allURLs[currentIndex])
    }

    // MARK: - ライフサイクル

    /// 初期インデックスの画像とEXIFを読み込む。VCの準備完了後に一度だけ呼ぶ。
    public func loadInitial() async {
        await loadImageAndExif(for: currentURL)
    }

    // MARK: - ナビゲーション

    public func navigatePrevious() async {
        guard canGoPrevious else { return }
        previousOrientation = currentImage?.photoOrientation
        currentIndex -= 1
        saveStatus = .idle
        lastSavedDate = savedDateStore.date(for: currentURL)
        await loadImageAndExif(for: currentURL)
    }

    public func navigateNext() async {
        guard canGoNext else { return }
        previousOrientation = currentImage?.photoOrientation
        currentIndex += 1
        saveStatus = .idle
        lastSavedDate = savedDateStore.date(for: currentURL)
        await loadImageAndExif(for: currentURL)
    }

    /// UIPageViewControllerのスワイプ完了後に呼ばれる。
    /// 画像はページアイテムVCで既に表示済みのため、EXIFのみ読み込む。
    public func didSwipeTo(index: Int, image: UIImage?) async {
        previousOrientation = nil  // スワイプは常に新しいページアイテムVCを表示するのでズームはリセットされる
        currentIndex = index
        saveStatus = .idle
        currentImage = image
        lastSavedDate = savedDateStore.date(for: currentURL)
        await loadExif(for: currentURL)
    }

    // MARK: - 保存

    public func save() async {
        guard currentImage != nil else { return }
        let url = currentURL
        saveStatus = .saving
        do {
            try await photoLibrary.save(fileURL: url)
            let date = Date()
            savedDateStore.setDate(date, for: url)
            lastSavedDate = date
            saveStatus = .success
            hapticsService.notifySuccess()
            try? await Task.sleep(for: .seconds(2))
            // ナビゲーション時は即座に .idle にリセットされるため、まだ .success の場合のみリセット
            if saveStatus == .success {
                saveStatus = .idle
            }
        } catch {
            saveStatus = .failure
            hapticsService.notifyError()
        }
    }

    // MARK: - オーバーレイ

    public func toggleOverlay() {
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
