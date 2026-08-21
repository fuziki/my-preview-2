import Testing
import Foundation
import Core
@testable import FileBrowser

struct FileBrowserFilterViewModelTests {

    private func makeViewModel(
        ratingFilter: RatingFilter? = nil,
        colorLabelFilter: Set<PhotoColorLabel> = [],
        savedFilter: SavedFilter? = nil,
        onChange: @escaping (RatingFilter?, Set<PhotoColorLabel>, SavedFilter?) -> Void = { _, _, _ in }
    ) -> FileBrowserFilterViewModel {
        FileBrowserFilterViewModel(
            ratingFilter: ratingFilter,
            colorLabelFilter: colorLabelFilter,
            savedFilter: savedFilter,
            onChange: onChange
        )
    }

    @Test
    func init_setsInitialValues() {
        let ratingFilter = RatingFilter(stars: 3, comparison: .atLeast)
        let viewModel = makeViewModel(ratingFilter: ratingFilter, colorLabelFilter: [.red], savedFilter: .savedOnly)

        #expect(viewModel.ratingFilter == ratingFilter)
        #expect(viewModel.colorLabelFilter == [.red])
        #expect(viewModel.savedFilter == .savedOnly)
    }

    @Test
    func setRatingFilter_notifiesOnChange_withCurrentColorLabelFilterAndSavedFilter() {
        var changes: [(RatingFilter?, Set<PhotoColorLabel>, SavedFilter?)] = []
        let viewModel = makeViewModel(
            colorLabelFilter: [.green],
            savedFilter: .unsavedOnly,
            onChange: { changes.append(($0, $1, $2)) }
        )

        let newFilter = RatingFilter(stars: 4, comparison: .exactly)
        viewModel.ratingFilter = newFilter

        #expect(changes.count == 1)
        #expect(changes[0].0 == newFilter)
        #expect(changes[0].1 == [.green])
        #expect(changes[0].2 == .unsavedOnly)
    }

    @Test
    func setColorLabelFilter_notifiesOnChange_withCurrentRatingFilterAndSavedFilter() {
        var changes: [(RatingFilter?, Set<PhotoColorLabel>, SavedFilter?)] = []
        let ratingFilter = RatingFilter(stars: 2, comparison: .atLeast)
        let viewModel = makeViewModel(ratingFilter: ratingFilter, onChange: { changes.append(($0, $1, $2)) })

        viewModel.colorLabelFilter = [.blue, .yellow]

        #expect(changes.count == 1)
        #expect(changes[0].0 == ratingFilter)
        #expect(changes[0].1 == [.blue, .yellow])
        #expect(changes[0].2 == nil)
    }

    @Test
    func setSavedFilter_notifiesOnChange_withCurrentRatingFilterAndColorLabelFilter() {
        var changes: [(RatingFilter?, Set<PhotoColorLabel>, SavedFilter?)] = []
        let ratingFilter = RatingFilter(stars: 2, comparison: .atLeast)
        let viewModel = makeViewModel(
            ratingFilter: ratingFilter,
            colorLabelFilter: [.pink],
            onChange: { changes.append(($0, $1, $2)) }
        )

        viewModel.savedFilter = .savedOnly

        #expect(changes.count == 1)
        #expect(changes[0].0 == ratingFilter)
        #expect(changes[0].1 == [.pink])
        #expect(changes[0].2 == .savedOnly)
    }

    @Test
    func clearFilters_resetsRatingFilterAndColorLabelFilterAndSavedFilter() {
        let viewModel = makeViewModel(
            ratingFilter: RatingFilter(stars: 3, comparison: .atLeast),
            colorLabelFilter: [.red, .green],
            savedFilter: .savedOnly
        )

        viewModel.clearFilters()

        #expect(viewModel.ratingFilter == nil)
        #expect(viewModel.colorLabelFilter.isEmpty)
        #expect(viewModel.savedFilter == nil)
    }

    @Test
    func clearFilters_notifiesOnChange_forEachProperty() {
        var changes: [(RatingFilter?, Set<PhotoColorLabel>, SavedFilter?)] = []
        let viewModel = makeViewModel(
            ratingFilter: RatingFilter(stars: 3, comparison: .atLeast),
            colorLabelFilter: [.red],
            savedFilter: .savedOnly,
            onChange: { changes.append(($0, $1, $2)) }
        )

        viewModel.clearFilters()

        #expect(changes.count == 3)
        #expect(changes[0].0 == nil)
        #expect(changes[0].1 == [.red])
        #expect(changes[0].2 == .savedOnly)
        #expect(changes[1].0 == nil)
        #expect(changes[1].1.isEmpty)
        #expect(changes[1].2 == .savedOnly)
        #expect(changes[2].0 == nil)
        #expect(changes[2].1.isEmpty)
        #expect(changes[2].2 == nil)
    }
}
