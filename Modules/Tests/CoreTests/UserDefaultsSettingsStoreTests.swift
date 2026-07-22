import Testing
import Foundation
@testable import Core

@Suite
struct UserDefaultsSettingsStoreTests {

    // MARK: - デフォルト値（未保存時）

    @Test
    func viewMode_defaultsToGrid_whenUnset() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        #expect(store.viewMode == .grid)
    }

    @Test
    func saveFormat_defaultsToJpeg_whenUnset() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        #expect(store.saveFormat == .jpeg)
    }

    @Test
    func sortOrder_defaultsToDateAscending_whenUnset() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        #expect(store.sortOrder == .dateAscending)
    }

    @Test
    func gridColumnCount_defaultsToThree_whenUnset() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        #expect(store.gridColumnCount == 3)
    }

    @Test
    func isRatingEnabled_defaultsToTrue_whenUnset() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        #expect(store.isRatingEnabled == true)
    }

    @Test
    func ratingFilter_defaultsToNil_whenUnset() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        #expect(store.ratingFilter == nil)
    }

    @Test
    func colorLabelFilter_defaultsToEmpty_whenUnset() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        #expect(store.colorLabelFilter.isEmpty)
    }

    @Test
    func lastViewedFileName_defaultsToNil_whenUnset() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        #expect(store.lastViewedFileName == nil)
    }

    // MARK: - 永続化ラウンドトリップ

    @Test
    func saveFormat_persistsAcrossInstances() {
        let storage = FakeUserDefaultsStorage()
        UserDefaultsSettingsStore(storage: storage).saveFormat = .jpegAndRaw
        #expect(UserDefaultsSettingsStore(storage: storage).saveFormat == .jpegAndRaw)
    }

    @Test
    func viewMode_persistsAcrossInstances() {
        let storage = FakeUserDefaultsStorage()
        UserDefaultsSettingsStore(storage: storage).viewMode = .list
        #expect(UserDefaultsSettingsStore(storage: storage).viewMode == .list)
    }

    // MARK: - gridColumnCountのクランプ

    @Test
    func gridColumnCount_clampsBelowRange() {
        let storage = FakeUserDefaultsStorage()
        storage.set("1", forKey: AppStorageKey.gridColumnCount.rawValue)
        let store = UserDefaultsSettingsStore(storage: storage)
        #expect(store.gridColumnCount == UserDefaultsSettingsStore.gridColumnCountRange.lowerBound)
    }

    @Test
    func gridColumnCount_clampsAboveRange() {
        let storage = FakeUserDefaultsStorage()
        storage.set("10", forKey: AppStorageKey.gridColumnCount.rawValue)
        let store = UserDefaultsSettingsStore(storage: storage)
        #expect(store.gridColumnCount == UserDefaultsSettingsStore.gridColumnCountRange.upperBound)
    }

    @Test
    func gridColumnCount_defaultsToThree_forInvalidStoredValue() {
        let storage = FakeUserDefaultsStorage()
        storage.set("abc", forKey: AppStorageKey.gridColumnCount.rawValue)
        let store = UserDefaultsSettingsStore(storage: storage)
        #expect(store.gridColumnCount == 3)
    }

    // MARK: - removeAll

    @Test
    func removeAll_resetsAllPropertiesToDefaults() {
        let store = UserDefaultsSettingsStore(storage: FakeUserDefaultsStorage())
        store.viewMode = .list
        store.saveFormat = .jpegAndRaw
        store.gridColumnCount = 5
        store.isRatingEnabled = false
        store.ratingFilter = RatingFilter(stars: 3, comparison: .atLeast)
        store.colorLabelFilter = [.green]
        store.lastViewedFileName = "a.jpg"

        store.removeAll()

        #expect(store.viewMode == .grid)
        #expect(store.saveFormat == .jpeg)
        #expect(store.gridColumnCount == 3)
        #expect(store.isRatingEnabled == true)
        #expect(store.ratingFilter == nil)
        #expect(store.colorLabelFilter.isEmpty)
        #expect(store.lastViewedFileName == nil)
    }

    // MARK: - 不正な生値のフォールバック

    @Test
    func ratingFilter_ignoresInvalidStoredValue() {
        let storage = FakeUserDefaultsStorage()
        storage.set("garbage", forKey: AppStorageKey.ratingFilter.rawValue)
        let store = UserDefaultsSettingsStore(storage: storage)
        #expect(store.ratingFilter == nil)
    }

    @Test
    func colorLabelFilter_ignoresInvalidElements_inStoredValue() {
        let storage = FakeUserDefaultsStorage()
        storage.set("blue,unknown", forKey: AppStorageKey.colorLabelFilter.rawValue)
        let store = UserDefaultsSettingsStore(storage: storage)
        #expect(store.colorLabelFilter == [.blue])
    }

    @Test
    func colorLabelFilter_emptySelection_removesUnderlyingStorageValue() {
        let storage = FakeUserDefaultsStorage()
        let store = UserDefaultsSettingsStore(storage: storage)
        store.colorLabelFilter = [.green]
        store.colorLabelFilter = []
        #expect(storage.string(forKey: AppStorageKey.colorLabelFilter.rawValue) == nil)
    }
}
