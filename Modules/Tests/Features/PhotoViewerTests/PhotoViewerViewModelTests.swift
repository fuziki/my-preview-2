import Testing
import Core
import UIKit
import Foundation
import MocksForTest
@testable import PhotoViewer

// MARK: - テスト

struct PhotoViewerViewModelTests {

    let url1 = URL(fileURLWithPath: "/tmp/photo1.jpg")
    let url2 = URL(fileURLWithPath: "/tmp/photo2.jpg")
    let url3 = URL(fileURLWithPath: "/tmp/photo3.jpg")

    let imageLoader: MockImageLoaderService
    let exifService: MockExifService
    let photoLibrary: MockPhotoLibraryService
    let savedDateStore: MockSavedDateStore
    let ratingStore: MockPhotoRatingStore
    let colorLabelStore: MockColorLabelStore
    let hapticsService: MockHapticsService
    let settings: MockUserDefaultsSettingsStore
    /// フィルター済み写真リストの唯一の真実（SSOT）。FileBrowserが公開する体でテストからsetURLsする
    let photoCollectionStore: PhotoCollectionStore
    let viewModel: PhotoViewerViewModel

    init() {
        imageLoader = MockImageLoaderService()
        exifService = MockExifService()
        photoLibrary = MockPhotoLibraryService()
        savedDateStore = MockSavedDateStore()
        ratingStore = MockPhotoRatingStore()
        colorLabelStore = MockColorLabelStore()
        hapticsService = MockHapticsService()
        settings = MockUserDefaultsSettingsStore()
        photoCollectionStore = PhotoCollectionStore()

        let urls = [
            URL(fileURLWithPath: "/tmp/photo1.jpg"),
            URL(fileURLWithPath: "/tmp/photo2.jpg"),
            URL(fileURLWithPath: "/tmp/photo3.jpg"),
        ]
        photoCollectionStore.setURLs(urls)
        let input = PhotoViewerInput(initialURL: urls[0])
        let dependencies = PhotoViewerDependencies(
            imageLoader: imageLoader,
            exifService: exifService,
            photoLibrary: photoLibrary,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            hapticsService: hapticsService,
            settings: settings,
            photoCollectionStore: photoCollectionStore
        )
        viewModel = PhotoViewerViewModel(input: input, dependencies: dependencies)
    }

    /// 現在のモックと指定のphotoCollectionStoreを使ってDependenciesを組み立てるヘルパー
    private func makeDependencies(photoCollectionStore: any PhotoCollectionStoreProtocol) -> PhotoViewerDependencies {
        PhotoViewerDependencies(
            imageLoader: imageLoader,
            exifService: exifService,
            photoLibrary: photoLibrary,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            hapticsService: hapticsService,
            settings: settings,
            photoCollectionStore: photoCollectionStore
        )
    }

    /// テスト用のViewModelを指定のURL・レーティング設定で生成するヘルパー。
    /// photoCollectionStore（SSOT）は呼び出し側のインスタンス（デフォルトはこのスイート共有のもの）を使う。
    private func makeViewModel(
        initialURL: URL,
        isRatingEnabled: Bool = false,
        ratingFilter: RatingFilter? = nil,
        colorLabelFilter: Set<PhotoColorLabel> = [],
        savedFilter: SavedFilter? = nil,
        photoCollectionStore: (any PhotoCollectionStoreProtocol)? = nil
    ) -> PhotoViewerViewModel {
        let input = PhotoViewerInput(
            initialURL: initialURL,
            isRatingEnabled: isRatingEnabled,
            ratingFilter: ratingFilter,
            colorLabelFilter: colorLabelFilter,
            savedFilter: savedFilter
        )
        let dependencies = makeDependencies(photoCollectionStore: photoCollectionStore ?? self.photoCollectionStore)
        return PhotoViewerViewModel(input: input, dependencies: dependencies)
    }

