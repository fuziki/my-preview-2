import Foundation
import Observation

/// ファイルシステムへの読み込み中フラグを一元管理するトラッカー。
/// カウンタ方式なので複数の並行読み込みが重なっても正しく isLoading を制御する。
@Observable @MainActor
public final class FileLoadingTracker {
    public private(set) var isLoading: Bool = false
    private var activeCount: Int = 0

    public init() {}

    /// body の実行中だけ isLoading を true に保つ。
    public func track<T>(_ body: () async -> T) async -> T {
        activeCount += 1
        isLoading = true
        defer {
            activeCount -= 1
            if activeCount == 0 { isLoading = false }
        }
        return await body()
    }
}
