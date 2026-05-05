import Foundation

/// PhotoViewerViewController と PhotoViewerViewModel が必要とする依存関係をまとめたバンドル。
/// FileBrowserViewController で一度生成し、フォトビューアーセッション間で再利用することで
/// 共有状態（例: SavedDateStore）が複数回の起動をまたいで保持される。
struct PhotoViewerServices {
    let imageLoader: any ImageLoaderServiceProtocol
    let exifService: any ExifServiceProtocol
    let photoLibrary: any PhotoLibraryServiceProtocol
    let savedDateStore: any SavedDateStoreProtocol
}

extension PhotoViewerServices {
    /// 本番用の実サービス実装を使った設定を生成する。
    static func production(savedDateStore: any SavedDateStoreProtocol) -> PhotoViewerServices {
        PhotoViewerServices(
            imageLoader: ImageLoaderService(),
            exifService: ExifService(),
            photoLibrary: PhotoLibraryService(),
            savedDateStore: savedDateStore
        )
    }
}
