import UIKit
import Core
import FileBrowser
import PhotoViewer

/// ScreenProvidingの実体。ScreenTypeに対応するViewControllerを生成する。
/// AppContainerが所有するサービス・ストアをコンストラクタ注入で受け取り、各画面の依存を組み立てる。
final class AppScreenProvider: ScreenProviding {

    // MARK: - 依存

    private let fileSystemService: any FileSystemServiceProtocol
    private let imageLoaderService: any ImageLoaderServiceProtocol
    private let exifService: any ExifServiceProtocol
    private let thumbnailService: any ThumbnailServiceProtocol
    private let savedDateStore: any SavedDateStoreProtocol
    private let ratingStore: any PhotoRatingStoreProtocol
    private let colorLabelStore: any ColorLabelStoreProtocol
    private let settingsStore: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>
    private let photoCollectionStore: any PhotoCollectionStoreProtocol

    // MARK: - 初期化

    init(
        fileSystemService: any FileSystemServiceProtocol,
        imageLoaderService: any ImageLoaderServiceProtocol,
        exifService: any ExifServiceProtocol,
        thumbnailService: any ThumbnailServiceProtocol,
        savedDateStore: any SavedDateStoreProtocol,
        ratingStore: any PhotoRatingStoreProtocol,
        colorLabelStore: any ColorLabelStoreProtocol,
        settingsStore: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>,
        photoCollectionStore: any PhotoCollectionStoreProtocol
    ) {
        self.fileSystemService = fileSystemService
        self.imageLoaderService = imageLoaderService
        self.exifService = exifService
        self.thumbnailService = thumbnailService
        self.savedDateStore = savedDateStore
        self.ratingStore = ratingStore
        self.colorLabelStore = colorLabelStore
        self.settingsStore = settingsStore
        self.photoCollectionStore = photoCollectionStore
    }

    // MARK: - ScreenProviding

    func makeViewController(_ screen: ScreenType) -> UIViewController {
        switch screen {
        case .fileBrowser:
            return makeFileBrowserViewController()

        case .photoViewer(let input, let onDismiss):
            return makePhotoViewerViewController(input: input, onDismiss: onDismiss)

        case .fileBrowserFilter(let ratingFilter, let colorLabelFilter, let savedFilter, let onChange):
            return FileBrowserFilterViewController(
                ratingFilter: ratingFilter,
                colorLabelFilter: colorLabelFilter,
                savedFilter: savedFilter,
                onChange: onChange
            )

        case .fileBrowserAdvancedSettings(
            let isRatingEnabled,
            let pipAutoAdvanceIntervalSeconds,
            let onRatingEnabledChange,
            let onPipAutoAdvanceIntervalSecondsChange,
            let onClearCacheRequested
        ):
            return FileBrowserAdvancedSettingsViewController(
                isRatingEnabled: isRatingEnabled,
                pipAutoAdvanceIntervalSeconds: pipAutoAdvanceIntervalSeconds,
                onRatingEnabledChange: onRatingEnabledChange,
                onPipAutoAdvanceIntervalSecondsChange: onPipAutoAdvanceIntervalSecondsChange,
                onClearCacheRequested: onClearCacheRequested
            )

        case .fileBrowserBulkSave(let urls, let onURLSaved):
            let dependencies = FileBrowserBulkSaveDependencies(
                photoLibrary: PhotoLibraryService(settings: settingsStore),
                savedDateStore: savedDateStore,
                hapticsService: HapticsService()
            )
            return FileBrowserBulkSaveViewController(urls: urls, dependencies: dependencies, onURLSaved: onURLSaved)
        }
    }

    // MARK: - private

    /// FileBrowserViewControllerを生成する。
    private func makeFileBrowserViewController() -> UIViewController {
        let dependencies = FileBrowserDependencies(
            fileSystemService: fileSystemService,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            settings: settingsStore,
            thumbnailService: thumbnailService,
            photoCollectionStore: photoCollectionStore
        )
        let viewModel = FileBrowserViewModel(dependencies: dependencies)
        return FileBrowserViewController(
            viewModel: viewModel,
            dependencies: dependencies,
            screenProvider: self
        )
    }

    /// PhotoViewerViewControllerを生成する。
    private func makePhotoViewerViewController(input: PhotoViewerInput, onDismiss: @escaping (URL) -> Void) -> UIViewController {
        let dependencies = PhotoViewerDependencies(
            imageLoader: imageLoaderService,
            exifService: exifService,
            photoLibrary: PhotoLibraryService(settings: settingsStore),
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            hapticsService: HapticsService(),
            settings: settingsStore,
            photoCollectionStore: photoCollectionStore
        )
        let vc = PhotoViewerViewController(input: input, dependencies: dependencies)
        vc.onDismiss = onDismiss
        return vc
    }
}
