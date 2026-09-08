import UIKit
import Core
#if targetEnvironment(simulator)
import Mocks
#endif

/// ViewControllerの生成とサービスの依存解決を担うコンテナ。
/// ViewControllerレイヤー（SceneDelegate）でのみ保持し、機能モジュール間の循環参照を防ぐ。
/// 画面生成は screenProvider（ScreenProviding）に一元化し、AppContainer自身はサービス・ストアの所有に専念する。
final class AppContainer {

    // MARK: - 共有サービス

    /// ファイルシステムへの読み込み中フラグを一元管理する。CornerDotWindowが観察する。
    let tracker = FileLoadingTracker()

    /// セッションをまたいで保存日時を保持するため、AppContainerが所有する
    private let savedDateStore: any SavedDateStoreProtocol = SavedDateStore(
        modelContainer: SavedDateStore.makeDefaultModelContainer()
    )

    /// セッションをまたいでレーティングを保持するため、AppContainerが所有する
    private let ratingStore: any PhotoRatingStoreProtocol = PhotoRatingStore(
        modelContainer: PhotoRatingStore.makeDefaultModelContainer()
    )

    /// セッションをまたいでカラーラベルを保持するため、AppContainerが所有する
    private let colorLabelStore: any ColorLabelStoreProtocol = ColorLabelStore(
        modelContainer: ColorLabelStore.makeDefaultModelContainer()
    )

    /// FileBrowserとPhotoViewerの保存設定を同一の値で参照させるため、AppContainerが所有する
    private let settingsStore: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings> = UserDefaultsSettingsStore(
        defaultValue: .default(),
        defaults: .standard
    )

    /// フィルター済み写真リストの唯一の真実（SSOT）。FileBrowserとPhotoViewerへ同一インスタンスを注入する
    private let photoCollectionStore: any PhotoCollectionStoreProtocol = PhotoCollectionStore()

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

    // MARK: - 画面生成

    /// 画面生成を一元管理するサービス。ViewControllerレイヤーはこれを介して画面を取得する。
    private(set) lazy var screenProvider: any ScreenProviding = AppScreenProvider(
        fileSystemService: fileSystemService,
        imageLoaderService: imageLoaderService,
        exifService: exifService,
        thumbnailService: thumbnailService,
        savedDateStore: savedDateStore,
        ratingStore: ratingStore,
        colorLabelStore: colorLabelStore,
        settingsStore: settingsStore,
        photoCollectionStore: photoCollectionStore
    )
}
