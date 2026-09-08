import Testing
import Foundation
import Core
import MocksForTest
@testable import FileBrowser

// MARK: - テスト

struct FileBrowserBulkSaveViewModelTests {

    let url1 = URL(fileURLWithPath: "/tmp/photo1.jpg")
    let url2 = URL(fileURLWithPath: "/tmp/photo2.jpg")
    let url3 = URL(fileURLWithPath: "/tmp/photo3.jpg")

    let photoLibrary: MockPhotoLibraryService
    let savedDateStore: MockSavedDateStore
    let hapticsService: MockHapticsService

    init() {
        photoLibrary = MockPhotoLibraryService()
        savedDateStore = MockSavedDateStore()
        hapticsService = MockHapticsService()
    }

    /// 現在のモックを使ってViewModelを生成するヘルパー
    private func makeViewModel(
        urls: [URL],
        onURLSaved: @escaping (URL, Date) -> Void = { _, _ in }
    ) -> FileBrowserBulkSaveViewModel {
        FileBrowserBulkSaveViewModel(
            urls: urls,
            dependencies: FileBrowserBulkSaveDependencies(
                photoLibrary: photoLibrary,
                savedDateStore: savedDateStore,
                hapticsService: hapticsService
            ),
            onURLSaved: onURLSaved
        )
    }

    // MARK: - 初期状態

    @Test
    func init_totalCountEqualsURLsCount() {
        let viewModel = makeViewModel(urls: [url1, url2, url3])
        #expect(viewModel.totalCount == 3)
    }

    @Test
    func init_completedCountIsZero() {
        let viewModel = makeViewModel(urls: [url1, url2])
        #expect(viewModel.completedCount == 0)
    }

    // MARK: - 全件成功

    @Test
    func start_savesEachURLToPhotoLibrary() async {
        let viewModel = makeViewModel(urls: [url1, url2, url3])
        await viewModel.start()
        #expect(photoLibrary.saveCallCount == 3)
    }

    @Test
    func start_incrementsCompletedCountToTotal() async {
        let viewModel = makeViewModel(urls: [url1, url2, url3])
        await viewModel.start()
        #expect(viewModel.completedCount == 3)
    }

    @Test
    func start_setsSavedDateForEachURL() async {
        let viewModel = makeViewModel(urls: [url1, url2])
        await viewModel.start()
        #expect(savedDateStore.date(for: url1) != nil)
        #expect(savedDateStore.date(for: url2) != nil)
    }

    @Test
    func start_callsOnURLSavedForEachURL() async {
        var savedURLs: [URL] = []
        let viewModel = makeViewModel(urls: [url1, url2]) { url, _ in savedURLs.append(url) }
        await viewModel.start()
        #expect(savedURLs == [url1, url2])
    }

    @Test
    func start_callsOnURLSavedWithTheDatePersistedToTheStore() async {
        var receivedDate: Date?
        let viewModel = makeViewModel(urls: [url1]) { _, date in receivedDate = date }
        await viewModel.start()
        #expect(receivedDate != nil)
        #expect(receivedDate == savedDateStore.date(for: url1))
    }

    @Test
    func start_onAllSuccess_callsHapticsSuccessOnce() async {
        let viewModel = makeViewModel(urls: [url1, url2])
        await viewModel.start()
        #expect(hapticsService.notifySuccessCallCount == 1)
        #expect(hapticsService.notifyErrorCallCount == 0)
    }

    @Test
    func start_callsOnFinishedExactlyOnce() async {
        var finishedCount = 0
        let viewModel = makeViewModel(urls: [url1, url2])
        viewModel.onFinished = { finishedCount += 1 }
        await viewModel.start()
        #expect(finishedCount == 1)
    }

    // MARK: - 失敗時はその場で中断

    @Test
    func start_onFailure_stopsAtFailedItem() async {
        photoLibrary.shouldThrow = true
        let viewModel = makeViewModel(urls: [url1, url2, url3])
        await viewModel.start()
        #expect(viewModel.completedCount == 0)
    }

    @Test
    func start_onFailure_callsHapticsErrorOnceAndNotSuccess() async {
        photoLibrary.shouldThrow = true
        let viewModel = makeViewModel(urls: [url1, url2])
        await viewModel.start()
        #expect(hapticsService.notifyErrorCallCount == 1)
        #expect(hapticsService.notifySuccessCallCount == 0)
    }

    @Test
    func start_onFailure_doesNotSetSavedDate() async {
        photoLibrary.shouldThrow = true
        let viewModel = makeViewModel(urls: [url1])
        await viewModel.start()
        #expect(savedDateStore.date(for: url1) == nil)
    }

    // MARK: - 中断

    @Test
    func cancel_calledDuringOnURLSaved_stopsBeforeNextItem() async {
        var viewModel: FileBrowserBulkSaveViewModel!
        viewModel = makeViewModel(urls: [url1, url2, url3]) { url, _ in
            if url == url1 {
                viewModel.cancel()
            }
        }
        await viewModel.start()
        #expect(viewModel.completedCount == 1)
        #expect(photoLibrary.saveCallCount == 1)
    }

    @Test
    func cancel_doesNotTriggerHaptics() async {
        var viewModel: FileBrowserBulkSaveViewModel!
        viewModel = makeViewModel(urls: [url1, url2]) { _, _ in
            viewModel.cancel()
        }
        await viewModel.start()
        #expect(hapticsService.notifySuccessCallCount == 0)
        #expect(hapticsService.notifyErrorCallCount == 0)
    }

    @Test
    func cancel_stillCallsOnFinished() async {
        var viewModel: FileBrowserBulkSaveViewModel!
        var finished = false
        viewModel = makeViewModel(urls: [url1, url2]) { _, _ in
            viewModel.cancel()
        }
        viewModel.onFinished = { finished = true }
        await viewModel.start()
        #expect(finished)
    }
}
