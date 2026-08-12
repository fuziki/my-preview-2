import UIKit
import Core
import Localization

/// FileBrowserViewControllerの設定メニューのUIMenuElement構築を担当する。
/// メニュー選択後の画面更新（BarButtonItemのmenu再代入・スナップショット再適用・アラート表示等）は
/// コールバック経由でFileBrowserViewControllerに委譲する。
final class FileBrowserMenuBuilder {

    private let viewModel: FileBrowserViewModel
    private let onSettingsMenuChanged: () -> Void
    private let onRatingToggled: () -> Void
    private let onClearCacheRequested: () -> Void

    init(
        viewModel: FileBrowserViewModel,
        onSettingsMenuChanged: @escaping () -> Void,
        onRatingToggled: @escaping () -> Void,
        onClearCacheRequested: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onSettingsMenuChanged = onSettingsMenuChanged
        self.onRatingToggled = onRatingToggled
        self.onClearCacheRequested = onClearCacheRequested
    }

    // MARK: - 設定メニュー

    /// 設定メニューを生成する。UIDeferredMenuElement.uncached でメニュー表示のたびに最新状態を反映する。
    func makeSettingsMenu() -> UIMenu {
        let deferred = UIDeferredMenuElement.uncached { [weak self] completion in
            completion(self?.buildSettingsMenuElements() ?? [])
        }
        return UIMenu(title: "", children: [deferred])
    }

    private func buildSettingsMenuElements() -> [UIMenuElement] {
        // 表示モード セクション（インライン展開・横並びアイコン+テキスト）
        let listAction = UIAction(
            title: L10n.FileBrowser.viewModeList,
            image: UIImage(systemName: "list.bullet"),
            attributes: .keepsMenuPresented,
            state: viewModel.viewMode == .list ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.viewMode = .list
            onSettingsMenuChanged()
        }
        let gridAction = UIAction(
            title: L10n.FileBrowser.viewModeGrid,
            image: UIImage(systemName: "square.grid.2x2"),
            attributes: .keepsMenuPresented,
            state: viewModel.viewMode == .grid ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.viewMode = .grid
            onSettingsMenuChanged()
        }
        let viewModeMenu = UIMenu(
            title: L10n.FileBrowser.viewMode,
            options: [.displayInline, .singleSelection],
            children: [listAction, gridAction]
        )
        viewModeMenu.preferredElementSize = .medium

        // 列数 セクション（グリッド選択時のみ・[−][現在値][＋]のステッパー形式）
        let columnCountMenu: UIMenu? = viewModel.viewMode == .grid ? makeColumnCountMenu() : nil

        // 保存形式 セクション（インライン展開・横並びアイコン+テキスト）
        let jpegAction = UIAction(
            title: "JPEG",
            image: UIImage(systemName: "photo"),
            attributes: .keepsMenuPresented,
            state: viewModel.saveFormat == .jpeg ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.saveFormat = .jpeg
            onSettingsMenuChanged()
        }
        let jpegAndRawAction = UIAction(
            title: "JPEG + RAW",
            image: UIImage(systemName: "photo.on.rectangle.angled"),
            attributes: .keepsMenuPresented,
            state: viewModel.saveFormat == .jpegAndRaw ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.saveFormat = .jpegAndRaw
            onSettingsMenuChanged()
        }
        let saveFormatMenu = UIMenu(
            title: L10n.FileBrowser.saveFormat,
            options: [.displayInline, .singleSelection],
            children: [jpegAction, jpegAndRawAction]
        )
        saveFormatMenu.preferredElementSize = .medium

        // ソート順 セクション
        let newestFirstAction = UIAction(
            title: L10n.FileBrowser.sortOrderNewestFirst,
            image: UIImage(systemName: "arrow.down"),
            attributes: .keepsMenuPresented,
            state: viewModel.sortOrder == FileSortOrder.dateDescending ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.sortOrder = .dateDescending
            onSettingsMenuChanged()
        }
        let oldestFirstAction = UIAction(
            title: L10n.FileBrowser.sortOrderOldestFirst,
            image: UIImage(systemName: "arrow.up"),
            attributes: .keepsMenuPresented,
            state: viewModel.sortOrder == FileSortOrder.dateAscending ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.sortOrder = .dateAscending
            onSettingsMenuChanged()
        }
        let sortOrderMenu = UIMenu(
            title: L10n.FileBrowser.sortOrder,
            options: [.displayInline, .singleSelection],
            children: [oldestFirstAction, newestFirstAction]
        )
        sortOrderMenu.preferredElementSize = .medium

        // レーティング機能 セクション（オンオフトグル）
        // チェックマークではなく、タイトルに現在の状態を括弧書きで示すトグル表現にする
        let ratingToggleAction = UIAction(
            title: L10n.FileBrowser.ratingFeatureTitle(isEnabled: viewModel.isRatingEnabled),
            image: UIImage(systemName: viewModel.isRatingEnabled ? "star.fill" : "star"),
            attributes: .keepsMenuPresented
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.isRatingEnabled.toggle()
            onRatingToggled()
        }
        let ratingMenu = UIMenu(
            title: "",
            options: .displayInline,
            children: [ratingToggleAction]
        )

        // PiP自動送り間隔 セクション
        let pipAutoAdvanceIntervalMenu = makePiPAutoAdvanceIntervalMenu()

        // キャッシュクリア セクション（最下部）
        let clearCacheAction = UIAction(
            title: L10n.FileBrowser.clearCache,
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.onClearCacheRequested()
        }
        let clearCacheMenu = UIMenu(
            title: "",
            options: .displayInline,
            children: [clearCacheAction]
        )

        return [viewModeMenu, columnCountMenu, sortOrderMenu, saveFormatMenu, ratingMenu, pipAutoAdvanceIntervalMenu, clearCacheMenu].compactMap { $0 }
    }

