import Testing
import Core
import UIKit
import Foundation
@testable import PhotoViewer

// MARK: - テスト

@Suite
@MainActor
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
    let viewModel: PhotoViewerViewModel

    init() {
        imageLoader = MockImageLoaderService()
        exifService = MockExifService()
        photoLibrary = MockPhotoLibraryService()
        savedDateStore = MockSavedDateStore()
        ratingStore = MockPhotoRatingStore()
        colorLabelStore = MockColorLabelStore()
        hapticsService = MockHapticsService()

        let urls = [
            URL(fileURLWithPath: "/tmp/photo1.jpg"),
            URL(fileURLWithPath: "/tmp/photo2.jpg"),
            URL(fileURLWithPath: "/tmp/photo3.jpg"),
        ]
        let input = PhotoViewerInput(initialURL: urls[0], allURLs: urls)
        let services = PhotoViewerServices(
            imageLoader: imageLoader,
            exifService: exifService,
            photoLibrary: photoLibrary,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            hapticsService: hapticsService
        )
        viewModel = PhotoViewerViewModel(input: input, services: services)
    }

    /// テスト用のViewModelを指定のURL・レーティング設定で生成するヘルパー
    private func makeViewModel(
        initialURL: URL,
        isRatingEnabled: Bool = false,
        ratingFilter: RatingFilter? = nil,
        colorLabelFilter: Set<PhotoColorLabel> = []
    ) -> PhotoViewerViewModel {
        let input = PhotoViewerInput(
            initialURL: initialURL,
            allURLs: [url1, url2, url3],
            isRatingEnabled: isRatingEnabled,
            ratingFilter: ratingFilter,
            colorLabelFilter: colorLabelFilter
        )
        let services = PhotoViewerServices(
            imageLoader: imageLoader,
            exifService: exifService,
            photoLibrary: photoLibrary,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            hapticsService: hapticsService
        )
        return PhotoViewerViewModel(input: input, services: services)
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
    func didSwipeTo_resetsPreviousOrientation() async {
        await viewModel.didSwipeTo(index: 1, image: nil)
        #expect(viewModel.previousOrientation == nil)
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

    // MARK: - レーティングフィルターによる自動遷移

    @Test
    func setRating_stillMatchingFilter_staysOnCurrentPhoto() async {
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, ratingFilter: filter)
        await vm.setRating(4)
        #expect(vm.currentIndex == 0)
        #expect(vm.shouldDismiss == false)
    }

    @Test
    func setRating_unmatchingFilter_advancesToNextMatchingPhoto() async {
        // フィルター: 星3以上。url2は不適合、url3は適合
        ratingStore.setRating(1, for: url2)
        ratingStore.setRating(4, for: url3)
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, ratingFilter: filter)

        await vm.setRating(1)  // url1が星1になりフィルターに不適合

        #expect(vm.currentURL == url3)
        #expect(vm.currentRating == 4)
    }

    @Test
    func setRating_noNextMatch_fallsBackToPreviousPhoto() async {
        // フィルター: 星3以上。前方のurl1のみ適合
        ratingStore.setRating(4, for: url1)
        ratingStore.setRating(3, for: url2)
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        let vm = makeViewModel(initialURL: url2, isRatingEnabled: true, ratingFilter: filter)

        await vm.setRating(1)  // url2が星1になりフィルターに不適合

        #expect(vm.currentURL == url1)
        #expect(vm.shouldDismiss == false)
    }

    @Test
    func setRating_noMatchesAtAll_requestsDismiss() async {
        // フィルター: 星3以上。唯一適合していたurl1を星1に変更する
        ratingStore.setRating(4, for: url1)
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, ratingFilter: filter)

        await vm.setRating(1)

        #expect(vm.shouldDismiss == true)
        #expect(vm.currentURL == url1)
    }

    @Test
    func setRating_withoutFilter_doesNotNavigate() async {
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, ratingFilter: nil)
        await vm.setRating(1)
        #expect(vm.currentIndex == 0)
        #expect(vm.shouldDismiss == false)
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
    func setColorLabel_unmatchingFilter_advancesToNextMatchingPhoto() async {
        // フィルター: 緑のみ。url2は不適合（赤）、url3は適合（緑）
        colorLabelStore.setLabel(.green, for: url1)
        colorLabelStore.setLabel(.red, for: url2)
        colorLabelStore.setLabel(.green, for: url3)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, colorLabelFilter: [.green])

        await vm.setColorLabel(.blue)  // url1が青になりフィルターに不適合

        #expect(vm.currentURL == url3)
        #expect(vm.currentColorLabel == .green)
    }

    @Test
    func setColorLabel_noNextMatch_fallsBackToPreviousPhoto() async {
        // フィルター: 緑のみ。前方のurl1のみ適合
        colorLabelStore.setLabel(.green, for: url1)
        colorLabelStore.setLabel(.green, for: url2)
        let vm = makeViewModel(initialURL: url2, isRatingEnabled: true, colorLabelFilter: [.green])

        await vm.setColorLabel(.red)  // url2が赤になりフィルターに不適合

        #expect(vm.currentURL == url1)
        #expect(vm.shouldDismiss == false)
    }

    @Test
    func setColorLabel_noMatchesAtAll_requestsDismiss() async {
        // フィルター: 緑のみ。唯一適合していたurl1のラベルを解除する
        colorLabelStore.setLabel(.green, for: url1)
        let vm = makeViewModel(initialURL: url1, isRatingEnabled: true, colorLabelFilter: [.green])

        await vm.setColorLabel(.green)  // 同色タップでラベル解除

        #expect(vm.shouldDismiss == true)
        #expect(vm.currentURL == url1)
    }

    @Test
    func setRating_combinedFilter_advancesWhenColorFilterUnmatched() async {
        // 複合フィルター: 星2以上 かつ 緑。url3のみ両方適合
        ratingStore.setRating(3, for: url1)
        colorLabelStore.setLabel(.green, for: url1)
        ratingStore.setRating(5, for: url2)  // 星は適合するがラベルなし
        ratingStore.setRating(2, for: url3)
        colorLabelStore.setLabel(.green, for: url3)
        let vm = makeViewModel(
            initialURL: url1,
            isRatingEnabled: true,
            ratingFilter: RatingFilter(stars: 2, comparison: .atLeast),
            colorLabelFilter: [.green]
        )

        await vm.setRating(1)  // url1が星1になり複合フィルターに不適合

        #expect(vm.currentURL == url3)
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
}
