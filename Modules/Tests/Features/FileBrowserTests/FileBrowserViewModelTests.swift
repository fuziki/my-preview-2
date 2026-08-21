import Testing
import Foundation
import Core
import MocksForTest
@testable import FileBrowser

// MARK: - テスト

struct FileBrowserViewModelTests {

    let fileSystemService: MockFileSystemService
    let settings: MockUserDefaultsSettingsStore
    let savedDateStore: MockSavedDateStore
    let ratingStore: MockPhotoRatingStore
    let colorLabelStore: MockColorLabelStore
    let thumbnailService: MockThumbnailService
    let viewModel: FileBrowserViewModel

    init() {
        fileSystemService = MockFileSystemService()
        settings = MockUserDefaultsSettingsStore()
        savedDateStore = MockSavedDateStore()
        ratingStore = MockPhotoRatingStore()
        colorLabelStore = MockColorLabelStore()
        thumbnailService = MockThumbnailService()
        viewModel = FileBrowserViewModel(dependencies: FileBrowserDependencies(
            fileSystemService: fileSystemService,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            settings: settings,
            thumbnailService: thumbnailService
        ))
    }

    /// 現在のモックを使ってDependenciesを組み立てるヘルパー
    private func makeDependencies() -> FileBrowserDependencies {
        FileBrowserDependencies(
            fileSystemService: fileSystemService,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            settings: settings,
            thumbnailService: thumbnailService
        )
    }

    /// 現在のモックを使ってViewModelを生成し直すヘルパー（設定復元のテストに使用）
    private func makeViewModel() -> FileBrowserViewModel {
        FileBrowserViewModel(dependencies: makeDependencies())
    }

    // MARK: - 初期状態

