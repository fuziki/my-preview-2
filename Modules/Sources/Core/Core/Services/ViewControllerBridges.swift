import UIKit

/// 現在表示中のURLを提供するプロトコル。
/// FileBrowserViewControllerがPhotoViewerViewControllerのcurrentURLを取得するために使用する。
/// FileBrowserはPhotoViewerに直接依存できないため、このプロトコルを介して通信する。
public protocol CurrentURLProvider {
    var currentURL: URL { get }
}

/// 閉じる時のコールバックを設定するプロトコル。
/// FileBrowserViewControllerがPhotoViewerViewControllerの終了イベントを受け取るために使用する。
public protocol DismissNotifiable {
    var onDismiss: ((URL) -> Void)? { get set }
}
