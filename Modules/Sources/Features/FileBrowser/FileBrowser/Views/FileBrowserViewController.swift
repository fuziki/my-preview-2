import UIKit
import UniformTypeIdentifiers
import Core
import Localization

// MARK: - FileBrowserViewController

public final class FileBrowserViewController: UIViewController {

    private let folderButtonSize: CGFloat = 56

    // MARK: - プロパティ

    private let viewModel: FileBrowserViewModel
    private var dataSource: UICollectionViewDiffableDataSource<FileBrowserSection.ID, FileItem.ID>!

    /// PhotoViewerViewControllerを生成するファクトリ。AppMainから注入される。
    /// FileBrowserモジュールはPhotoViewerモジュールに依存しないため、UIViewControllerとして受け取る。
    private let photoViewerFactory: (PhotoViewerInput) -> UIViewController

    /// フィルターのハーフモーダルを生成するファクトリ。AppMainから注入される。
    /// AppContainer側でFileBrowserFilterViewModelとFileBrowserFilterViewを組み立ててUIHostingControllerで包む。
    /// onChangeクロージャは呼び出し側（本クラス）で用意し、変更のたびにFileBrowserViewModelへ書き戻す。
    private let filterViewControllerFactory: (
        _ ratingFilter: RatingFilter?,
        _ colorLabelFilter: Set<PhotoColorLabel>,
        _ onChange: @escaping (RatingFilter?, Set<PhotoColorLabel>) -> Void
    ) -> UIViewController

    /// 詳細設定画面を生成するファクトリ。AppMainから注入される。
    /// AppContainer側でFileBrowserAdvancedSettingsViewModelとFileBrowserAdvancedSettingsViewを組み立ててUIHostingControllerで包む。
    /// 各onChangeクロージャは呼び出し側（本クラス）で用意し、変更のたびにFileBrowserViewModelへ書き戻す。
    private let advancedSettingsViewControllerFactory: (
        _ isRatingEnabled: Bool,
        _ pipAutoAdvanceIntervalSeconds: Int,
        _ onRatingEnabledChange: @escaping (Bool) -> Void,
        _ onPipAutoAdvanceIntervalSecondsChange: @escaping (Int) -> Void,
        _ onClearCacheRequested: @escaping () -> (isRatingEnabled: Bool, pipAutoAdvanceIntervalSeconds: Int)
    ) -> UIViewController

    private let thumbnailService: any ThumbnailServiceProtocol

    // セル登録 — configureDataSource() で初期化する
    private var listCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, URL>!
    private var gridCellRegistration: UICollectionView.CellRegistration<ThumbnailCell, URL>!

    // MARK: - 初期化

