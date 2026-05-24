import Testing
import Foundation
import Core
@testable import FileBrowser

// MARK: - テスト

@Suite
@MainActor
struct FileBrowserViewModelTests {

    let fileSystemService: MockFileSystemService
    let storage: MockUserDefaultsStorage
    let viewModel: FileBrowserViewModel

    init() {
        fileSystemService = MockFileSystemService()
        storage = MockUserDefaultsStorage()
        viewModel = FileBrowserViewModel(fileSystemService: fileSystemService, storage: storage)
    }

    // MARK: - 初期状態

    @Test
    func initialState_defaultValues() {
        #expect(viewModel.items == [])
        #expect(viewModel.sections.isEmpty)
        #expect(viewModel.hasFolder == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.folderName == nil)
        #expect(viewModel.viewMode == .list)
        #expect(viewModel.saveFormat == .jpegAndRaw)
        #expect(viewModel.lastViewedItemID == nil)
    }

    // MARK: - selectFolder

    @Test
    func selectFolder_setsHasFolderTrue() async {
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(viewModel.hasFolder == true)
    }

    @Test
    func selectFolder_setsFolderName() async {
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp/Photos"))
        #expect(viewModel.folderName == "Photos")
    }

    @Test
    func selectFolder_loadsReturnedItems() async {
        let expectedItems = [FileItem(url: URL(fileURLWithPath: "/tmp/a.jpg"), captureDate: Date())]
        fileSystemService.stubbedItems = expectedItems
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(viewModel.items == expectedItems)
    }

    @Test
    func selectFolder_callsFileSystemService() async {
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(fileSystemService.scanCallCount == 1)
    }

    @Test
    func selectFolder_isLoadingFalseAfterCompletion() async {
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(viewModel.isLoading == false)
    }

    // MARK: - saveLastViewed

