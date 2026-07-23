import Testing
import Foundation
@testable import Core

@Suite
struct UserDefaultsSettingsStoreTests {

    /// テストごとに独立したUserDefaultsスイートを生成する
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "UserDefaultsSettingsStoreTests.\(UUID().uuidString)")!
    }

    // MARK: - デフォルト値（未保存時）

    @Test
    func viewMode_defaultsToGrid_whenUnset() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        #expect(store.viewMode == .grid)
    }

    @Test
    func saveFormat_defaultsToJpeg_whenUnset() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        #expect(store.saveFormat == .jpeg)
    }

    @Test
    func sortOrder_defaultsToDateAscending_whenUnset() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        #expect(store.sortOrder == .dateAscending)
    }

    @Test
    func gridColumnCount_defaultsToThree_whenUnset() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        #expect(store.gridColumnCount == 3)
    }

    @Test
    func isRatingEnabled_defaultsToTrue_whenUnset() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        #expect(store.isRatingEnabled == true)
    }

    @Test
    func ratingFilter_defaultsToNil_whenUnset() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        #expect(store.ratingFilter == nil)
    }

    @Test
    func colorLabelFilter_defaultsToEmpty_whenUnset() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        #expect(store.colorLabelFilter.isEmpty)
    }

    @Test
    func lastViewedFileName_defaultsToNil_whenUnset() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
        #expect(store.lastViewedFileName == nil)
    }

    // MARK: - 永続化ラウンドトリップ

    @Test
    func saveFormat_persistsAcrossInstances() {
        let defaults = makeDefaults()
        UserDefaultsSettingsStore(defaults: defaults).saveFormat = .jpegAndRaw
        #expect(UserDefaultsSettingsStore(defaults: defaults).saveFormat == .jpegAndRaw)
    }

    @Test
    func viewMode_persistsAcrossInstances() {
        let defaults = makeDefaults()
        UserDefaultsSettingsStore(defaults: defaults).viewMode = .list
        #expect(UserDefaultsSettingsStore(defaults: defaults).viewMode == .list)
    }

    @Test
    func ratingFilter_persistsAcrossInstances() {
        let defaults = makeDefaults()
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        UserDefaultsSettingsStore(defaults: defaults).ratingFilter = filter
        #expect(UserDefaultsSettingsStore(defaults: defaults).ratingFilter == filter)
    }

    @Test
    func colorLabelFilter_persistsAcrossInstances() {
        let defaults = makeDefaults()
        UserDefaultsSettingsStore(defaults: defaults).colorLabelFilter = [.green, .red]
        #expect(UserDefaultsSettingsStore(defaults: defaults).colorLabelFilter == [.green, .red])
    }

    // MARK: - removeAll

    @Test
    func removeAll_resetsAllPropertiesToDefaults() {
        let store = UserDefaultsSettingsStore(defaults: makeDefaults())
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

    // MARK: - 不正な生データのフォールバック

    @Test
    func decodeFailure_fallsBackToDefault() {
        let defaults = makeDefaults()
        defaults.set(Data([0xFF, 0x00]), forKey: "saveFormat")
        let store = UserDefaultsSettingsStore(defaults: defaults)
        #expect(store.saveFormat == .jpeg)
    }

    // MARK: - allKeyPathsの網羅性

    /// Mirrorで実際のプロパティ名を列挙し、allKeyPathsの内容と一致するか検証する。
    /// プロパティの追加・削除・二重登録があるとこのテストが失敗する。
    @Test
    func allKeyPaths_namesMatchActualProperties() {
        let propertyNames = Set(Mirror(reflecting: UserDefaultsSettings.default()).children.compactMap(\.label))
        let keyPathNames = Set(UserDefaultsSettings.allKeyPathsForTest.map(Self.propertyName(of:)))
        #expect(keyPathNames == propertyNames)
    }

    /// KeyPathのdebug description（例: "\UserDefaultsSettings.viewMode"）末尾のプロパティ名を取り出す
    private static func propertyName(of keyPath: PartialKeyPath<UserDefaultsSettings>) -> String {
        let description = String(describing: keyPath)
        return description.split(separator: ".").last.map(String.init) ?? description
    }
}
