import Testing
import Foundation
@testable import Core

struct FileLoadingTrackerTests {

    @Test
    func initialState_isLoadingFalse() {
        let tracker = FileLoadingTracker()
        #expect(tracker.isLoading == false)
    }

    @Test
    func track_returnsBodyResult() async {
        let tracker = FileLoadingTracker()
        let result = await tracker.track { 42 }
        #expect(result == 42)
    }

    @Test
    func track_setsIsLoadingTrue_duringExecution() async {
        let tracker = FileLoadingTracker()
        await tracker.track {
            #expect(tracker.isLoading == true)
        }
    }

    @Test
    func track_resetsIsLoadingFalse_afterCompletion() async {
        let tracker = FileLoadingTracker()
        await tracker.track {}
        #expect(tracker.isLoading == false)
    }

    /// 2つの読み込みが重なっている間はisLoadingがtrueのままで、
    /// 後発の読み込みが終わって初めてfalseに戻ることを検証する（カウンタ方式の要）
    @Test
    func track_overlappingCalls_isLoadingStaysTrueUntilLastCompletes() async {
        let tracker = FileLoadingTracker()

        var resumeFirst: CheckedContinuation<Void, Never>?
        var resumeSecond: CheckedContinuation<Void, Never>?

        let first = Task {
            await tracker.track {
                await withCheckedContinuation { resumeFirst = $0 }
            }
        }
        let second = Task {
            await tracker.track {
                await withCheckedContinuation { resumeSecond = $0 }
            }
        }

        while resumeFirst == nil || resumeSecond == nil {
            await Task.yield()
        }
        #expect(tracker.isLoading == true)

        resumeFirst?.resume()
        _ = await first.value
        #expect(tracker.isLoading == true)

        resumeSecond?.resume()
        _ = await second.value
        #expect(tracker.isLoading == false)
    }
}
