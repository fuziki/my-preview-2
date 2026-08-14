import Testing
import Foundation
import Core
@testable import FileBrowser

struct FileBrowserAdvancedSettingsViewModelTests {

    private func makeViewModel(
        isRatingEnabled: Bool = true,
        pipAutoAdvanceIntervalSeconds: Int = 5,
        onRatingEnabledChange: @escaping (Bool) -> Void = { _ in },
        onPipAutoAdvanceIntervalSecondsChange: @escaping (Int) -> Void = { _ in },
        onClearCacheRequested: @escaping () -> (isRatingEnabled: Bool, pipAutoAdvanceIntervalSeconds: Int) = {
            (isRatingEnabled: true, pipAutoAdvanceIntervalSeconds: 5)
        }
    ) -> FileBrowserAdvancedSettingsViewModel {
        FileBrowserAdvancedSettingsViewModel(
            isRatingEnabled: isRatingEnabled,
            pipAutoAdvanceIntervalSeconds: pipAutoAdvanceIntervalSeconds,
            onRatingEnabledChange: onRatingEnabledChange,
            onPipAutoAdvanceIntervalSecondsChange: onPipAutoAdvanceIntervalSecondsChange,
            onClearCacheRequested: onClearCacheRequested
        )
    }

    @Test
    func init_setsInitialValues() {
        let viewModel = makeViewModel(isRatingEnabled: true, pipAutoAdvanceIntervalSeconds: 7)

        #expect(viewModel.isRatingEnabled == true)
        #expect(viewModel.pipAutoAdvanceIntervalSeconds == 7)
    }

    @Test
    func pipAutoAdvanceIntervalSecondsRange_matchesUserDefaultsSettingsRange() {
        #expect(
            FileBrowserAdvancedSettingsViewModel.pipAutoAdvanceIntervalSecondsRange
                == UserDefaultsSettings.pipAutoAdvanceIntervalSecondsRange
        )
    }

    @Test
    func setIsRatingEnabled_notifiesOnRatingEnabledChange() {
        var changedValues: [Bool] = []
        let viewModel = makeViewModel(onRatingEnabledChange: { changedValues.append($0) })

        viewModel.isRatingEnabled = false

        #expect(changedValues == [false])
    }

    @Test
    func setPipAutoAdvanceIntervalSeconds_notifiesOnPipAutoAdvanceIntervalSecondsChange() {
        var changedValues: [Int] = []
        let viewModel = makeViewModel(onPipAutoAdvanceIntervalSecondsChange: { changedValues.append($0) })

        viewModel.pipAutoAdvanceIntervalSeconds = 15

        #expect(changedValues == [15])
    }

    @Test
    func clearCache_appliesReturnedDefaults_toCurrentProperties() {
        let viewModel = makeViewModel(
            isRatingEnabled: false,
            pipAutoAdvanceIntervalSeconds: 20,
            onClearCacheRequested: { (isRatingEnabled: true, pipAutoAdvanceIntervalSeconds: 3) }
        )

        viewModel.clearCache()

        #expect(viewModel.isRatingEnabled == true)
        #expect(viewModel.pipAutoAdvanceIntervalSeconds == 3)
    }

    @Test
    func clearCache_notifiesBothOnChangeCallbacks_withDefaults() {
        var ratingChanges: [Bool] = []
        var intervalChanges: [Int] = []
        let viewModel = makeViewModel(
            isRatingEnabled: false,
            pipAutoAdvanceIntervalSeconds: 20,
            onRatingEnabledChange: { ratingChanges.append($0) },
            onPipAutoAdvanceIntervalSecondsChange: { intervalChanges.append($0) },
            onClearCacheRequested: { (isRatingEnabled: true, pipAutoAdvanceIntervalSeconds: 3) }
        )

        viewModel.clearCache()

        #expect(ratingChanges == [true])
        #expect(intervalChanges == [3])
    }
}
