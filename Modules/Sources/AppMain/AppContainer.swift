import UIKit
import Core
import FileBrowser
import PhotoViewer
#if targetEnvironment(simulator)
import Mocks
#endif

/// ViewControllerの生成とサービスの依存解決を担うコンテナ。
/// ViewControllerレイヤー（SceneDelegate）でのみ保持し、機能モジュール間の循環参照を防ぐ。
/// FileBrowserはPhotoViewerを直接参照せず、ファクトリクロージャを介して生成する。
final class AppContainer {

    // MARK: - 共有サービス

    /// ファイルシステムへの読み込み中フラグを一元管理する。LoadingIndicatorWindowが観察する。
    let tracker = FileLoadingTracker()

    /// セッションをまたいで保存日時を保持するため、AppContainerが所有する
    private let savedDateStore: any SavedDateStoreProtocol = SavedDateStore()

    /// セッションをまたいでレーティングを保持するため、AppContainerが所有する
    private let ratingStore: any PhotoRatingStoreProtocol = PhotoRatingStore()

    /// セッションをまたいでカラーラベルを保持するため、AppContainerが所有する
    private let colorLabelStore: any ColorLabelStoreProtocol = ColorLabelStore()

    /// FileBrowserとPhotoViewerの保存設定を同一の値で参照させるため、AppContainerが所有する
    private let settingsStore: any UserDefaultsSettingsStoreProtocol = UserDefaultsSettingsStore(storage: UserDefaultsStorage.shared)

    #if targetEnvironment(simulator)
    /// シミュレータでは実ファイルが存在しないため、ファイルIO系サービスをモックに差し替える
    private lazy var fileSystemService: any FileSystemServiceProtocol = MockFileSystemService()
    private lazy var imageLoaderService: any ImageLoaderServiceProtocol = MockImageLoaderService()
    private lazy var exifService: any ExifServiceProtocol = MockExifService()
    private lazy var thumbnailService: any ThumbnailServiceProtocol = MockThumbnailService()
    #else
    /// tracker 注入済みのサービス群。全モジュールへはここから伝播させる。
    private lazy var fileSystemService: any FileSystemServiceProtocol = FileSystemService(tracker: tracker)
    private lazy var imageLoaderService: any ImageLoaderServiceProtocol = ImageLoaderService(tracker: tracker)
    private lazy var exifService: any ExifServiceProtocol = ExifService(tracker: tracker)
    private lazy var thumbnailService: any ThumbnailServiceProtocol = ThumbnailService(tracker: tracker)
    #endif

    // MARK: - ファクトリ

    /// FileBrowserViewControllerを生成する。
    /// PhotoViewerViewControllerの生成はクロージャとして注入する。
    func makeFileBrowserViewController() -> UIViewController {
        let viewModel = FileBrowserViewModel(
            fileSystemService: fileSystemService,
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            settings: settingsStore
        )
        return FileBrowserViewController(
            viewModel: viewModel,
            thumbnailService: thumbnailService,
            photoViewerFactory: { [weak self] input in
                guard let self else { return UIViewController() }
                return self.makePhotoViewerViewController(input: input)
            }
        )
    }

    /// PhotoViewerViewControllerを生成する。
    private func makePhotoViewerViewController(input: PhotoViewerInput) -> UIViewController {
        let services = PhotoViewerServices(
            imageLoader: imageLoaderService,
            exifService: exifService,
            photoLibrary: PhotoLibraryService(settings: settingsStore),
            savedDateStore: savedDateStore,
            ratingStore: ratingStore,
            colorLabelStore: colorLabelStore,
            hapticsService: HapticsService()
        )
        return PhotoViewerViewController(input: input, services: services)
    }
}