    @Test
    func saveLastViewed_updatesLastViewedItemID() async {
        let itemURL = URL(fileURLWithPath: "/tmp/photo.jpg")
        let item = FileItem(url: itemURL)
        fileSystemService.stubbedItems = [item]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))

        viewModel.saveLastViewed(url: itemURL)

        #expect(viewModel.lastViewedItemID == item.id)
    }

    @Test
    func saveLastViewed_persistsToStorage() async {
        let itemURL = URL(fileURLWithPath: "/tmp/photo.jpg")
        fileSystemService.stubbedItems = [FileItem(url: itemURL)]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))

        let countBefore = storage.setCallCount
        viewModel.saveLastViewed(url: itemURL)

        #expect(storage.setCallCount > countBefore)
    }

    @Test
    func saveLastViewed_lastViewedItem_returnsMatchingItem() async {
        let itemURL = URL(fileURLWithPath: "/tmp/photo.jpg")
        fileSystemService.stubbedItems = [FileItem(url: itemURL)]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))

        viewModel.saveLastViewed(url: itemURL)

        #expect(viewModel.lastViewedItem?.url == itemURL)
    }

    // MARK: - consumeHasFolderChanged

    @Test
    func consumeHasFolderChanged_returnsFalse_initially() {
        #expect(viewModel.consumeHasFolderChanged() == false)
    }

    @Test
    func consumeHasFolderChanged_returnsTrue_afterFolderSelected() async {
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(viewModel.consumeHasFolderChanged() == true)
    }

    @Test
    func consumeHasFolderChanged_returnsFalse_afterAlreadyConsumed() async {
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        _ = viewModel.consumeHasFolderChanged() // 1回目で消費
        #expect(viewModel.consumeHasFolderChanged() == false)
    }

    // MARK: - sectionTitle

    @Test
    func sectionTitle_returnsNonEmptyString_forValidDate() {
        #expect(viewModel.sectionTitle(for: .init(dateKey: "2024-01-15")).isEmpty == false)
    }

    @Test
    func sectionTitle_containsYear_forValidDate() {
        #expect(viewModel.sectionTitle(for: .init(dateKey: "2024-01-15")).contains("2024"))
    }

    @Test
    func sectionTitle_returnsInputKey_forInvalidDate() {
        let invalidKey = "invalid-date"
        #expect(viewModel.sectionTitle(for: .init(dateKey: invalidKey)) == invalidKey)
    }

    // MARK: - updateSections（selectFolder経由で間接テスト）

    @Test
    func selectFolder_updatesSections_singleDate() async {
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10))!
        fileSystemService.stubbedItems = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a.jpg"), captureDate: date),
            FileItem(url: URL(fileURLWithPath: "/tmp/b.jpg"), captureDate: date),
        ]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(viewModel.sections.count == 1)
    }

    @Test
    func selectFolder_updatesSections_multipleDates() async {
        let date1 = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10))!
        let date2 = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 11))!
        fileSystemService.stubbedItems = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a.jpg"), captureDate: date1),
            FileItem(url: URL(fileURLWithPath: "/tmp/b.jpg"), captureDate: date2),
        ]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(viewModel.sections.count == 2)
    }

    @Test
    func selectFolder_sectionItems_countMatchesItems() async throws {
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10))!
        fileSystemService.stubbedItems = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a.jpg"), captureDate: date),
            FileItem(url: URL(fileURLWithPath: "/tmp/b.jpg"), captureDate: date),
        ]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))

        let section = try #require(viewModel.sections.first)
        #expect(section.items.count == 2)
    }

    // MARK: - makeMenuData

    @Test
    func makeMenuData_showsLastViewed_whenLastViewedItemExists() async {
        let itemURL = URL(fileURLWithPath: "/tmp/photo.jpg")
        fileSystemService.stubbedItems = [FileItem(url: itemURL)]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        viewModel.saveLastViewed(url: itemURL)

        #expect(viewModel.makeMenuData().showsLastViewed == true)
    }

    @Test
    func makeMenuData_doesNotShowLastViewed_whenNoLastViewed() {
        #expect(viewModel.makeMenuData().showsLastViewed == false)
    }

    @Test
    func makeMenuData_sectionsCount_matchesSections() async {
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10))!
        fileSystemService.stubbedItems = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a.jpg"), captureDate: date),
        ]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))

        let data = viewModel.makeMenuData()
        #expect(data.sections.count == viewModel.sections.count)
    }

    @Test
    func makeMenuData_sectionTitle_containsItemCount() async {
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10))!
        fileSystemService.stubbedItems = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a.jpg"), captureDate: date),
            FileItem(url: URL(fileURLWithPath: "/tmp/b.jpg"), captureDate: date),
        ]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))

        // タイトルには "2枚" が含まれるはず
        #expect(viewModel.makeMenuData().sections[0].title.contains("2"))
    }

    // MARK: - UserDefaults連携

    @Test
    func viewMode_persistsToStorage_onChange() {
        viewModel.viewMode = .grid
        #expect(storage.string(forKey: AppStorageKey.viewMode.rawValue) == ViewMode.grid.rawValue)
    }

    @Test
    func saveFormat_persistsToStorage_onChange() {
        viewModel.saveFormat = .jpeg
        #expect(storage.string(forKey: AppStorageKey.saveFormat.rawValue) == SaveFormat.jpeg.rawValue)
    }

    @Test
    func init_restoresViewMode_fromStorage() {
        storage.set(ViewMode.grid.rawValue, forKey: AppStorageKey.viewMode.rawValue)
        let vm = FileBrowserViewModel(fileSystemService: fileSystemService, storage: storage)
        #expect(vm.viewMode == .grid)
    }

    @Test
    func init_restoresSaveFormat_fromStorage() {
        storage.set(SaveFormat.jpeg.rawValue, forKey: AppStorageKey.saveFormat.rawValue)
        let vm = FileBrowserViewModel(fileSystemService: fileSystemService, storage: storage)
        #expect(vm.saveFormat == .jpeg)
    }

    @Test
    func init_defaultsToListViewMode_whenStorageEmpty() {
        #expect(viewModel.viewMode == .list)
    }

    @Test
    func init_defaultsToJpegAndRawSaveFormat_whenStorageEmpty() {
        #expect(viewModel.saveFormat == .jpegAndRaw)
    }
}
