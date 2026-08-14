import Core
import Foundation

/// PhotoViewerViewController / PhotoViewerViewModel / PhotoPageItemCell が必要とする依存関係をまとめたバンドル。
/// AppContainer で一度生成し、フォトビューアーセッション間で再利用することで
/// 共有状態（例: SavedDateStore）が複数回の起動をまたいで保持される。
/// imageLoader と exifService には FileLoadingTracker 注入済みのインスタンスを渡すこと。
public struct PhotoViewerDependencies {
    public let imageLoader: any ImageLoaderServiceProtocol
    public let exifService: any ExifServiceProtocol
    public let photoLibrary: any PhotoLibraryServiceProtocol
    public let savedDateStore: any SavedDateStoreProtocol
    public let ratingStore: any PhotoRatingStoreProtocol
    public let colorLabelStore: any ColorLabelStoreProtocol
    public let hapticsService: any HapticsServiceProtocol
    public let settings: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>

    public init(
        imageLoader: any ImageLoaderServiceProtocol,
        exifService: any ExifServiceProtocol,
        photoLibrary: any PhotoLibraryServiceProtocol,
        savedDateStore: any SavedDateStoreProtocol,
        ratingStore: any PhotoRatingStoreProtocol,
        colorLabelStore: any ColorLabelStoreProtocol,
        hapticsService: any HapticsServiceProtocol,
        settings: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>
    ) {
        self.imageLoader = imageLoader
        self.exifService = exifService
        self.photoLibrary = photoLibrary
        self.savedDateStore = savedDateStore
        self.ratingStore = ratingStore
        self.colorLabelStore = colorLabelStore
        self.hapticsService = hapticsService
        self.settings = settings
    }
}