    /// グリッドの列数を増減するステッパー形式のメニューセクションを生成する
    private func makeColumnCountMenu() -> UIMenu {
        let count = viewModel.gridColumnCount
        let range = FileBrowserViewModel.gridColumnCountRange

        let decrementAction = UIAction(
            title: L10n.FileBrowser.columnCountDecrement,
            image: UIImage(systemName: "minus.circle"),
            attributes: count <= range.lowerBound ? [.disabled, .keepsMenuPresented] : .keepsMenuPresented
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.gridColumnCount = max(count - 1, range.lowerBound)
            onSettingsMenuChanged()
        }
        // 現在の列数表示（タップ不可）
        let currentAction = UIAction(
            title: L10n.FileBrowser.columnCountValue(count),
            image: UIImage(systemName: "\(count).square"),
            attributes: .disabled
        ) { _ in }
        let incrementAction = UIAction(
            title: L10n.FileBrowser.columnCountIncrement,
            image: UIImage(systemName: "plus.circle"),
            attributes: count >= range.upperBound ? [.disabled, .keepsMenuPresented] : .keepsMenuPresented
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.gridColumnCount = min(count + 1, range.upperBound)
            onSettingsMenuChanged()
        }

        let menu = UIMenu(
            title: L10n.FileBrowser.columnCount,
            options: .displayInline,
            children: [decrementAction, currentAction, incrementAction]
        )
        menu.preferredElementSize = .small
        return menu
    }

    /// PiP再生中の自動送り間隔を増減するステッパー形式のメニューセクションを生成する
    private func makePiPAutoAdvanceIntervalMenu() -> UIMenu {
        let seconds = viewModel.pipAutoAdvanceIntervalSeconds
        let range = FileBrowserViewModel.pipAutoAdvanceIntervalSecondsRange

        let decrementAction = UIAction(
            title: L10n.FileBrowser.pipAutoAdvanceIntervalDecrement,
            image: UIImage(systemName: "minus.circle"),
            attributes: seconds <= range.lowerBound ? [.disabled, .keepsMenuPresented] : .keepsMenuPresented
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.pipAutoAdvanceIntervalSeconds = max(seconds - 1, range.lowerBound)
            onSettingsMenuChanged()
        }
        let currentAction = UIAction(
            title: L10n.FileBrowser.pipAutoAdvanceIntervalValue(seconds),
            image: UIImage(systemName: "timer"),
            attributes: .disabled
        ) { _ in }
        let incrementAction = UIAction(
            title: L10n.FileBrowser.pipAutoAdvanceIntervalIncrement,
            image: UIImage(systemName: "plus.circle"),
            attributes: seconds >= range.upperBound ? [.disabled, .keepsMenuPresented] : .keepsMenuPresented
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.pipAutoAdvanceIntervalSeconds = min(seconds + 1, range.upperBound)
            onSettingsMenuChanged()
        }

        let menu = UIMenu(
            title: L10n.FileBrowser.pipAutoAdvanceInterval,
            options: .displayInline,
            children: [decrementAction, currentAction, incrementAction]
        )
        menu.preferredElementSize = .small
        return menu
    }
}
