import Foundation

public struct PhotoViewerInput: Sendable {
    public let initialURL: URL
    public let allURLs: [URL]
    /// レーティング機能が有効か（星ボタンの表示可否）
    public let isRatingEnabled: Bool
    /// 適用中のレーティングフィルター（nilはフィルターなし）。星変更時の自動遷移判定に使用する
    public let ratingFilter: RatingFilter?

    public init(
        initialURL: URL,
        allURLs: [URL],
        isRatingEnabled: Bool = false,
        ratingFilter: RatingFilter? = nil
    ) {
        self.initialURL = initialURL
        self.allURLs = allURLs
        self.isRatingEnabled = isRatingEnabled
        self.ratingFilter = ratingFilter
    }
}