    public init(
        viewModel: FileBrowserViewModel,
        dependencies: FileBrowserDependencies,
        photoViewerFactory: @escaping (PhotoViewerInput) -> UIViewController,
        filterViewControllerFactory: @escaping (
            _ ratingFilter: RatingFilter?,
            _ colorLabelFilter: Set<PhotoColorLabel>,
            _ onChange: @escaping (RatingFilter?, Set<PhotoColorLabel>) -> Void
        ) -> UIViewController,
        advancedSettingsViewControllerFactory: @escaping (
            _ isRatingEnabled: Bool,
            _ pipAutoAdvanceIntervalSeconds: Int,
            _ onRatingEnabledChange: @escaping (Bool) -> Void,
            _ onPipAutoAdvanceIntervalSecondsChange: @escaping (Int) -> Void,
            _ onClearCacheRequested: @escaping () -> (isRatingEnabled: Bool, pipAutoAdvanceIntervalSeconds: Int)
        ) -> UIViewController
    ) {
        self.viewModel = viewModel
        self.thumbnailService = dependencies.thumbnailService
        self.photoViewerFactory = photoViewerFactory
        self.filterViewControllerFactory = filterViewControllerFactory
        self.advancedSettingsViewControllerFactory = advancedSettingsViewControllerFactory
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - フォルダボタン制約

    private var folderButtonTrailingConstraint: NSLayoutConstraint!
    private var folderButtonWidthConstraint: NSLayoutConstraint!

    // MARK: - ビュー

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout(for: viewModel.viewMode))
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.contentInsetAdjustmentBehavior = .automatic
        cv.delegate = self
        // ライト/ダークモードに関わらずスクロールバーを白色に固定する
        cv.indicatorStyle = .white
        return cv
    }()

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var folderButton: UIButton = {
        var config = UIButton.Configuration.prominentGlass()
        config.image = UIImage(systemName: "folder")
        config.title = L10n.FileBrowser.openFolder
        config.imagePlacement = .leading
        config.imagePadding = 8
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openFolderPicker), for: .touchUpInside)
        return button
    }()

    private lazy var jumpToBottomButton: UIButton = {
        var config = UIButton.Configuration.glass()
        config.image = UIImage(systemName: "chevron.down")
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alpha = 0
        button.addTarget(self, action: #selector(jumpToBottom), for: .touchUpInside)
        return button
    }()

    // MARK: - ライフサイクル

    override public func viewDidLoad() {
        super.viewDidLoad()
        title = "My Preview"
        additionalSafeAreaInsets.bottom = folderButtonSize + 32
        setupViews()
        setupNavigationBar()
        configureDataSource()
        applySnapshot()
        startObservingItems()
        startObservingViewMode()
    }

    // MARK: - セットアップ

    private func setupViews() {
        view.backgroundColor = .systemBackground

        // コレクションビュー（全面表示）
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 空状態ビュー
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 切り替え可能な制約付きフォルダボタン
        view.addSubview(folderButton)

        let trailingConstraint = folderButton.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16
        )
        let widthConstraint = folderButton.widthAnchor.constraint(equalToConstant: folderButtonSize)
        widthConstraint.isActive = false

        NSLayoutConstraint.activate([
            folderButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            trailingConstraint,
            folderButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: folderButtonSize),
            folderButton.heightAnchor.constraint(equalToConstant: folderButtonSize),
        ])

        folderButtonTrailingConstraint = trailingConstraint
        folderButtonWidthConstraint = widthConstraint

        // 下部へジャンプボタン（右側、folderButtonと同じ垂直位置）
        view.addSubview(jumpToBottomButton)
        NSLayoutConstraint.activate([
            jumpToBottomButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            jumpToBottomButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: folderButtonSize),
            jumpToBottomButton.widthAnchor.constraint(equalToConstant: folderButtonSize),
            jumpToBottomButton.heightAnchor.constraint(equalToConstant: folderButtonSize),
        ])
    }

    // MARK: - ナビゲーションバーアイテム

    /// 設定・フィルターメニューのUIMenuElement構築を担当する。選択後の画面更新はコールバック経由で受け取る。
    private lazy var menuBuilder = FileBrowserMenuBuilder(
        viewModel: viewModel,
        onSettingsMenuChanged: { [weak self] in self?.refreshSettingsMenu() },
        onAdvancedSettingsRequested: { [weak self] in self?.pushAdvancedSettings() }
    )

    private lazy var settingsBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "gear"),
        menu: menuBuilder.makeSettingsMenu()
    )

    private lazy var filterBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
        primaryAction: UIAction { [weak self] _ in self?.presentFilterSheet() }
    )

    private func setupNavigationBar() {
        updateNavigationBarItems()
    }

    /// レーティング設定に応じてフィルターボタン（設定ボタンの左）の表示を切り替える
    private func updateNavigationBarItems() {
        if viewModel.isRatingEnabled {
            navigationItem.rightBarButtonItems = [settingsBarButtonItem, filterBarButtonItem]
        } else {
            navigationItem.rightBarButtonItems = [settingsBarButtonItem]
        }
        updateFilterButtonAppearance()
    }

    /// フィルター（レーティング・カラーラベルのいずれか）適用中はアイコンを塗りつぶし表示にする
    private func updateFilterButtonAppearance() {
        let isActive = viewModel.ratingFilter != nil || !viewModel.colorLabelFilter.isEmpty
        let name = isActive
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        filterBarButtonItem.image = UIImage(systemName: name)
    }

    /// アクション選択後、keepsMenuPresented でメニューが開いたままの状態でも
    /// チェックマークを更新するため、menu プロパティを再代入して再評価させる。
    private func refreshSettingsMenu() {
        settingsBarButtonItem.menu = menuBuilder.makeSettingsMenu()
    }

    /// フィルター設定をハーフモーダルで表示する。
    /// 画面（ViewModel・SwiftUI View・UIHostingController）の生成はAppContainer経由のfactoryへ委譲し、
    /// 変更のたびに呼ばれるonChangeでFileBrowserViewModelへ書き戻す。
    private func presentFilterSheet() {
        let filterViewController = filterViewControllerFactory(
            viewModel.ratingFilter,
            viewModel.colorLabelFilter
        ) { [weak self] ratingFilter, colorLabelFilter in
            guard let self else { return }
            viewModel.ratingFilter = ratingFilter
            viewModel.colorLabelFilter = colorLabelFilter
        }
        if let sheet = filterViewController.sheetPresentationController {
            // 固定のhalf detentではなく、コンテンツの理想の高さにフィットさせる（Core共通実装）
            sheet.detents = [filterViewController.contentFittingSheetDetent(presentingViewWidth: view.bounds.width)]
            // ダイミングビューを外し、シート表示中も裏のファイルリストを操作できるようにする
            sheet.largestUndimmedDetentIdentifier = .contentFitting
            sheet.delegate = self
        }
        present(filterViewController, animated: true)
    }

    /// 詳細設定画面をpushで表示する。
    /// 画面（ViewModel・SwiftUI View・UIHostingController）の生成はAppContainer経由のfactoryへ委譲し、
    /// 変更のたびに呼ばれる各クロージャでFileBrowserViewModelへ書き戻す。
    private func pushAdvancedSettings() {
        let advancedSettingsViewController = advancedSettingsViewControllerFactory(
            viewModel.isRatingEnabled,
            viewModel.pipAutoAdvanceIntervalSeconds,
            { [weak self] isRatingEnabled in
                guard let self else { return }
                viewModel.isRatingEnabled = isRatingEnabled
                updateNavigationBarItems()
                applySnapshot(reconfiguringAllItems: true)
                refreshSettingsMenu()
            },
            { [weak self] seconds in
                self?.viewModel.pipAutoAdvanceIntervalSeconds = seconds
            },
            { [weak self] in
                guard let self else {
                    let defaults = UserDefaultsSettings.default()
                    return (defaults.isRatingEnabled, defaults.pipAutoAdvanceIntervalSeconds)
                }
                viewModel.resetToDefaults()
                updateNavigationBarItems()
                applySnapshot(reconfiguringAllItems: true)
                refreshSettingsMenu()
                return (viewModel.isRatingEnabled, viewModel.pipAutoAdvanceIntervalSeconds)
            }
        )
        navigationController?.pushViewController(advancedSettingsViewController, animated: true)
    }

    private func configureDataSource() {
        listCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, URL> { [weak self] cell, _, url in
            var config = cell.defaultContentConfiguration()
            config.image = UIImage(systemName: "photo")
            config.imageProperties.tintColor = .systemBlue
            config.text = url.lastPathComponent
            config.textProperties.lineBreakMode = .byTruncatingMiddle
            config.textProperties.numberOfLines = 1

            // レーティング（星1以上）・カラーラベル・最後に閲覧をセカンダリ行で表示する
            let caption = UIFont.preferredFont(forTextStyle: .caption1)
            var secondaryParts: [NSAttributedString] = []
            if let s = self, s.viewModel.isRatingEnabled {
                let rating = s.viewModel.rating(for: url)
                if rating > 0 {
                    secondaryParts.append(NSAttributedString(
                        string: String(repeating: "★", count: rating),
                        attributes: [.font: caption, .foregroundColor: UIColor.secondaryLabel]
                    ))
                }
                if let label = s.viewModel.colorLabel(for: url) {
                    // 白ラベルは背景に紛れるため縁取りを付ける（負のstrokeWidthは塗り+縁取り）
                    var attributes: [NSAttributedString.Key: Any] = [
                        .font: caption, .foregroundColor: label.uiColor,
                    ]
                    if label == .white {
                        attributes[.strokeColor] = UIColor.systemGray3
                        attributes[.strokeWidth] = -3.0
                    }
                    secondaryParts.append(NSAttributedString(string: "●", attributes: attributes))
                }
            }
            let isLastViewed = self.map { s in
                s.viewModel.items.first(where: { $0.url == url })?.id == s.viewModel.lastViewedItemID
            } ?? false
            if isLastViewed {
                secondaryParts.append(NSAttributedString(
                    string: L10n.FileBrowser.jumpToLastViewed,
                    attributes: [.font: caption, .foregroundColor: UIColor.systemBlue]
                ))
            }
            if secondaryParts.isEmpty {
                config.secondaryAttributedText = nil
            } else {
                let joined = NSMutableAttributedString()
                for (index, part) in secondaryParts.enumerated() {
                    if index > 0 {
                        joined.append(NSAttributedString(
                            string: " · ",
                            attributes: [.font: caption, .foregroundColor: UIColor.secondaryLabel]
                        ))
                    }
                    joined.append(part)
                }
                config.secondaryAttributedText = joined
            }

            cell.contentConfiguration = config
        }

        // サムネイルのピクセルサイズを画面解像度から算出する
        let thumbnailPixelSize = if let cellWidth = view.window?.windowScene?.screen.bounds.width,
           let scale = view.window?.windowScene?.screen.scale {
            min(400, Int(cellWidth * scale))
        } else {
            400
        }

        gridCellRegistration = UICollectionView.CellRegistration<ThumbnailCell, URL> { [weak self, thumbnailService = thumbnailService] cell, _, url in
            cell.configure(with: url, thumbnailPixelSize: thumbnailPixelSize, thumbnailService: thumbnailService)

            // 最後に閲覧したアイテムにバッジを付ける
            let isLastViewed = self.map { s in
                s.viewModel.items.first(where: { $0.url == url })?.id == s.viewModel.lastViewedItemID
            } ?? false
            cell.setLastViewed(isLastViewed)

            // レーティング（星1以上）のバッジを付ける
            let rating = self.map { s in
                s.viewModel.isRatingEnabled ? s.viewModel.rating(for: url) : 0
            } ?? 0
            cell.setRating(rating)

            // カラーラベルのドットを付ける
            let colorLabel = self.flatMap { s in
                s.viewModel.isRatingEnabled ? s.viewModel.colorLabel(for: url) : nil
            }
            cell.setColorLabel(colorLabel)
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, _, indexPath in
            guard let self else { return }
            let snapshot = self.dataSource.snapshot()
            guard indexPath.section < snapshot.sectionIdentifiers.count else { return }
            let sectionID = snapshot.sectionIdentifiers[indexPath.section]
            guard let section = viewModel.section(for: sectionID) else { return }

            let title = L10n.FileBrowser.sectionTitleWithCount(viewModel.sectionTitle(for: sectionID), section.items.count)
            headerView.configure(title: title) { [weak self] in
                guard let self else { return [] }
                let (showsLastViewed, sections) = viewModel.makeMenuData()
                var actions: [UIMenuElement] = []

                if showsLastViewed {
                    let action = UIAction(title: L10n.FileBrowser.jumpToLastViewed) { [weak self] _ in
                        self?.jumpToLastViewed()
                    }
                    actions.append(action)
                }

                let sectionActions = sections.map { (id, title) in
                    UIAction(title: title) { [weak self] _ in
                        self?.jumpToSection(id)
                    }
                }
                actions.append(contentsOf: sectionActions)
                return actions
            }
        }

        dataSource = UICollectionViewDiffableDataSource<FileBrowserSection.ID, FileItem.ID>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, id in
            guard let self,
                  let item = viewModel.items.first(where: { $0.id == id }) else { return nil }
            switch viewModel.viewMode {
            case .list:
                return collectionView.dequeueConfiguredReusableCell(
                    using: listCellRegistration, for: indexPath, item: item.url)
            case .grid:
                return collectionView.dequeueConfiguredReusableCell(
                    using: gridCellRegistration, for: indexPath, item: item.url)
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            guard kind == UICollectionView.elementKindSectionHeader else { return nil }
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    private func applySnapshot(reconfiguringAllItems: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<FileBrowserSection.ID, FileItem.ID>()
        for section in viewModel.sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.items.map(\.id), toSection: section.id)
        }
        if reconfiguringAllItems {
            // レーティング変更など、既存セルの表示内容が変わった可能性がある場合に全セルを再設定する
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        }
        // 異なるフォルダ間で同じ日付キーのセクションIDが再利用されると、
        // 枚数が変わってもヘッダーViewが使い回されて古い枚数のまま表示され続けるため、毎回強制的に再構成する
        snapshot.reloadSections(snapshot.sectionIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - レイアウトファクトリ

    private func makeLayout(for mode: ViewMode) -> UICollectionViewLayout {
        mode == .grid ? .fileBrowserGrid(columnCount: viewModel.gridColumnCount) : .fileBrowserList()
    }

    // MARK: - 監視

    private func startObservingItems() {
        withObservationTracking {
            _ = viewModel.sections
            _ = viewModel.hasFolder
            _ = viewModel.isLoading
            _ = viewModel.folderName
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let hasFolderChanged = viewModel.consumeHasFolderChanged()
                self.applySnapshot()
                self.updateEmptyState()
                if hasFolderChanged {
                    self.animateFolderButton(hasFolder: viewModel.hasFolder)
                }
                self.title = viewModel.folderName ?? "My Preview"
                self.startObservingItems()
            }
        }
    }

    // viewModeと列数の変化を独立して監視し、レイアウトを更新する
    private func startObservingViewMode() {
        withObservationTracking {
            _ = viewModel.viewMode
            _ = viewModel.gridColumnCount
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyViewMode(viewModel.viewMode)
                self.startObservingViewMode()
            }
        }
    }

    // MARK: - UI更新

    private func updateEmptyState() {
        let hasFolder = viewModel.hasFolder
        let isLoading = viewModel.isLoading
        let hasItems = !viewModel.items.isEmpty

        let showList = hasFolder && !isLoading && hasItems
        collectionView.isHidden = !showList
        emptyStateView.isHidden = showList

        if !hasFolder {
            emptyStateView.configure(state: .noFolder)
        } else if isLoading {
            emptyStateView.configure(state: .loading)
        } else if viewModel.isFilterActive {
            emptyStateView.configure(state: .noMatchingPhotos)
        } else {
            emptyStateView.configure(state: .noPhotos)
        }
    }

    private func animateFolderButton(hasFolder: Bool) {
        if hasFolder {
            var config = UIButton.Configuration.prominentGlass()
            config.image = UIImage(systemName: "folder")
            folderButton.configuration = config

            folderButtonTrailingConstraint.isActive = false
            folderButtonWidthConstraint.isActive = true
        } else {
            var config = UIButton.Configuration.prominentGlass()
            config.image = UIImage(systemName: "folder")
            config.title = L10n.FileBrowser.openFolder
            config.imagePlacement = .leading
            config.imagePadding = 8
            folderButton.configuration = config

            folderButtonWidthConstraint.isActive = false
            folderButtonTrailingConstraint.isActive = true
        }

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: []) {
            self.view.layoutIfNeeded()
            self.jumpToBottomButton.alpha = hasFolder ? 1 : 0
        }
    }

    // MARK: - updateProperties

    override public func updateProperties() {
        super.updateProperties()
        updateEmptyState()
    }

    // MARK: - アクション

    @objc private func openFolderPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func jumpToBottom() {
        let lastSection = collectionView.numberOfSections - 1
        guard lastSection >= 0 else { return }
        let lastItem = collectionView.numberOfItems(inSection: lastSection) - 1
        guard lastItem >= 0 else { return }
        collectionView.scrollToItem(at: IndexPath(item: lastItem, section: lastSection), at: .bottom, animated: true)
    }

    // MARK: - 設定同期

    private func applyViewMode(_ mode: ViewMode) {
        // レイアウトを切り替える（セルタイプ不一致のグリッチを避けるためアニメーションなし）
        collectionView.setCollectionViewLayout(makeLayout(for: mode), animated: false)

        // すべてのセルを新しい登録で再作成する
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - セクションジャンプ

    private func jumpToSection(_ sectionID: FileBrowserSection.ID) {
        let snapshot = dataSource.snapshot()
        guard let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: sectionID) else { return }
        guard collectionView.numberOfItems(inSection: sectionIndex) > 0 else { return }
        collectionView.scrollToItem(
            at: IndexPath(item: 0, section: sectionIndex),
            at: .top,
            animated: true
        )
    }

    private func jumpToLastViewed() {
        guard let lastViewedID = viewModel.lastViewedItemID,
              let indexPath = dataSource.indexPath(for: lastViewedID) else { return }
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
    }

    // MARK: - ズームトランジション用ヘルパー

    /// 指定URLに対応するセルのビューを返す。
    /// セルが画面外の場合は先にスクロールして可視範囲に収める（閉じるアニメーションの戻り先として使用）。
    private func cellViewForURL(_ url: URL) -> UIView? {
        guard let item = viewModel.items.first(where: { $0.url == url }),
              let indexPath = dataSource.indexPath(for: item.id) else { return nil }

        // セルがまだ可視でない場合はスクロールして可視範囲に入れる（アニメーションなし）
        let visiblePaths = collectionView.indexPathsForVisibleItems
        if !visiblePaths.contains(indexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            collectionView.layoutIfNeeded()
        }

        return collectionView.cellForItem(at: indexPath)
    }
}

