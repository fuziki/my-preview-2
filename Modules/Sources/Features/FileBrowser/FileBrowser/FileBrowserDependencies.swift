import Core
import Foundation

/// FileBrowserViewController / FileBrowserViewModel が必要とする依存関係をまとめたバンドル。
public struct FileBrowserDependencies {
    public let fileSystemService: any FileSystemServiceProtocol
    public let savedDateStore: any SavedDateStoreProtocol
    public let ratingStore: any PhotoRatingStoreProtocol
    public let colorLabelStore: any ColorLabelStoreProtocol
    public let settings: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>
    public let thumbnailService: any ThumbnailServiceProtocol

    public init(
        fileSystemService: any FileSystemServiceProtocol,
        savedDateStore: any SavedDateStoreProtocol,
        ratingStore: any PhotoRatingStoreProtocol,
        colorLabelStore: any ColorLabelStoreProtocol,
        settings: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>,
        thumbnailService: any ThumbnailServiceProtocol
    ) {
        self.fileSystemService = fileSystemService
        self.savedDateStore = savedDateStore
        self.ratingStore = ratingStore
        self.colorLabelStore = colorLabelStore
        self.settings = settings
        self.thumbnailService = thumbnailService
    }
}
