import UIKit

// MARK: - ScreenType

/// アプリ内の「画面表示単位（Screen）」を表す列挙。
/// 各 case の関連値には、その画面の ViewController を生成するために
/// View レイヤー（呼び出し側）が渡すべきパラメータのみを持たせる。
/// サービス層（AppMain 管理の依存）は実体側（AppScreenProvider）で注入する。
public enum ScreenType {
    /// ファイルブラウザ（ルート画面）
    case fileBrowser

    /// フォトビューア。onDismiss は閉じた時に最後に表示していた URL を通知する。
    case photoViewer(input: PhotoViewerInput, onDismiss: (URL) -> Void)

    /// フィルターのハーフモーダル。onChange は変更のたびに呼び出し側へ通知する。
    case fileBrowserFilter(
        ratingFilter: RatingFilter?,
        colorLabelFilter: Set<PhotoColorLabel>,
        savedFilter: SavedFilter?,
        onChange: (RatingFilter?, Set<PhotoColorLabel>, SavedFilter?) -> Void
    )

    /// 詳細設定画面。各 onChange 系クロージャで変更を呼び出し側へ通知する。
    case fileBrowserAdvancedSettings(
        isRatingEnabled: Bool,
        pipAutoAdvanceIntervalSeconds: Int,
        onRatingEnabledChange: (Bool) -> Void,
        onPipAutoAdvanceIntervalSecondsChange: (Int) -> Void,
        onClearCacheRequested: () -> (isRatingEnabled: Bool, pipAutoAdvanceIntervalSeconds: Int)
    )

    /// 「全て保存」の進捗オーバーレイ。onURLSaved は1枚保存完了ごとに保存先 URL と日時を通知する。
    case fileBrowserBulkSave(urls: [URL], onURLSaved: (URL, Date) -> Void)
}

// MARK: - ScreenProviding

/// ScreenType に対応する ViewController を生成するサービス。
/// protocol は Core に置き、実体（依存注入込み）は AppMain の AppScreenProvider が担う。
/// View レイヤーはこのサービスを介して画面遷移用の ViewController を取得してよい。
public protocol ScreenProviding {
    func makeViewController(_ screen: ScreenType) -> UIViewController
}
