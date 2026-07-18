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
    let savedDateStore: MockSavedDateStore
    let ratingStore: MockPhotoRatingStore
    let colorLabelStore: MockColorLabelStore
    let viewModel: FileBrowserViewModel

    init() {
        fileSystemService = MockFileSystemService()
        storage = MockUserDefaultsStorage()
        savedDateStore = MockSavedDateStore()
        ratingStore = MockPhotoRatingStore()
        colorLabelStore = MockColorLabelStore()
        viewModel = FileBrowserViewModel(
            fileSystemService: fileSystemService,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            storage: storage
        )
    }

    /// 現在のモックを使ってViewModelを生成し直すヘルパー（ストレージ復元のテストに使用）
    private func makeViewModel() -> FileBrowserViewModel {
        FileBrowserViewModel(
            fileSystemService: fileSystemService,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            storage: storage
        )
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
        let vm = makeViewModel()
        #expect(vm.viewMode == .grid)
    }

    @Test
    func init_restoresSaveFormat_fromStorage() {
        storage.set(SaveFormat.jpeg.rawValue, forKey: AppStorageKey.saveFormat.rawValue)
        let vm = makeViewModel()
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

    // MARK: - グリッド列数

    @Test
    func init_defaultsToThreeColumns_whenStorageEmpty() {
        #expect(viewModel.gridColumnCount == 3)
    }

    @Test
    func gridColumnCount_persistsToStorage_onChange() {
        viewModel.gridColumnCount = 4
        #expect(storage.string(forKey: AppStorageKey.gridColumnCount.rawValue) == "4")
    }

    @Test
    func init_restoresGridColumnCount_fromStorage() {
        storage.set("5", forKey: AppStorageKey.gridColumnCount.rawValue)
        let vm = makeViewModel()
        #expect(vm.gridColumnCount == 5)
    }

    @Test
    func init_clampsGridColumnCount_belowRange() {
        storage.set("1", forKey: AppStorageKey.gridColumnCount.rawValue)
        let vm = makeViewModel()
        #expect(vm.gridColumnCount == 2)
    }

    @Test
    func init_clampsGridColumnCount_aboveRange() {
        storage.set("10", forKey: AppStorageKey.gridColumnCount.rawValue)
        let vm = makeViewModel()
        #expect(vm.gridColumnCount == 5)
    }

    @Test
    func init_defaultsToThreeColumns_forInvalidStoredValue() {
        storage.set("abc", forKey: AppStorageKey.gridColumnCount.rawValue)
        let vm = makeViewModel()
        #expect(vm.gridColumnCount == 3)
    }

    // MARK: - resetToDefaults

    @Test
    func resetToDefaults_clearsSavedDateStore() {
        savedDateStore.setDate(Date(), for: URL(fileURLWithPath: "/tmp/a.jpg"))
        viewModel.resetToDefaults()
        #expect(savedDateStore.removeAllCallCount == 1)
        #expect(savedDateStore.dates.isEmpty)
    }

    @Test
    func resetToDefaults_clearsRatingStore() {
        ratingStore.setRating(3, for: URL(fileURLWithPath: "/tmp/a.jpg"))
        viewModel.resetToDefaults()
        #expect(ratingStore.removeAllCallCount == 1)
        #expect(ratingStore.ratings.isEmpty)
    }

    @Test
    func resetToDefaults_disablesRatingAndClearsFilter() {
        viewModel.isRatingEnabled = true
        viewModel.ratingFilter = RatingFilter(stars: 3, comparison: .atLeast)
        viewModel.resetToDefaults()
        #expect(viewModel.isRatingEnabled == false)
        #expect(viewModel.ratingFilter == nil)
    }

    // MARK: - レーティング

    @Test
    func init_defaultsToRatingDisabled_whenStorageEmpty() {
        #expect(viewModel.isRatingEnabled == false)
        #expect(viewModel.ratingFilter == nil)
    }

    @Test
    func isRatingEnabled_persistsToStorage_onChange() {
        viewModel.isRatingEnabled = true
        #expect(storage.string(forKey: AppStorageKey.isRatingEnabled.rawValue) == "true")
    }

    @Test
    func init_restoresIsRatingEnabled_fromStorage() {
        storage.set("true", forKey: AppStorageKey.isRatingEnabled.rawValue)
        let vm = makeViewModel()
        #expect(vm.isRatingEnabled == true)
    }

    @Test
    func ratingFilter_persistsToStorage_onChange() {
        viewModel.ratingFilter = RatingFilter(stars: 3, comparison: .atLeast)
        #expect(storage.string(forKey: AppStorageKey.ratingFilter.rawValue) == "atLeast:3")
    }

    @Test
    func init_restoresRatingFilter_fromStorage() {
        storage.set("exactly:2", forKey: AppStorageKey.ratingFilter.rawValue)
        let vm = makeViewModel()
        #expect(vm.ratingFilter == RatingFilter(stars: 2, comparison: .exactly))
    }

    @Test
    func init_ignoresInvalidRatingFilter_fromStorage() {
        storage.set("garbage", forKey: AppStorageKey.ratingFilter.rawValue)
        let vm = makeViewModel()
        #expect(vm.ratingFilter == nil)
    }

    @Test
    func rating_returnsStoredRating_afterFolderLoad() async {
        let itemURL = URL(fileURLWithPath: "/tmp/a.jpg")
        ratingStore.setRating(4, for: itemURL)
        fileSystemService.stubbedItems = [FileItem(url: itemURL)]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(viewModel.rating(for: itemURL) == 4)
    }

    // MARK: - レーティングフィルター適用

    /// 星3・星1・星0の3枚を読み込むヘルパー
    private func loadRatedItems() async -> (rated3: URL, rated1: URL, unrated: URL) {
        let rated3 = URL(fileURLWithPath: "/tmp/a.jpg")
        let rated1 = URL(fileURLWithPath: "/tmp/b.jpg")
        let unrated = URL(fileURLWithPath: "/tmp/c.jpg")
        ratingStore.setRating(3, for: rated3)
        ratingStore.setRating(1, for: rated1)
        // ソート順を決定的にするため撮影時刻をずらす（同日内で昇順）
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 10))!
        fileSystemService.stubbedItems = [
            FileItem(url: rated3, captureDate: date),
            FileItem(url: rated1, captureDate: date.addingTimeInterval(60)),
            FileItem(url: unrated, captureDate: date.addingTimeInterval(120)),
        ]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        return (rated3, rated1, unrated)
    }

    @Test
    func ratingFilter_atLeast_filtersItems() async {
        let (rated3, _, _) = await loadRatedItems()
        viewModel.isRatingEnabled = true
        viewModel.ratingFilter = RatingFilter(stars: 2, comparison: .atLeast)
        #expect(viewModel.items.map(\.url) == [rated3])
    }

    @Test
    func ratingFilter_atMost_filtersItems() async {
        let (_, rated1, unrated) = await loadRatedItems()
        viewModel.isRatingEnabled = true
        viewModel.ratingFilter = RatingFilter(stars: 1, comparison: .atMost)
        #expect(viewModel.items.map(\.url) == [rated1, unrated])
    }

    @Test
    func ratingFilter_exactly_filtersItems() async {
        let (_, _, unrated) = await loadRatedItems()
        viewModel.isRatingEnabled = true
        viewModel.ratingFilter = RatingFilter(stars: 0, comparison: .exactly)
        #expect(viewModel.items.map(\.url) == [unrated])
    }

    @Test
    func ratingFilter_notApplied_whenRatingDisabled() async {
        _ = await loadRatedItems()
        viewModel.isRatingEnabled = false
        viewModel.ratingFilter = RatingFilter(stars: 5, comparison: .exactly)
        #expect(viewModel.items.count == 3)
    }

    @Test
    func ratingFilter_nil_showsAllItems() async {
        _ = await loadRatedItems()
        viewModel.isRatingEnabled = true
        viewModel.ratingFilter = nil
        #expect(viewModel.items.count == 3)
    }

    @Test
    func refreshRatingsAndLabels_reflectsStoreChanges() async {
        let (rated3, rated1, _) = await loadRatedItems()
        viewModel.isRatingEnabled = true
        viewModel.ratingFilter = RatingFilter(stars: 2, comparison: .atLeast)
        #expect(viewModel.items.map(\.url) == [rated3])

        // ビューアー側での変更を想定してストアを直接更新する
        ratingStore.setRating(5, for: rated1)
        viewModel.refreshRatingsAndLabels()
        #expect(viewModel.items.map(\.url) == [rated3, rated1])
    }

    // MARK: - カラーラベルフィルター

    @Test
    func colorLabelFilter_persistsToStorage_onChange() {
        viewModel.colorLabelFilter = [.green, .red]
        #expect(storage.string(forKey: AppStorageKey.colorLabelFilter.rawValue) == "green,red")
    }

    @Test
    func colorLabelFilter_emptySelection_removesStorageValue() {
        viewModel.colorLabelFilter = [.green]
        viewModel.colorLabelFilter = []
        #expect(storage.string(forKey: AppStorageKey.colorLabelFilter.rawValue) == nil)
    }

    @Test
    func init_restoresColorLabelFilter_fromStorage() {
        storage.set("blue,white", forKey: AppStorageKey.colorLabelFilter.rawValue)
        let vm = makeViewModel()
        #expect(vm.colorLabelFilter == [.blue, .white])
    }

    @Test
    func init_ignoresInvalidColorLabelFilter_fromStorage() {
        storage.set("blue,unknown", forKey: AppStorageKey.colorLabelFilter.rawValue)
        let vm = makeViewModel()
        #expect(vm.colorLabelFilter == [.blue])
    }

    @Test
    func colorLabel_returnsStoredLabel_afterFolderLoad() async {
        let itemURL = URL(fileURLWithPath: "/tmp/a.jpg")
        colorLabelStore.setLabel(.pink, for: itemURL)
        fileSystemService.stubbedItems = [FileItem(url: itemURL)]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))
        #expect(viewModel.colorLabel(for: itemURL) == .pink)
    }

    @Test
    func colorLabelFilter_filtersItems() async {
        let (rated3, rated1, unrated) = await loadRatedItems()
        colorLabelStore.setLabel(.green, for: rated3)
        colorLabelStore.setLabel(.red, for: rated1)
        viewModel.isRatingEnabled = true
        viewModel.refreshRatingsAndLabels()

        viewModel.colorLabelFilter = [.green]
        #expect(viewModel.items.map(\.url) == [rated3])

        viewModel.colorLabelFilter = [.green, .red]
        #expect(viewModel.items.map(\.url) == [rated3, rated1])

        // ラベル未設定の写真は非空フィルタに適合しない
        #expect(viewModel.items.map(\.url).contains(unrated) == false)
    }

    @Test
    func colorLabelFilter_emptySelection_showsAllItems() async {
        let (rated3, _, _) = await loadRatedItems()
        colorLabelStore.setLabel(.green, for: rated3)
        viewModel.isRatingEnabled = true
        viewModel.refreshRatingsAndLabels()
        viewModel.colorLabelFilter = []
        #expect(viewModel.items.count == 3)
    }

    @Test
    func colorLabelFilter_notApplied_whenRatingDisabled() async {
        let (rated3, _, _) = await loadRatedItems()
        colorLabelStore.setLabel(.green, for: rated3)
        viewModel.isRatingEnabled = false
        viewModel.refreshRatingsAndLabels()
        viewModel.colorLabelFilter = [.blue]
        #expect(viewModel.items.count == 3)
    }

    @Test
    func combinedFilter_requiresBothRatingAndColorMatch() async {
        // rated3は星3、rated1は星1。rated3とrated1に緑ラベルを付ける
        let (rated3, rated1, _) = await loadRatedItems()
        colorLabelStore.setLabel(.green, for: rated3)
        colorLabelStore.setLabel(.green, for: rated1)
        viewModel.isRatingEnabled = true
        viewModel.refreshRatingsAndLabels()

        // 星2以上 かつ 緑 → rated3のみ
        viewModel.ratingFilter = RatingFilter(stars: 2, comparison: .atLeast)
        viewModel.colorLabelFilter = [.green]
        #expect(viewModel.items.map(\.url) == [rated3])
    }

    @Test
    func resetToDefaults_clearsColorLabelStoreAndFilter() {
        colorLabelStore.setLabel(.green, for: URL(fileURLWithPath: "/tmp/a.jpg"))
        viewModel.colorLabelFilter = [.green]
        viewModel.resetToDefaults()
        #expect(colorLabelStore.removeAllCallCount == 1)
        #expect(colorLabelStore.labels.isEmpty)
        #expect(viewModel.colorLabelFilter.isEmpty)
    }
}

