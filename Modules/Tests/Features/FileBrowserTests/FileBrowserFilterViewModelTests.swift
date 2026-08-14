import Testing
import Foundation
import Core
@testable import FileBrowser

struct FileBrowserFilterViewModelTests {

    private func makeViewModel(
        ratingFilter: RatingFilter? = nil,
        colorLabelFilter: Set<PhotoColorLabel> = [],
        onChange: @escaping (RatingFilter?, Set<PhotoColorLabel>) -> Void = { _, _ in }
    ) -> FileBrowserFilterViewModel {
        FileBrowserFilterViewModel(
            ratingFilter: ratingFilter,
            colorLabelFilter: colorLabelFilter,
            onChange: onChange
        )
    }

    @Test
    func init_setsInitialValues() {
        let ratingFilter = RatingFilter(stars: 3, comparison: .atLeast)
        let viewModel = makeViewModel(ratingFilter: ratingFilter, colorLabelFilter: [.red])

        #expect(viewModel.ratingFilter == ratingFilter)
        #expect(viewModel.colorLabelFilter == [.red])
    }

    @Test
    func setRatingFilter_notifiesOnChange_withCurrentColorLabelFilter() {
        var changes: [(RatingFilter?, Set<PhotoColorLabel>)] = []
        let viewModel = makeViewModel(colorLabelFilter: [.green], onChange: { changes.append(($0, $1)) })

        let newFilter = RatingFilter(stars: 4, comparison: .exactly)
        viewModel.ratingFilter = newFilter

        #expect(changes.count == 1)
        #expect(changes[0].0 == newFilter)
        #expect(changes[0].1 == [.green])
    }

    @Test
    func setColorLabelFilter_notifiesOnChange_withCurrentRatingFilter() {
        var changes: [(RatingFilter?, Set<PhotoColorLabel>)] = []
        let ratingFilter = RatingFilter(stars: 2, comparison: .atLeast)
        let viewModel = makeViewModel(ratingFilter: ratingFilter, onChange: { changes.append(($0, $1)) })

        viewModel.colorLabelFilter = [.blue, .yellow]

        #expect(changes.count == 1)
        #expect(changes[0].0 == ratingFilter)
        #expect(changes[0].1 == [.blue, .yellow])
    }

    @Test
    func clearFilters_resetsRatingFilterAndColorLabelFilter() {
        let viewModel = makeViewModel(
            ratingFilter: RatingFilter(stars: 3, comparison: .atLeast),
            colorLabelFilter: [.red, .green]
        )

        viewModel.clearFilters()

        #expect(viewModel.ratingFilter == nil)
        #expect(viewModel.colorLabelFilter.isEmpty)
    }

    @Test
    func clearFilters_notifiesOnChange_forEachProperty() {
        var changes: [(RatingFilter?, Set<PhotoColorLabel>)] = []
        let viewModel = makeViewModel(
            ratingFilter: RatingFilter(stars: 3, comparison: .atLeast),
            colorLabelFilter: [.red],
            onChange: { changes.append(($0, $1)) }
        )

        viewModel.clearFilters()

        #expect(changes.count == 2)
        #expect(changes[0].0 == nil)
        #expect(changes[0].1 == [.red])
        #expect(changes[1].0 == nil)
        #expect(changes[1].1.isEmpty)
    }
}
