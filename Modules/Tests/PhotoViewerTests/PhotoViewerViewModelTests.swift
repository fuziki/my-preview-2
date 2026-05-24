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
    let hapticsService: MockHapticsService
    let viewModel: PhotoViewerViewModel

    init() {
        imageLoader = MockImageLoaderService()
        exifService = MockExifService()
        photoLibrary = MockPhotoLibraryService()
        savedDateStore = MockSavedDateStore()
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
            hapticsService: hapticsService
        )
        viewModel = PhotoViewerViewModel(input: input, services: services)
    }

    /// テスト用のViewModelを指定のURLで生成するヘルパー
    private func makeViewModel(initialURL: URL) -> PhotoViewerViewModel {
        let input = PhotoViewerInput(initialURL: initialURL, allURLs: [url1, url2, url3])
        let services = PhotoViewerServices(
            imageLoader: imageLoader,
            exifService: exifService,
            photoLibrary: photoLibrary,
            savedDateStore: savedDateStore,
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
