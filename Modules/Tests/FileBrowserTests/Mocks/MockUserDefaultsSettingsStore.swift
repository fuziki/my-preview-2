import Core

/// UserDefaultsSettingsStoreProtocolのテスト用モック（インメモリ）
final class MockUserDefaultsSettingsStore: UserDefaultsSettingsStoreProtocol {
    var viewMode: ViewMode = .grid
    var saveFormat: SaveFormat = .jpeg
    var sortOrder: FileSortOrder = .dateAscending
    var gridColumnCount: Int = 3
    var isRatingEnabled: Bool = true
    var ratingFilter: RatingFilter?
    var colorLabelFilter: Set<PhotoColorLabel> = []
    var lastViewedFileName: String?
    var removeAllCallCount = 0

    /// UserDefaultsSettingsStore.removeAll()と同様、削除後は各プロパティがデフォルト値を返す
    func removeAll() {
        removeAllCallCount += 1
        viewMode = .grid
        saveFormat = .jpeg
        sortOrder = .dateAscending
        gridColumnCount = 3
        isRatingEnabled = true
        ratingFilter = nil
        colorLabelFilter = []
        lastViewedFileName = nil
    }
}
