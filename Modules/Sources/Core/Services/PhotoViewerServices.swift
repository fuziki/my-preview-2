import Foundation

/// PhotoViewerViewController と PhotoViewerViewModel が必要とする依存関係をまとめたバンドル。
/// AppContainer で一度生成し、フォトビューアーセッション間で再利用することで
/// 共有状態（例: SavedDateStore）が複数回の起動をまたいで保持される。
public struct PhotoViewerServices {
    public let imageLoader: any ImageLoaderServiceProtocol
    public let exifService: any ExifServiceProtocol
    public let photoLibrary: any PhotoLibraryServiceProtocol
    public let savedDateStore: any SavedDateStoreProtocol
    public let hapticsService: any HapticsServiceProtocol

    public init(
        imageLoader: any ImageLoaderServiceProtocol,
        exifService: any ExifServiceProtocol,
        photoLibrary: any PhotoLibraryServiceProtocol,
        savedDateStore: any SavedDateStoreProtocol,
        hapticsService: any HapticsServiceProtocol
    ) {
        self.imageLoader = imageLoader
        self.exifService = exifService
        self.photoLibrary = photoLibrary
        self.savedDateStore = savedDateStore
        self.hapticsService = hapticsService
    }
}

public extension PhotoViewerServices {
    /// 本番用の実サービス実装を使った設定を生成する。
    static func production(savedDateStore: any SavedDateStoreProtocol) -> PhotoViewerServices {
        PhotoViewerServices(
            imageLoader: ImageLoaderService(),
            exifService: ExifService(),
            photoLibrary: PhotoLibraryService(),
            savedDateStore: savedDateStore,
            hapticsService: HapticsService()
        )
    }
}