// MARK: - UICollectionViewDelegate

extension FileBrowserViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)

        guard let selectedID = dataSource.itemIdentifier(for: indexPath),
              let selectedItem = viewModel.items.first(where: { $0.id == selectedID }) else { return }
        let allURLs = viewModel.items.map(\.url)

        let input = PhotoViewerInput(
            initialURL: selectedItem.url,
            allURLs: allURLs,
            isRatingEnabled: viewModel.isRatingEnabled,
            ratingFilter: viewModel.ratingFilter,
            colorLabelFilter: viewModel.colorLabelFilter
        )
        let photoViewer = photoViewerFactory(input)

        // ステータスバーの制御をPhotoViewerViewControllerに委譲する
        photoViewer.modalPresentationCapturesStatusBarAppearance = true

        // セルからズームイン/アウトするトランジションを設定する。
        // sourceViewProviderは表示時と閉じる時に呼ばれる。
        // photoViewer.currentURLは常に現在表示中のURLを返すため、両タイミングで正しいセルを指す。
        photoViewer.preferredTransition = .zoom { [weak self, weak photoViewer] _ in
            guard let self, let photoViewer else { return nil }
            guard let currentURLProvider = photoViewer as? CurrentURLProvider else { return nil }
            return self.cellViewForURL(currentURLProvider.currentURL)
        }

        // 閉じる時: 最後に表示したアイテムを記録し、レーティング変更を反映してセルを更新する
        if var dismissable = photoViewer as? DismissNotifiable {
            dismissable.onDismiss = { [weak self] currentURL in
                guard let self else { return }
                // ファイル名をViewModelを通じてUserDefaultsに永続化し、lastViewedItemIDも更新する
                viewModel.saveLastViewed(url: currentURL)
                // ビューアー内でレーティング・カラーラベルが変更された可能性があるため、
                // ストアから再読み込みしてフィルタ適用済みセクションと全セルを更新する
                viewModel.refreshRatingsAndLabels()
                applySnapshot(reconfiguringAllItems: true)
            }
        }

        present(photoViewer, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension FileBrowserViewController: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        Task { await viewModel.selectFolder(url) }
    }
}

// MARK: - UISheetPresentationControllerDelegate

extension FileBrowserViewController: UISheetPresentationControllerDelegate {
    // フィルターのハーフモーダルを閉じたタイミングでフィルターボタンの塗りつぶし状態を最新化する
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        updateFilterButtonAppearance()
    }
}