    @Test
    func initialState_defaultValues() {
        #expect(viewModel.items == [])
        #expect(viewModel.sections.isEmpty)
        #expect(viewModel.hasFolder == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.folderName == nil)
        #expect(viewModel.viewMode == .grid)
        #expect(viewModel.saveFormat == .jpeg)
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

        viewModel.saveLastViewed(url: itemURL)

        #expect(settings.lastViewedEntries == [
            DirectoryLastViewedEntry(directoryPath: "/tmp", fileName: itemURL.lastPathComponent),
        ])
    }

    @Test
    func saveLastViewed_lastViewedItem_returnsMatchingItem() async {
        let itemURL = URL(fileURLWithPath: "/tmp/photo.jpg")
        fileSystemService.stubbedItems = [FileItem(url: itemURL)]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp"))

        viewModel.saveLastViewed(url: itemURL)

        #expect(viewModel.lastViewedItem?.url == itemURL)
    }

    @Test
    func saveLastViewed_keepsSeparateEntry_perDirectory() async {
        let firstURL = URL(fileURLWithPath: "/tmp/a/photo.jpg")
        fileSystemService.stubbedItems = [FileItem(url: firstURL)]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp/a"))
        viewModel.saveLastViewed(url: firstURL)

        let secondURL = URL(fileURLWithPath: "/tmp/b/photo2.jpg")
        fileSystemService.stubbedItems = [FileItem(url: secondURL)]
        await viewModel.selectFolder(URL(fileURLWithPath: "/tmp/b"))
        viewModel.saveLastViewed(url: secondURL)

        #expect(settings.lastViewedEntries == [
            DirectoryLastViewedEntry(directoryPath: "/tmp/a", fileName: "photo.jpg"),
            DirectoryLastViewedEntry(directoryPath: "/tmp/b", fileName: "photo2.jpg"),
        ])
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

    // MARK: - UserDefaultsSettingsStore連携

    @Test
    func viewMode_persistsToStorage_onChange() {
        viewModel.viewMode = .list
        #expect(settings.viewMode == .list)
    }

    @Test
    func saveFormat_persistsToStorage_onChange() {
        viewModel.saveFormat = .jpegAndRaw
        #expect(settings.saveFormat == .jpegAndRaw)
    }

    @Test
    func init_restoresViewMode_fromStorage() {
        settings.viewMode = .list
        let vm = makeViewModel()
        #expect(vm.viewMode == .list)
    }

    @Test
    func init_restoresSaveFormat_fromStorage() {
        settings.saveFormat = .jpegAndRaw
        let vm = makeViewModel()
        #expect(vm.saveFormat == .jpegAndRaw)
    }

    @Test
    func init_defaultsToGridViewMode_whenStorageEmpty() {
        #expect(viewModel.viewMode == .grid)
    }

    @Test
    func init_defaultsToJpegSaveFormat_whenStorageEmpty() {
        #expect(viewModel.saveFormat == .jpeg)
    }

    // MARK: - グリッド列数

    @Test
    func init_defaultsToThreeColumns_whenStorageEmpty() {
        #expect(viewModel.gridColumnCount == 3)
    }

    @Test
    func gridColumnCount_persistsToStorage_onChange() {
        viewModel.gridColumnCount = 4
        #expect(settings.gridColumnCount == 4)
    }

    @Test
    func init_restoresGridColumnCount_fromStorage() {
        settings.gridColumnCount = 5
        let vm = makeViewModel()
        #expect(vm.gridColumnCount == 5)
    }

    @Test
    func init_clampsGridColumnCount_belowRange() {
        settings.gridColumnCount = 1
        let vm = makeViewModel()
        #expect(vm.gridColumnCount == FileBrowserViewModel.gridColumnCountRange.lowerBound)
    }

    @Test
    func init_clampsGridColumnCount_aboveRange() {
        settings.gridColumnCount = 10
        let vm = makeViewModel()
        #expect(vm.gridColumnCount == FileBrowserViewModel.gridColumnCountRange.upperBound)
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
    func resetToDefaults_reenablesRatingAndClearsFilter() {
        viewModel.isRatingEnabled = false
        viewModel.ratingFilter = RatingFilter(stars: 3, comparison: .atLeast)
        viewModel.resetToDefaults()
        #expect(viewModel.isRatingEnabled == true)
        #expect(viewModel.ratingFilter == nil)
    }

    @Test
    func resetToDefaults_clearsSavedFilter() {
        viewModel.savedFilter = .savedOnly
        viewModel.resetToDefaults()
        #expect(viewModel.savedFilter == nil)
    }

    // MARK: - レーティング

    @Test
    func init_defaultsToRatingEnabled_whenStorageEmpty() {
        #expect(viewModel.isRatingEnabled == true)
        #expect(viewModel.ratingFilter == nil)
    }

    @Test
    func isRatingEnabled_persistsToStorage_onChange() {
        viewModel.isRatingEnabled = false
        #expect(settings.isRatingEnabled == false)
    }

    @Test
    func init_restoresIsRatingEnabled_fromStorage() {
        settings.isRatingEnabled = false
        let vm = makeViewModel()
        #expect(vm.isRatingEnabled == false)
    }

    @Test
    func ratingFilter_persistsToStorage_onChange() {
        viewModel.ratingFilter = RatingFilter(stars: 3, comparison: .atLeast)
        #expect(settings.ratingFilter == RatingFilter(stars: 3, comparison: .atLeast))
    }

    @Test
    func init_restoresRatingFilter_fromStorage() {
        settings.ratingFilter = RatingFilter(stars: 2, comparison: .exactly)
        let vm = makeViewModel()
        #expect(vm.ratingFilter == RatingFilter(stars: 2, comparison: .exactly))
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
        #expect(settings.colorLabelFilter == [.green, .red])
    }

    @Test
    func colorLabelFilter_emptySelection_removesStorageValue() {
        viewModel.colorLabelFilter = [.green]
        viewModel.colorLabelFilter = []
        #expect(settings.colorLabelFilter.isEmpty)
    }

    @Test
    func init_restoresColorLabelFilter_fromStorage() {
        settings.colorLabelFilter = [.blue, .white]
        let vm = makeViewModel()
        #expect(vm.colorLabelFilter == [.blue, .white])
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

    // MARK: - 保存状態フィルター

    @Test
    func savedFilter_persistsToStorage_onChange() {
        viewModel.savedFilter = .savedOnly
        #expect(settings.savedFilter == .savedOnly)
    }

    @Test
    func init_restoresSavedFilter_fromStorage() {
        settings.savedFilter = .unsavedOnly
        let vm = makeViewModel()
        #expect(vm.savedFilter == .unsavedOnly)
    }

    @Test
    func savedFilter_savedOnly_filtersItems() async {
        let (rated3, rated1, unrated) = await loadRatedItems()
        savedDateStore.setDate(Date(), for: rated3)
        viewModel.isRatingEnabled = true
        viewModel.refreshRatingsAndLabels()

        viewModel.savedFilter = .savedOnly
        #expect(viewModel.items.map(\.url) == [rated3])
        #expect(viewModel.items.map(\.url).contains(rated1) == false)
        #expect(viewModel.items.map(\.url).contains(unrated) == false)
    }

    @Test
    func savedFilter_unsavedOnly_filtersItems() async {
        let (rated3, rated1, unrated) = await loadRatedItems()
        savedDateStore.setDate(Date(), for: rated3)
        viewModel.isRatingEnabled = true
        viewModel.refreshRatingsAndLabels()

        viewModel.savedFilter = .unsavedOnly
        #expect(viewModel.items.map(\.url) == [rated1, unrated])
    }

    @Test
    func savedFilter_notApplied_whenRatingDisabled() async {
        let (rated3, _, _) = await loadRatedItems()
        savedDateStore.setDate(Date(), for: rated3)
        viewModel.isRatingEnabled = false
        viewModel.refreshRatingsAndLabels()
        viewModel.savedFilter = .savedOnly
        #expect(viewModel.items.count == 3)
    }

    @Test
    func savedFilter_nil_showsAllItems() async {
        let (rated3, _, _) = await loadRatedItems()
        savedDateStore.setDate(Date(), for: rated3)
        viewModel.isRatingEnabled = true
        viewModel.refreshRatingsAndLabels()
        viewModel.savedFilter = nil
        #expect(viewModel.items.count == 3)
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

}

// MARK: - SavedFilterテスト

struct SavedFilterTests {

    @Test
    func matches_savedOnly() {
        #expect(SavedFilter.savedOnly.matches(savedDate: Date()) == true)
        #expect(SavedFilter.savedOnly.matches(savedDate: nil) == false)
    }

    @Test
    func matches_unsavedOnly() {
        #expect(SavedFilter.unsavedOnly.matches(savedDate: nil) == true)
        #expect(SavedFilter.unsavedOnly.matches(savedDate: Date()) == false)
    }

}
