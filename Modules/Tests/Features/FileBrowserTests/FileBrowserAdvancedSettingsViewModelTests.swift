import Testing
import Foundation
import Core
@testable import FileBrowser

struct FileBrowserAdvancedSettingsViewModelTests {

    private func makeViewModel(
        isRatingEnabled: Bool = true,
        pipAutoAdvanceIntervalSeconds: Int = 5,
        buttonAutoAdvanceIntervalMilliseconds: Int = 120,
        onRatingEnabledChange: @escaping (Bool) -> Void = { _ in },
        onPipAutoAdvanceIntervalSecondsChange: @escaping (Int) -> Void = { _ in },
        onButtonAutoAdvanceIntervalMillisecondsChange: @escaping (Int) -> Void = { _ in },
        onClearCacheRequested: @escaping () -> (isRatingEnabled: Bool, pipAutoAdvanceIntervalSeconds: Int, buttonAutoAdvanceIntervalMilliseconds: Int) = {
            (isRatingEnabled: true, pipAutoAdvanceIntervalSeconds: 5, buttonAutoAdvanceIntervalMilliseconds: 120)
        }
    ) -> FileBrowserAdvancedSettingsViewModel {
        FileBrowserAdvancedSettingsViewModel(
            isRatingEnabled: isRatingEnabled,
            pipAutoAdvanceIntervalSeconds: pipAutoAdvanceIntervalSeconds,
            buttonAutoAdvanceIntervalMilliseconds: buttonAutoAdvanceIntervalMilliseconds,
            onRatingEnabledChange: onRatingEnabledChange,
            onPipAutoAdvanceIntervalSecondsChange: onPipAutoAdvanceIntervalSecondsChange,
            onButtonAutoAdvanceIntervalMillisecondsChange: onButtonAutoAdvanceIntervalMillisecondsChange,
            onClearCacheRequested: onClearCacheRequested
        )
    }

    @Test
    func init_setsInitialValues() {
        let viewModel = makeViewModel(
            isRatingEnabled: true,
            pipAutoAdvanceIntervalSeconds: 7,
            buttonAutoAdvanceIntervalMilliseconds: 200
        )

        #expect(viewModel.isRatingEnabled == true)
        #expect(viewModel.pipAutoAdvanceIntervalSeconds == 7)
        #expect(viewModel.buttonAutoAdvanceIntervalMilliseconds == 200)
    }

    @Test
    func pipAutoAdvanceIntervalSecondsRange_matchesUserDefaultsSettingsRange() {
        #expect(
            FileBrowserAdvancedSettingsViewModel.pipAutoAdvanceIntervalSecondsRange
                == UserDefaultsSettings.pipAutoAdvanceIntervalSecondsRange
        )
    }

    @Test
    func buttonAutoAdvanceIntervalMillisecondsRange_matchesUserDefaultsSettingsRange() {
        #expect(
            FileBrowserAdvancedSettingsViewModel.buttonAutoAdvanceIntervalMillisecondsRange
                == UserDefaultsSettings.buttonAutoAdvanceIntervalMillisecondsRange
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
    func setButtonAutoAdvanceIntervalMilliseconds_notifiesOnButtonAutoAdvanceIntervalMillisecondsChange() {
        var changedValues: [Int] = []
        let viewModel = makeViewModel(onButtonAutoAdvanceIntervalMillisecondsChange: { changedValues.append($0) })

        viewModel.buttonAutoAdvanceIntervalMilliseconds = 300

        #expect(changedValues == [300])
    }

    @Test
    func clearCache_appliesReturnedDefaults_toCurrentProperties() {
        let viewModel = makeViewModel(
            isRatingEnabled: false,
            pipAutoAdvanceIntervalSeconds: 20,
            buttonAutoAdvanceIntervalMilliseconds: 400,
            onClearCacheRequested: {
                (isRatingEnabled: true, pipAutoAdvanceIntervalSeconds: 3, buttonAutoAdvanceIntervalMilliseconds: 90)
            }
        )

        viewModel.clearCache()

        #expect(viewModel.isRatingEnabled == true)
        #expect(viewModel.pipAutoAdvanceIntervalSeconds == 3)
        #expect(viewModel.buttonAutoAdvanceIntervalMilliseconds == 90)
    }

    @Test
    func clearCache_notifiesAllOnChangeCallbacks_withDefaults() {
        var ratingChanges: [Bool] = []
        var intervalChanges: [Int] = []
        var buttonIntervalChanges: [Int] = []
        let viewModel = makeViewModel(
            isRatingEnabled: false,
            pipAutoAdvanceIntervalSeconds: 20,
            buttonAutoAdvanceIntervalMilliseconds: 400,
            onRatingEnabledChange: { ratingChanges.append($0) },
            onPipAutoAdvanceIntervalSecondsChange: { intervalChanges.append($0) },
            onButtonAutoAdvanceIntervalMillisecondsChange: { buttonIntervalChanges.append($0) },
            onClearCacheRequested: {
                (isRatingEnabled: true, pipAutoAdvanceIntervalSeconds: 3, buttonAutoAdvanceIntervalMilliseconds: 90)
            }
        )

        viewModel.clearCache()

        #expect(ratingChanges == [true])
        #expect(intervalChanges == [3])
        #expect(buttonIntervalChanges == [90])
    }
}
