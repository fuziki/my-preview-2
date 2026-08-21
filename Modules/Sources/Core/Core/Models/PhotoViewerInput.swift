import Foundation

public struct PhotoViewerInput {
    public let initialURL: URL
    public let allURLs: [URL]
    /// レーティング機能が有効か（星ボタン・カラーラベルの表示可否）
    public let isRatingEnabled: Bool
    /// 適用中のレーティングフィルター（nilはフィルターなし）。星変更時の自動遷移判定に使用する
    public let ratingFilter: RatingFilter?
    /// 適用中のカラーラベルフィルター（空はフィルターなし）。ラベル変更時の自動遷移判定に使用する
    public let colorLabelFilter: Set<PhotoColorLabel>
    /// 適用中の保存状態フィルター（nilはフィルターなし）。保存時の自動遷移判定に使用する
    public let savedFilter: SavedFilter?

    public init(
        initialURL: URL,
        allURLs: [URL],
        isRatingEnabled: Bool = false,
        ratingFilter: RatingFilter? = nil,
        colorLabelFilter: Set<PhotoColorLabel> = [],
        savedFilter: SavedFilter? = nil
    ) {
        self.initialURL = initialURL
        self.allURLs = allURLs
        self.isRatingEnabled = isRatingEnabled
        self.ratingFilter = ratingFilter
        self.colorLabelFilter = colorLabelFilter
        self.savedFilter = savedFilter
    }
}