    /// 条件が満たされるまでポーリングして待機する（固定時間sleepによるCI環境でのフレークを避けるためのヘルパー）
    private func waitUntil(
        timeout: Duration = .seconds(30),
        pollInterval: Duration = .milliseconds(20),
        _ condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            if ContinuousClock.now >= deadline { return }
            try await Task.sleep(for: pollInterval)
        }
    }

    // MARK: - 初期状態

    @Test
    func initialState_currentIndexIsZero() {
        #expect(viewModel.currentIndex == 0)
    }

    @Test
    func initialState_allURLsSet() {
        #expect(viewModel.allURLs == [url1, url2, url3])
    }

    @Test
    func initialState_currentURLIsInitialURL() {
        #expect(viewModel.currentURL == url1)
    }

    @Test
    func initialState_currentImageIsNil() {
        #expect(viewModel.currentImage == nil)
    }

    @Test
    func initialState_exifInfoIsNil() {
        #expect(viewModel.exifInfo == nil)
    }

    @Test
    func initialState_saveStatusIsIdle() {
        #expect(viewModel.saveStatus == .idle)
    }

    @Test
    func initialState_isOverlayVisibleTrue() {
        #expect(viewModel.isOverlayVisible == true)
    }

    @Test
    func initialState_canGoNextTrue() {
        #expect(viewModel.canGoNext == true)
    }

    @Test
    func initialState_canGoPreviousFalse() {
        #expect(viewModel.canGoPrevious == false)
    }

    // MARK: - 初期URL指定

    @Test
    func init_withMiddleInitialURL_setsCorrectIndex() {
        let vm = makeViewModel(initialURL: url2)
        #expect(vm.currentIndex == 1)
    }

    @Test
    func init_withLastInitialURL_setsCorrectIndex() {
        let vm = makeViewModel(initialURL: url3)
        #expect(vm.currentIndex == 2)
    }

    // MARK: - 派生プロパティ

    @Test
    func currentFileName_returnsLastPathComponent() {
        #expect(viewModel.currentFileName == "photo1.jpg")
    }

    @Test
    func canGoNext_falseAtLastItem() async {
        await viewModel.navigateNext()
        await viewModel.navigateNext()
        #expect(viewModel.canGoNext == false)
    }

    @Test
    func canGoPrevious_trueAfterNavigateNext() async {
        await viewModel.navigateNext()
        #expect(viewModel.canGoPrevious == true)
    }

    // MARK: - lastChangeWasSwipe（スワイプ時は子ページャへ moveToIndex を呼ばないための信号）

    @Test
    func initialState_lastChangeWasSwipeFalse() {
        #expect(viewModel.lastChangeWasSwipe == false)
    }

    @Test
    func didSwipeTo_setsLastChangeWasSwipeTrue() async {
        await viewModel.didSwipeTo(index: 1, image: nil)
        #expect(viewModel.lastChangeWasSwipe == true)
    }

    @Test
    func navigateNext_setsLastChangeWasSwipeFalse() async {
        // スワイプ後にボタン移動すると false へ戻る（moveToIndex が適用される）
        await viewModel.didSwipeTo(index: 1, image: nil)
        await viewModel.navigateNext()
        #expect(viewModel.lastChangeWasSwipe == false)
    }

    // MARK: - loadInitial

    @Test
    func loadInitial_setsCurrentImage() async {
        await viewModel.loadInitial()
        #expect(viewModel.currentImage != nil)
    }

    @Test
    func loadInitial_setsExifInfo() async {
        await viewModel.loadInitial()
        #expect(viewModel.exifInfo != nil)
    }

    @Test
    func loadInitial_isLoadingFalseAfterCompletion() async {
        await viewModel.loadInitial()
        #expect(viewModel.isLoading == false)
    }

    @Test
    func loadInitial_callsImageLoader() async {
        await viewModel.loadInitial()
        #expect(imageLoader.loadCallCount == 1)
    }

    @Test
    func loadInitial_callsExifService() async {
        await viewModel.loadInitial()
        #expect(exifService.extractCallCount == 1)
    }

    // MARK: - navigateNext

    @Test
    func navigateNext_incrementsCurrentIndex() async {
        await viewModel.navigateNext()
        #expect(viewModel.currentIndex == 1)
    }

    @Test
    func navigateNext_updatesCurrentURL() async {
        await viewModel.navigateNext()
        #expect(viewModel.currentURL == url2)
    }

    @Test
    func navigateNext_doesNothing_atLastItem() async {
        await viewModel.navigateNext()
        await viewModel.navigateNext()
        await viewModel.navigateNext() // 最後を超えようとする
        #expect(viewModel.currentIndex == 2)
    }

    @Test
    func navigateNext_resetsSaveStatus() async {
        await viewModel.loadInitial()
        await viewModel.navigateNext()
        #expect(viewModel.saveStatus == .idle)
    }

    @Test
    func navigateNext_loadsImageAndExif() async {
        await viewModel.navigateNext()
        #expect(imageLoader.loadCallCount == 1)
        #expect(exifService.extractCallCount == 1)
    }

    // MARK: - advanceForPictureInPictureAutoPlay

    @Test
    func advanceForPictureInPictureAutoPlay_incrementsCurrentIndex() async {
        await viewModel.advanceForPictureInPictureAutoPlay()
        #expect(viewModel.currentIndex == 1)
    }

    @Test
    func advanceForPictureInPictureAutoPlay_atLastItem_wrapsToFirstItem() async {
        // navigateNext()と異なり、末尾で停止せず先頭へループする（PiP自動送りの意図的な仕様）
        await viewModel.navigateNext()
        await viewModel.navigateNext()
        #expect(viewModel.currentIndex == 2)

        await viewModel.advanceForPictureInPictureAutoPlay()

        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.currentURL == url1)
    }

    @Test
    func advanceForPictureInPictureAutoPlay_singleItemGallery_doesNothing() async {
        let singleItemStore = PhotoCollectionStore()
        singleItemStore.setURLs([url1])
        let vm = PhotoViewerViewModel(
            input: PhotoViewerInput(initialURL: url1),
            dependencies: PhotoViewerDependencies(
                imageLoader: imageLoader,
                exifService: exifService,
                photoLibrary: photoLibrary,
                savedDateStore: savedDateStore,
                ratingStore: ratingStore,
                colorLabelStore: colorLabelStore,
                hapticsService: hapticsService,
                settings: settings,
                photoCollectionStore: singleItemStore
            )
        )
        await vm.advanceForPictureInPictureAutoPlay()
        #expect(vm.currentIndex == 0)
    }

    // MARK: - navigatePrevious

    @Test
    func navigatePrevious_doesNothing_atFirstItem() async {
        await viewModel.navigatePrevious()
        #expect(viewModel.currentIndex == 0)
    }

    @Test
    func navigatePrevious_decrementsCurrentIndex() async {
        await viewModel.navigateNext()
        await viewModel.navigatePrevious()
        #expect(viewModel.currentIndex == 0)
    }

    @Test
    func navigatePrevious_updatesCurrentURL() async {
        await viewModel.navigateNext()
        await viewModel.navigatePrevious()
        #expect(viewModel.currentURL == url1)
    }

    @Test
    func navigatePrevious_resetsSaveStatus() async {
        await viewModel.navigateNext()
        await viewModel.navigatePrevious()
        #expect(viewModel.saveStatus == .idle)
    }

    // MARK: - didSwipeTo

    @Test
    func didSwipeTo_updatesCurrentIndex() async {
        await viewModel.didSwipeTo(index: 2, image: nil)
        #expect(viewModel.currentIndex == 2)
    }

    @Test
    func didSwipeTo_setsCurrentImage_whenImageProvided() async {
        let image = UIImage()
        await viewModel.didSwipeTo(index: 1, image: image)
        #expect(viewModel.currentImage != nil)
    }

    @Test
    func didSwipeTo_callsExifService() async {
        await viewModel.didSwipeTo(index: 1, image: nil)
        #expect(exifService.extractCallCount == 1)
    }

    @Test
    func didSwipeTo_resetsSaveStatus() async {
        await viewModel.didSwipeTo(index: 1, image: nil)
        #expect(viewModel.saveStatus == .idle)
    }

    @Test
    func didSwipeTo_doesNotCallImageLoader() async {
        // スワイプ時は画像が既に表示済みなのでloadImageは呼ばれない
        await viewModel.didSwipeTo(index: 1, image: UIImage())
        #expect(imageLoader.loadCallCount == 0)
    }

    // MARK: - save（成功）

    @Test
    func save_withImage_callsPhotoLibrary() async {
        await viewModel.loadInitial()
        await viewModel.save()
        #expect(photoLibrary.saveCallCount == 1)
    }

    @Test
    func save_withImage_callsHapticsSuccess() async {
        await viewModel.loadInitial()
        await viewModel.save()
        #expect(hapticsService.notifySuccessCallCount == 1)
    }

    @Test
    func save_withImage_updatesLastSavedDate() async {
        await viewModel.loadInitial()
        await viewModel.save()
        #expect(viewModel.lastSavedDate != nil)
    }

    @Test
    func save_withoutImage_doesNotCallPhotoLibrary() async {
        // currentImageがnilのまま保存を試みる
        await viewModel.save()
        #expect(photoLibrary.saveCallCount == 0)
    }

    // MARK: - save（失敗）

    @Test
    func save_onFailure_setsFailureStatus() async {
        photoLibrary.shouldThrow = true
        await viewModel.loadInitial()
        await viewModel.save()
        #expect(viewModel.saveStatus == .failure)
    }

    @Test
    func save_onFailure_callsHapticsError() async {
        photoLibrary.shouldThrow = true
        await viewModel.loadInitial()
        await viewModel.save()
        #expect(hapticsService.notifyErrorCallCount == 1)
    }

    @Test
    func save_onFailure_doesNotUpdateLastSavedDate() async {
        photoLibrary.shouldThrow = true
        await viewModel.loadInitial()
        await viewModel.save()
        #expect(viewModel.lastSavedDate == nil)
    }

    // MARK: - レーティング

    @Test
    func initialState_currentRatingIsZero() {
        #expect(viewModel.currentRating == 0)
    }

    @Test
    func init_restoresRating_fromStore() {
        ratingStore.setRating(4, for: url2)
        let vm = makeViewModel(initialURL: url2)
        #expect(vm.currentRating == 4)
    }

    @Test
    func setRating_updatesCurrentRatingAndStore() async {
        await viewModel.setRating(3)
        #expect(viewModel.currentRating == 3)
        #expect(ratingStore.rating(for: url1) == 3)
    }

    @Test
    func setRating_sameStars_resetsToZero() async {
        await viewModel.setRating(3)
        await viewModel.setRating(3)
        #expect(viewModel.currentRating == 0)
        #expect(ratingStore.rating(for: url1) == 0)
    }

    @Test
    func setRating_differentStars_overwrites() async {
        await viewModel.setRating(3)
        await viewModel.setRating(5)
        #expect(viewModel.currentRating == 5)
        #expect(ratingStore.rating(for: url1) == 5)
    }

    @Test
    func navigateNext_updatesCurrentRating() async {
        ratingStore.setRating(2, for: url2)
        await viewModel.navigateNext()
        #expect(viewModel.currentRating == 2)
    }

    @Test
    func didSwipeTo_updatesCurrentRating() async {
        ratingStore.setRating(5, for: url3)
        await viewModel.didSwipeTo(index: 2, image: nil)
        #expect(viewModel.currentRating == 5)
    }

    // MARK: - レーティングフィルターによる自動遷移（SSOT: photoCollectionStoreからの除去）
    //
    // photoCollectionStore.urlsは常に「全件がフィルターに適合済み」であることが前提（FileBrowserが
    // フィルタ済みリストを公開するため）。よってこれらのテストでは、シナリオごとに適合する写真のみを
    // 収めた専用のPhotoCollectionStoreを用意し、現在写真が不適合になった際に「除去 → 同じ位置（＝旧next。
    // 末尾なら旧prev）へ遷移」という新しい自動遷移の挙動を検証する。

    @Test
    func setRating_stillMatchingFilter_staysOnCurrentPhoto() async {
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, ratingFilter: filter)
        await vm.setRating(4)
        #expect(vm.currentIndex == 0)
        #expect(vm.shouldDismiss == false)
        #expect(photoCollectionStore.urls.count == 3)
    }

    @Test
    func setRating_unmatchingFilter_removesCurrentAndAdvancesToNextPhoto() async {
        // フィルター: 星3以上。3枚とも初期状態で適合させておく（storeは常に全件適合が前提のため）
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2, url3])
        ratingStore.setRating(3, for: url1)
        ratingStore.setRating(3, for: url2)
        ratingStore.setRating(3, for: url3)
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, ratingFilter: filter, photoCollectionStore: store)

        await vm.setRating(1)  // url1が星1になりフィルターに不適合

        #expect(store.urls == [url2, url3])
        #expect(vm.allURLs.count == 2)
        #expect(vm.currentURL == url2)
        #expect(vm.shouldDismiss == false)
    }

    @Test
    func setRating_removingLastPhotoInStore_fallsBackToPreviousPhoto() async {
        // フィルター: 星3以上。storeにはurl1・url2のみ（url2が末尾）
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2])
        ratingStore.setRating(4, for: url1)
        ratingStore.setRating(3, for: url2)
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        let vm = makeViewModel(initialURL: url2, isRatingEnabled: true, ratingFilter: filter, photoCollectionStore: store)

        await vm.setRating(1)  // url2が星1になりフィルターに不適合。storeの末尾だったため前へ戻る

        #expect(store.urls == [url1])
        #expect(vm.currentURL == url1)
        #expect(vm.shouldDismiss == false)
    }

    @Test
    func setRating_onlyMatchInStore_requestsDismissAndEmptiesStore() async {
        // フィルター: 星3以上。storeにはurl1のみ（唯一の適合写真）
        let store = PhotoCollectionStore()
        store.setURLs([url1])
        ratingStore.setRating(4, for: url1)
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, ratingFilter: filter, photoCollectionStore: store)

        await vm.setRating(1)  // url1が星1になりフィルターに不適合

        #expect(vm.shouldDismiss == true)
        #expect(store.urls.isEmpty)
        #expect(vm.allURLs.isEmpty)
    }

    @Test
    func setRating_withoutFilter_doesNotNavigate() async {
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, ratingFilter: nil)
        await vm.setRating(1)
        #expect(vm.currentIndex == 0)
        #expect(vm.shouldDismiss == false)
        #expect(photoCollectionStore.urls.count == 3)
    }

    // MARK: - カラーラベル

    @Test
    func initialState_currentColorLabelIsNil() {
        #expect(viewModel.currentColorLabel == nil)
    }

    @Test
    func init_restoresColorLabel_fromStore() {
        colorLabelStore.setLabel(.blue, for: url2)
        let vm = makeViewModel(initialURL: url2)
        #expect(vm.currentColorLabel == .blue)
    }

    @Test
    func setColorLabel_updatesCurrentLabelAndStore() async {
        await viewModel.setColorLabel(.green)
        #expect(viewModel.currentColorLabel == .green)
        #expect(colorLabelStore.label(for: url1) == .green)
    }

    @Test
    func setColorLabel_sameLabel_resetsToNil() async {
        await viewModel.setColorLabel(.green)
        await viewModel.setColorLabel(.green)
        #expect(viewModel.currentColorLabel == nil)
        #expect(colorLabelStore.label(for: url1) == nil)
    }

    @Test
    func setColorLabel_differentLabel_overwrites() async {
        await viewModel.setColorLabel(.green)
        await viewModel.setColorLabel(.red)
        #expect(viewModel.currentColorLabel == .red)
        #expect(colorLabelStore.label(for: url1) == .red)
    }

    @Test
    func navigateNext_updatesCurrentColorLabel() async {
        colorLabelStore.setLabel(.pink, for: url2)
        await viewModel.navigateNext()
        #expect(viewModel.currentColorLabel == .pink)
    }

    @Test
    func didSwipeTo_updatesCurrentColorLabel() async {
        colorLabelStore.setLabel(.white, for: url3)
        await viewModel.didSwipeTo(index: 2, image: nil)
        #expect(viewModel.currentColorLabel == .white)
    }

    // MARK: - カラーラベルフィルターによる自動遷移

    @Test
    func setColorLabel_stillMatchingFilter_staysOnCurrentPhoto() async {
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, colorLabelFilter: [.green, .red])
        await vm.setColorLabel(.red)
        #expect(vm.currentIndex == 0)
        #expect(vm.shouldDismiss == false)
    }

    @Test
    func setColorLabel_unmatchingFilter_removesCurrentAndAdvancesToNextPhoto() async {
        // フィルター: 緑のみ。storeにはurl1・url3のみ（両方とも緑で適合）
        let store = PhotoCollectionStore()
        store.setURLs([url1, url3])
        colorLabelStore.setLabel(.green, for: url1)
        colorLabelStore.setLabel(.green, for: url3)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, colorLabelFilter: [.green], photoCollectionStore: store)

        await vm.setColorLabel(.blue)  // url1が青になりフィルターに不適合

        #expect(store.urls == [url3])
        #expect(vm.currentURL == url3)
        #expect(vm.currentColorLabel == .green)
    }

    @Test
    func setColorLabel_removingLastPhotoInStore_fallsBackToPreviousPhoto() async {
        // フィルター: 緑のみ。storeにはurl1・url2のみ（url2が末尾）
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2])
        colorLabelStore.setLabel(.green, for: url1)
        colorLabelStore.setLabel(.green, for: url2)
        let vm = makeViewModel(initialURL: url2, isRatingEnabled: true, colorLabelFilter: [.green], photoCollectionStore: store)

        await vm.setColorLabel(.red)  // url2が赤になりフィルターに不適合。storeの末尾だったため前へ戻る

        #expect(store.urls == [url1])
        #expect(vm.currentURL == url1)
        #expect(vm.shouldDismiss == false)
    }

    @Test
    func setColorLabel_onlyMatchInStore_requestsDismissAndEmptiesStore() async {
        // フィルター: 緑のみ。storeにはurl1のみ（唯一の適合写真）のラベルを解除する
        let store = PhotoCollectionStore()
        store.setURLs([url1])
        colorLabelStore.setLabel(.green, for: url1)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, colorLabelFilter: [.green], photoCollectionStore: store)

        await vm.setColorLabel(.green)  // 同色タップでラベル解除

        #expect(vm.shouldDismiss == true)
        #expect(store.urls.isEmpty)
    }

    @Test
    func setRating_combinedFilterUnmatched_removesCurrentAndAdvancesToNextPhoto() async {
        // 複合フィルター: 星2以上 かつ 緑。storeにはurl1・url3のみ（両方とも適合）
        let store = PhotoCollectionStore()
        store.setURLs([url1, url3])
        ratingStore.setRating(3, for: url1)
        colorLabelStore.setLabel(.green, for: url1)
        ratingStore.setRating(2, for: url3)
        colorLabelStore.setLabel(.green, for: url3)
        let vm = makeViewModel(
            initialURL: url1,
            isRatingEnabled: true,
            ratingFilter: RatingFilter(stars: 2, comparison: .atLeast),
            colorLabelFilter: [.green],
            photoCollectionStore: store
        )

        await vm.setRating(1)  // url1が星1になり複合フィルターに不適合

        #expect(store.urls == [url3])
        #expect(vm.currentURL == url3)
    }

    // MARK: - 保存状態フィルターによる自動遷移（SSOT: photoCollectionStoreからの除去）

    @Test
    func save_unsavedOnlyFilter_advancesToNextUnsavedPhoto() async {
        // url2・url3は未保存のまま、url1のみ保存する（3枚とも未保存で開始 = 全件適合の前提を満たす）
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, savedFilter: .unsavedOnly)
        await vm.loadInitial()

        await vm.save()

        #expect(photoCollectionStore.urls == [url2, url3])
        #expect(vm.currentURL == url2)
    }

    @Test
    func save_unsavedOnlyFilter_removingLastPhotoInStore_fallsBackToPreviousPhoto() async {
        // storeにはurl1・url2のみ（url2が末尾、両方とも未保存で適合）
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2])
        let vm = makeViewModel(initialURL: url2, isRatingEnabled: true, savedFilter: .unsavedOnly, photoCollectionStore: store)
        await vm.loadInitial()

        await vm.save()  // url2を保存 → storeの末尾だったため前方のurl1へ

        #expect(store.urls == [url1])
        #expect(vm.currentURL == url1)
        #expect(vm.shouldDismiss == false)
    }

    @Test
    func save_unsavedOnlyFilter_onlyMatchInStore_requestsDismissAndEmptiesStore() async {
        // storeにはurl1のみ（唯一の未保存＝適合写真）
        let store = PhotoCollectionStore()
        store.setURLs([url1])
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, savedFilter: .unsavedOnly, photoCollectionStore: store)
        await vm.loadInitial()

        await vm.save()

        #expect(vm.shouldDismiss == true)
        #expect(store.urls.isEmpty)
    }

    // MARK: - toggleOverlay

    @Test
    func toggleOverlay_flipsVisibility() {
        let initial = viewModel.isOverlayVisible
        viewModel.toggleOverlay()
        #expect(viewModel.isOverlayVisible == !initial)
    }

    @Test
    func toggleOverlay_twice_restoresOriginalValue() {
        let initial = viewModel.isOverlayVisible
        viewModel.toggleOverlay()
        viewModel.toggleOverlay()
        #expect(viewModel.isOverlayVisible == initial)
    }

    // MARK: - cycleOrientationLock

    @Test
    func initialState_orientationLockIsFollowSystem() {
        #expect(viewModel.orientationLock == .followSystem)
    }

    @Test
    func cycleOrientationLock_fromFollowSystem_movesToPortrait() {
        viewModel.cycleOrientationLock()
        #expect(viewModel.orientationLock == .portrait)
    }

    @Test
    func cycleOrientationLock_threeTimes_returnsToFollowSystem() {
        viewModel.cycleOrientationLock()
        viewModel.cycleOrientationLock()
        viewModel.cycleOrientationLock()
        #expect(viewModel.orientationLock == .followSystem)
    }

    @Test
    func cycleOrientationLock_persistsToSettings() {
        viewModel.cycleOrientationLock()
        #expect(settings.orientationLock == .portrait)
    }

    // MARK: - startAutoNavigation

    @Test
    func startAutoNavigation_forward_stopsAtLastItem() async throws {
        // 境界（末尾）に到達すると自動的にループが終了することを確認する。
        // 固定時間のsleepはCI環境の実行速度差でフレークするため、条件成立をポーリングで待つ。
        viewModel.startAutoNavigation(forward: true)
        try await waitUntil { viewModel.canGoNext == false }
        viewModel.stopAutoNavigation()
        #expect(viewModel.currentIndex == 2)
        #expect(viewModel.canGoNext == false)
    }
}
