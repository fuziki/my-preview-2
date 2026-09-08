import Core
import Foundation

/// FileBrowserBulkSaveViewController / FileBrowserBulkSaveViewModel が必要とする依存関係をまとめたバンドル。
public struct FileBrowserBulkSaveDependencies {
    public let photoLibrary: any PhotoLibraryServiceProtocol
    public let savedDateStore: any SavedDateStoreProtocol
    public let hapticsService: any HapticsServiceProtocol

    public init(
        photoLibrary: any PhotoLibraryServiceProtocol,
        savedDateStore: any SavedDateStoreProtocol,
        hapticsService: any HapticsServiceProtocol
    ) {
        self.photoLibrary = photoLibrary
        self.savedDateStore = savedDateStore
        self.hapticsService = hapticsService
    }
}
