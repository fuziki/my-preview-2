import UIKit
import Core
import Localization

/// FileBrowserViewControllerの設定メニュー・フィルターメニューのUIMenuElement構築を担当する。
/// メニュー選択後の画面更新（BarButtonItemのmenu再代入・スナップショット再適用・アラート表示等）は
/// コールバック経由でFileBrowserViewControllerに委譲する。
final class FileBrowserMenuBuilder {

    private let viewModel: FileBrowserViewModel
    private let onSettingsMenuChanged: () -> Void
    private let onRatingToggled: () -> Void
    private let onFilterMenuChanged: () -> Void
    private let onClearCacheRequested: () -> Void

    init(
        viewModel: FileBrowserViewModel,
        onSettingsMenuChanged: @escaping () -> Void,
        onRatingToggled: @escaping () -> Void,
        onFilterMenuChanged: @escaping () -> Void,
        onClearCacheRequested: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onSettingsMenuChanged = onSettingsMenuChanged
        self.onRatingToggled = onRatingToggled
        self.onFilterMenuChanged = onFilterMenuChanged
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

        return [viewModeMenu, columnCountMenu, sortOrderMenu, saveFormatMenu, ratingMenu, clearCacheMenu].compactMap { $0 }
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

    // MARK: - フィルターメニュー

    /// フィルターメニューを生成する。UIDeferredMenuElement.uncached でメニュー表示のたびに最新状態を反映する。
    func makeFilterMenu() -> UIMenu {
        let deferred = UIDeferredMenuElement.uncached { [weak self] completion in
            completion(self?.buildFilterMenuElements() ?? [])
        }
        return UIMenu(title: "", children: [deferred])
    }

    private func buildFilterMenuElements() -> [UIMenuElement] {
        let current = viewModel.ratingFilter
        // 星・条件の選択時に引き継ぐベース値（フィルターなしの場合はデフォルト値）
        let base = current ?? RatingFilter(stars: 0, comparison: .atLeast)

        // フィルターなし（レーティング・カラーラベルの両方を解除）
        let offAction = UIAction(
            title: L10n.FileBrowser.ratingFilterOff,
            image: UIImage(systemName: "xmark.circle"),
            state: current == nil && viewModel.colorLabelFilter.isEmpty ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            viewModel.ratingFilter = nil
            viewModel.colorLabelFilter = []
            onFilterMenuChanged()
        }
        let offMenu = UIMenu(title: "", options: .displayInline, children: [offAction])

        // 星の数（0〜5）
        let starActions = RatingFilter.starsRange.map { stars in
            UIAction(
                title: L10n.FileBrowser.ratingFilterStarValue(stars),
                image: UIImage(systemName: stars == 0 ? "star.slash" : "star.fill"),
                attributes: .keepsMenuPresented,
                state: current?.stars == stars ? .on : .off
            ) { [weak self] _ in
                self?.applyRatingFilter(RatingFilter(stars: stars, comparison: base.comparison))
            }
        }
        let starsMenu = UIMenu(
            title: L10n.FileBrowser.ratingFilterStars,
            options: [.displayInline, .singleSelection],
            children: starActions
        )

        // 条件（以上・以下・同値）
        let comparisonData: [(RatingFilter.Comparison, String, String)] = [
            (.atLeast, L10n.FileBrowser.ratingFilterAtLeast, "greaterthanorequalto"),
            (.atMost, L10n.FileBrowser.ratingFilterAtMost, "lessthanorequalto"),
            (.exactly, L10n.FileBrowser.ratingFilterExactly, "equal"),
        ]
        let comparisonActions = comparisonData.map { comparison, title, imageName in
            UIAction(
                title: title,
                image: UIImage(systemName: imageName),
                attributes: .keepsMenuPresented,
                state: current?.comparison == comparison ? .on : .off
            ) { [weak self] _ in
                self?.applyRatingFilter(RatingFilter(stars: base.stars, comparison: comparison))
            }
        }
        let comparisonMenu = UIMenu(
            title: L10n.FileBrowser.ratingFilterComparison,
            options: [.displayInline, .singleSelection],
            children: comparisonActions
        )

        // カラーラベル（複数選択・0〜6個）
        let colorActions = PhotoColorLabel.allCases.map { label in
            UIAction(
                title: L10n.ColorLabel.name(forRawValue: label.rawValue),
                image: UIImage(systemName: "circle.fill")?
                    .withTintColor(label.uiColor, renderingMode: .alwaysOriginal),
                attributes: .keepsMenuPresented,
                state: viewModel.colorLabelFilter.contains(label) ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                var selection = viewModel.colorLabelFilter
                if selection.contains(label) {
                    selection.remove(label)
                } else {
                    selection.insert(label)
                }
                viewModel.colorLabelFilter = selection
                onFilterMenuChanged()
            }
        }
        let colorMenu = UIMenu(
            title: L10n.FileBrowser.colorLabel,
            options: .displayInline,
            children: colorActions
        )

        return [offMenu, starsMenu, comparisonMenu, colorMenu]
    }

    /// フィルターを適用する（BarButtonItem表示の更新はコールバック経由でVCに委譲する）
    private func applyRatingFilter(_ filter: RatingFilter?) {
        viewModel.ratingFilter = filter
        onFilterMenuChanged()
    }
}
