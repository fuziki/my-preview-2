import Testing
import Foundation
@testable import Core

@Suite
struct UserDefaultsSettingsStoreTests {

    /// テストごとに独立したUserDefaultsスイートを生成する
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "UserDefaultsSettingsStoreTests.\(UUID().uuidString)")!
    }

    private func makeStore(defaults: UserDefaults) -> UserDefaultsSettingsStore<UserDefaultsSettings> {
        UserDefaultsSettingsStore(defaultValue: .default(), defaults: defaults)
    }

    // MARK: - デフォルト値（未保存時）

    @Test
    func viewMode_defaultsToGrid_whenUnset() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.viewMode == .grid)
    }

    @Test
    func saveFormat_defaultsToJpeg_whenUnset() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.saveFormat == .jpeg)
    }

    @Test
    func sortOrder_defaultsToDateAscending_whenUnset() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.sortOrder == .dateAscending)
    }

    @Test
    func gridColumnCount_defaultsToThree_whenUnset() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.gridColumnCount == 3)
    }

    @Test
    func isRatingEnabled_defaultsToTrue_whenUnset() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.isRatingEnabled == true)
    }

    @Test
    func ratingFilter_defaultsToNil_whenUnset() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.ratingFilter == nil)
    }

    @Test
    func colorLabelFilter_defaultsToEmpty_whenUnset() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.colorLabelFilter.isEmpty)
    }

    @Test
    func lastViewedFileName_defaultsToNil_whenUnset() {
        let store = makeStore(defaults: makeDefaults())
        #expect(store.lastViewedFileName == nil)
    }

    // MARK: - 永続化ラウンドトリップ

    @Test
    func saveFormat_persistsAcrossInstances() {
        let defaults = makeDefaults()
        makeStore(defaults: defaults).saveFormat = .jpegAndRaw
        #expect(makeStore(defaults: defaults).saveFormat == .jpegAndRaw)
    }

    @Test
    func viewMode_persistsAcrossInstances() {
        let defaults = makeDefaults()
        makeStore(defaults: defaults).viewMode = .list
        #expect(makeStore(defaults: defaults).viewMode == .list)
    }

    @Test
    func ratingFilter_persistsAcrossInstances() {
        let defaults = makeDefaults()
        let filter = RatingFilter(stars: 3, comparison: .atLeast)
        makeStore(defaults: defaults).ratingFilter = filter
        #expect(makeStore(defaults: defaults).ratingFilter == filter)
    }

    @Test
    func colorLabelFilter_persistsAcrossInstances() {
        let defaults = makeDefaults()
        makeStore(defaults: defaults).colorLabelFilter = [.green, .red]
        #expect(makeStore(defaults: defaults).colorLabelFilter == [.green, .red])
    }

    // MARK: - removeAll

    @Test
    func removeAll_resetsAllPropertiesToDefaults() {
        let store = makeStore(defaults: makeDefaults())
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
        defaults.set(Data([0xFF, 0x00]), forKey: "UserDefaultsSettingsStore.saveFormat")
        let store = makeStore(defaults: defaults)
        #expect(store.saveFormat == .jpeg)
    }

    // MARK: - storageKeysの網羅性

    /// Mirrorで実際のプロパティ名を列挙し、storageKeysの内容と一致するか検証する。
    /// プロパティの追加・削除・二重登録があるとこのテストが失敗する。
    @Test
    func storageKeys_namesMatchActualProperties() {
        let propertyNames = Set(Mirror(reflecting: UserDefaultsSettings.default()).children.compactMap(\.label))
        let keyPathNames = Set(UserDefaultsSettings.storageKeys.keys.map(Self.propertyName(of:)))
        #expect(keyPathNames == propertyNames)
    }

    /// 保存キー文字列が重複していない（コピペミスで2プロパティが同じキーを共有していない）ことを検証する
    @Test
    func storageKeys_valuesAreUnique() {
        let keys = UserDefaultsSettings.storageKeys.values
        #expect(Set(keys).count == keys.count)
    }

    /// KeyPathのdebug description（例: "\UserDefaultsSettings.viewMode"）末尾のプロパティ名を取り出す
    private static func propertyName(of keyPath: PartialKeyPath<UserDefaultsSettings>) -> String {
        let description = String(describing: keyPath)
        return description.split(separator: ".").last.map(String.init) ?? description
    }

    // MARK: - storageKeysに無いプロパティの自動生成フォールバック

    /// テスト専用: storageKeysの対応が一部欠けた設定型
    private struct IncompleteSettings: Codable, UserDefaultsStorableSettings {
        var known: String
        var unknown: String

        static func `default`() -> Self {
            Self(known: "known-default", unknown: "unknown-default")
        }

        static var storageKeys: [PartialKeyPath<IncompleteSettings>: String] {
            [\.known: "IncompleteSettings.known"]
        }
    }

    @Test
    func missingStorageKey_stillPersists_usingGeneratedKey() {
        let defaults = makeDefaults()
        let store = UserDefaultsSettingsStore(defaultValue: IncompleteSettings.default(), defaults: defaults)

        store.unknown = "updated"

        #expect(UserDefaultsSettingsStore(defaultValue: IncompleteSettings.default(), defaults: defaults).unknown == "updated")
    }
}
