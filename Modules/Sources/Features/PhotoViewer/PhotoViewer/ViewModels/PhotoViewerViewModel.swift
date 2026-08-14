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
    public private(set) var currentRating: Int = 0
    public private(set) var currentColorLabel: PhotoColorLabel? = nil
    /// フィルタに適合する写真が1枚も無くなった場合にtrueになる（VCはこれを見てdismissする）
    public private(set) var shouldDismiss: Bool = false
    public var isOverlayVisible: Bool = true
    /// フォトビューア画面のみに適用される画面回転設定
    public private(set) var orientationLock: PhotoViewerOrientationLock

    /// レーティング機能が有効か（星ボタン・カラーラベルの表示可否）
    public let isRatingEnabled: Bool

    // MARK: - 派生状態

    public var currentURL: URL { allURLs[currentIndex] }
    public var currentFileName: String { currentURL.lastPathComponent }
    public var canGoPrevious: Bool { currentIndex > 0 }
    public var canGoNext: Bool { currentIndex < allURLs.count - 1 }

    /// PiP再生中に自動的に次の写真へ進める間隔（秒。設定Menuで変更可能）
    public var pipAutoAdvanceIntervalSeconds: Int { settings.pipAutoAdvanceIntervalSeconds }

    // MARK: - 依存関係

    private let imageLoader: any ImageLoaderServiceProtocol
    private let exifService: any ExifServiceProtocol
    private let photoLibrary: any PhotoLibraryServiceProtocol
    private let savedDateStore: any SavedDateStoreProtocol
    private let ratingStore: any PhotoRatingStoreProtocol
    private let colorLabelStore: any ColorLabelStoreProtocol
    private let hapticsService: any HapticsServiceProtocol
    private let settings: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>
    private let ratingFilter: RatingFilter?
    private let colorLabelFilter: Set<PhotoColorLabel>

    // MARK: - 初期化

    public init(input: PhotoViewerInput, dependencies: PhotoViewerDependencies) {
        allURLs = input.allURLs
        currentIndex = input.allURLs.firstIndex(of: input.initialURL) ?? 0
        isRatingEnabled = input.isRatingEnabled
        ratingFilter = input.ratingFilter
        colorLabelFilter = input.colorLabelFilter
        imageLoader = dependencies.imageLoader
        exifService = dependencies.exifService
        photoLibrary = dependencies.photoLibrary
        savedDateStore = dependencies.savedDateStore
        ratingStore = dependencies.ratingStore
        colorLabelStore = dependencies.colorLabelStore
        hapticsService = dependencies.hapticsService
        settings = dependencies.settings
        orientationLock = dependencies.settings.orientationLock
        lastSavedDate = dependencies.savedDateStore.date(for: input.allURLs[currentIndex])
        currentRating = dependencies.ratingStore.rating(for: input.allURLs[currentIndex])
        currentColorLabel = dependencies.colorLabelStore.label(for: input.allURLs[currentIndex])
    }

    // MARK: - ライフサイクル

    /// 初期インデックスの画像とEXIFを読み込む。VCの準備完了後に一度だけ呼ぶ。
    public func loadInitial() async {
        await loadImageAndExif(for: currentURL)
    }

    // MARK: - ナビゲーション

    public func navigatePrevious() async {
        guard canGoPrevious else { return }
        await navigate(to: currentIndex - 1)
    }

    public func navigateNext() async {
        guard canGoNext else { return }
        await navigate(to: currentIndex + 1)
    }

    /// PiP再生中の自動送り用のナビゲーション。前後ボタンと異なり末尾では停止せず、先頭へ固定でループする
    public func advanceForPictureInPictureAutoPlay() async {
        guard allURLs.count > 1 else { return }
        await navigate(to: (currentIndex + 1) % allURLs.count)
    }

    /// 任意のインデックスへ遷移する（ボタンナビゲーションとレーティング変更による自動遷移で使用）
    private func navigate(to index: Int) async {
        previousOrientation = currentImage?.photoOrientation
        currentIndex = index
        saveStatus = .idle
        lastSavedDate = savedDateStore.date(for: currentURL)
        currentRating = ratingStore.rating(for: currentURL)
        currentColorLabel = colorLabelStore.label(for: currentURL)
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
        currentRating = ratingStore.rating(for: currentURL)
        currentColorLabel = colorLabelStore.label(for: currentURL)
        await loadExif(for: currentURL)
    }

    // MARK: - レーティング・カラーラベル

    /// 星をタップした時の処理。現在と同じ星の位置なら星0に戻す。
    public func setRating(_ stars: Int) async {
        let newRating = stars == currentRating ? 0 : stars
        currentRating = newRating
        ratingStore.setRating(newRating, for: currentURL)
        await autoNavigateIfFilteredOut()
    }

    /// カラーラベルをタップした時の処理。現在と同じ色ならラベルなしに戻す。
    public func setColorLabel(_ label: PhotoColorLabel) async {
        let newLabel = label == currentColorLabel ? nil : label
        currentColorLabel = newLabel
        colorLabelStore.setLabel(newLabel, for: currentURL)
        await autoNavigateIfFilteredOut()
    }

    /// レーティング・カラーラベルのいずれかのフィルタが有効か
    private var hasActiveFilter: Bool {
        ratingFilter != nil || !colorLabelFilter.isEmpty
    }

    /// 指定URLが現在のフィルタ（レーティング・カラーラベルの複合条件）に適合するかを返す
    private func matchesFilters(url: URL) -> Bool {
        if let filter = ratingFilter, !filter.matches(ratingStore.rating(for: url)) { return false }
        if !colorLabelFilter.isEmpty {
            guard let label = colorLabelStore.label(for: url), colorLabelFilter.contains(label) else { return false }
        }
        return true
    }

    /// 現在の写真がフィルタに合わなくなった場合、後方→前方の順で適合写真へ自動遷移し、
    /// 適合写真が1枚も無ければshouldDismissを立てる。
    private func autoNavigateIfFilteredOut() async {
        guard hasActiveFilter, !matchesFilters(url: currentURL) else { return }
        if let nextIndex = firstMatchingIndex(after: currentIndex) {
            await navigate(to: nextIndex)
        } else if let previousIndex = firstMatchingIndex(before: currentIndex) {
            await navigate(to: previousIndex)
        } else {
            shouldDismiss = true
        }
    }

    /// 指定インデックスより後方で、フィルタに適合する最初のインデックスを返す
    private func firstMatchingIndex(after index: Int) -> Int? {
        ((index + 1)..<allURLs.count).first { matchesFilters(url: allURLs[$0]) }
    }

    /// 指定インデックスより前方で、フィルタに適合する直近のインデックスを返す
    private func firstMatchingIndex(before index: Int) -> Int? {
        (0..<index).reversed().first { matchesFilters(url: allURLs[$0]) }
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

    // MARK: - 画面回転設定

    /// 画面回転ボタンタップ時の処理。「端末の設定に追従」→「縦画面固定」→「横画面固定」の順に循環する
    public func cycleOrientationLock() {
        orientationLock = orientationLock.next
        settings.orientationLock = orientationLock
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