// MARK: - PhotoColorLabelテスト

@Suite
struct PhotoColorLabelTests {

    @Test
    func filterRawValue_roundTrips() {
        let selection: Set<PhotoColorLabel> = [.yellow, .white, .green]
        #expect(Set(colorLabelFilterRawValue: selection.colorLabelFilterRawValue) == selection)
    }

    @Test
    func filterRawValue_usesCanonicalOrder() {
        let selection: Set<PhotoColorLabel> = [.white, .green]
        #expect(selection.colorLabelFilterRawValue == "green,white")
    }

    @Test
    func initWithFilterRawValue_ignoresInvalidElements() {
        #expect(Set(colorLabelFilterRawValue: "") == Set<PhotoColorLabel>())
        #expect(Set(colorLabelFilterRawValue: "green,bogus") == Set<PhotoColorLabel>([.green]))
    }
}

// MARK: - RatingFilterテスト

@Suite
struct RatingFilterTests {

    @Test
    func matches_atLeast() {
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        #expect(filter.matches(3) == true)
        #expect(filter.matches(5) == true)
        #expect(filter.matches(2) == false)
    }

    @Test
    func matches_atMost() {
        let filter = RatingFilter(stars: 3, comparison: .atMost)
        #expect(filter.matches(3) == true)
        #expect(filter.matches(0) == true)
        #expect(filter.matches(4) == false)
    }

    @Test
    func matches_exactly() {
        let filter = RatingFilter(stars: 3, comparison: .exactly)
        #expect(filter.matches(3) == true)
        #expect(filter.matches(2) == false)
        #expect(filter.matches(4) == false)
    }

    @Test
    func rawValue_roundTrips() {
        let filter = RatingFilter(stars: 4, comparison: .atMost)
        #expect(RatingFilter(rawValue: filter.rawValue) == filter)
    }

    @Test
    func initWithRawValue_rejectsInvalidStrings() {
        #expect(RatingFilter(rawValue: "") == nil)
        #expect(RatingFilter(rawValue: "atLeast") == nil)
        #expect(RatingFilter(rawValue: "atLeast:9") == nil)
        #expect(RatingFilter(rawValue: "unknown:3") == nil)
    }
}
