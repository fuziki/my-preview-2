import UIKit
import Core
import FileBrowser
import PhotoViewer

/// ViewControllerの生成とサービスの依存解決を担うコンテナ。
/// ViewControllerレイヤー（SceneDelegate）でのみ保持し、機能モジュール間の循環参照を防ぐ。
/// FileBrowserはPhotoViewerを直接参照せず、ファクトリクロージャを介して生成する。
final class AppContainer {

    // MARK: - 共有サービス

    /// セッションをまたいで保存日時を保持するため、AppContainerが所有する
    private let savedDateStore: any SavedDateStoreProtocol = SavedDateStore()
    private let fileSystemService: any FileSystemServiceProtocol = FileSystemService()

    // MARK: - ファクトリ

    /// FileBrowserViewControllerを生成する。
    /// PhotoViewerViewControllerの生成はクロージャとして注入する。
    func makeFileBrowserViewController() -> UIViewController {
        let viewModel = FileBrowserViewModel(fileSystemService: fileSystemService)
        return FileBrowserViewController(
            viewModel: viewModel,
            photoViewerFactory: { [weak self] input in
                guard let self else { return UIViewController() }
                return self.makePhotoViewerViewController(input: input)
            }
        )
    }

    /// PhotoViewerViewControllerを生成する。
    private func makePhotoViewerViewController(input: PhotoViewerInput) -> UIViewController {
        let services = PhotoViewerServices.production(savedDateStore: savedDateStore)
        return PhotoViewerViewController(input: input, services: services)
    }
}
