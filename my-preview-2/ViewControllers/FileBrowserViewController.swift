import UIKit
import UniformTypeIdentifiers

// MARK: - ViewMode

private enum ViewMode: String {
    case list, grid

    var toggled: ViewMode { self == .list ? .grid : .list }

    /// トグルボタンに表示するアイコン（次のモードを示す）
    var toggleButtonImage: UIImage? {
        switch self {
        case .list: return UIImage(systemName: "square.grid.2x2")
        case .grid: return UIImage(systemName: "list.bullet")
        }
    }
}

private extension UserDefaults {
    private static let viewModeKey = "FileBrowser.viewMode"
    private static let lastViewedFileNameKey = "FileBrowser.lastViewedFileName"

    var fileBrowserViewMode: ViewMode {
        get { ViewMode(rawValue: string(forKey: Self.viewModeKey) ?? "") ?? .list }
        set { set(newValue.rawValue, forKey: Self.viewModeKey) }
    }

    var fileBrowserLastViewedFileName: String? {
        get { string(forKey: Self.lastViewedFileNameKey) }
        set { set(newValue, forKey: Self.lastViewedFileNameKey) }
    }
}

// MARK: - Section

nonisolated enum Section: Hashable, Sendable {
    case date(String) // ソートキーとして使用する "yyyy-MM-dd" 形式の文字列
}

// MARK: - FileBrowserViewController

final class FileBrowserViewController: UIViewController {

    private let folderButtonSize: CGFloat = 56

    // MARK: - プロパティ

    private let viewModel: FileBrowserViewModel
    private var dataSource: UICollectionViewDiffableDataSource<Section, FileItem.ID>!
    private var lastKnownHasFolder: Bool = false

    private var viewMode: ViewMode = UserDefaults.standard.fileBrowserViewMode

    // PhotoViewerServicesをすべてのフォトビューア間で共有する（SavedDateStoreは写真閲覧をまたいで保存日時を保持する）
    private let savedDateStore: any SavedDateStoreProtocol = SavedDateStore()
    private lazy var photoViewerServices = PhotoViewerServices.production(savedDateStore: savedDateStore)

    /// 最後に閲覧していたアイテムのID（「最後に表示」バッジの表示に使用する）
    private var lastViewedItemID: FileItem.ID?

    // セル登録 — configureDataSource() で初期化する
    private var listCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, URL>!
    private var gridCellRegistration: UICollectionView.CellRegistration<ThumbnailCell, URL>!

    // MARK: - 初期化

    init(fileSystemService: any FileSystemServiceProtocol) {
        viewModel = FileBrowserViewModel(fileSystemService: fileSystemService)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 日付フォーマッタ

    private lazy var sectionKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private lazy var sectionDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    // MARK: - フォルダボタン制約

    private var folderButtonTrailingConstraint: NSLayoutConstraint!
    private var folderButtonWidthConstraint: NSLayoutConstraint!

    // MARK: - ビュー

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout(for: viewMode))
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.contentInsetAdjustmentBehavior = .automatic
        cv.delegate = self
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
        config.title = "フォルダを開く"
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

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Preview"
        additionalSafeAreaInsets.bottom = folderButtonSize + 32
        setupViews()
        setupNavigationBar()
        configureDataSource()
        applySnapshot()
        startObservingItems()
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

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: viewMode.toggleButtonImage,
            style: .plain,
            target: self,
            action: #selector(toggleViewMode)
        )
    }

    private func configureDataSource() {
        listCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, URL> { [weak self] cell, _, url in
            var config = cell.defaultContentConfiguration()
            config.image = UIImage(systemName: "photo")
            config.imageProperties.tintColor = .systemBlue
            config.text = url.lastPathComponent
            config.textProperties.lineBreakMode = .byTruncatingMiddle
            config.textProperties.numberOfLines = 1

            // 最後に閲覧したアイテムにセカンダリテキストを付ける
            let isLastViewed = self.map { s in
                s.viewModel.items.first(where: { $0.url == url })?.id == s.lastViewedItemID
            } ?? false
            config.secondaryText = isLastViewed ? "最後に表示" : nil
            config.secondaryTextProperties.color = .systemBlue
            config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)

            cell.contentConfiguration = config
        }

        // サムネイルのピクセルサイズを画面解像度から算出する
        let thumbnailPixelSize = if let cellWidth = view.window?.windowScene?.screen.bounds.width,
           let scale = view.window?.windowScene?.screen.scale {
            min(400, Int(cellWidth * scale))
        } else {
            400
        }

        gridCellRegistration = UICollectionView.CellRegistration<ThumbnailCell, URL> { [weak self] cell, _, url in
            cell.configure(with: url, thumbnailPixelSize: thumbnailPixelSize)

            // 最後に閲覧したアイテムにバッジを付ける
            let isLastViewed = self.map { s in
                s.viewModel.items.first(where: { $0.url == url })?.id == s.lastViewedItemID
            } ?? false
            cell.setLastViewed(isLastViewed)
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, _, indexPath in
            guard let self else { return }
            let snapshot = self.dataSource.snapshot()
            guard indexPath.section < snapshot.sectionIdentifiers.count else { return }
            let section = snapshot.sectionIdentifiers[indexPath.section]
            guard case .date(let dateKey) = section else { return }

            // menuProvider クロージャはメニュー表示のたびに呼ばれる（UIDeferredMenuElement.uncached による）
            headerView.configure(title: self.sectionTitle(for: dateKey)) { [weak self] in
                guard let self else { return [] }
                let snapshot = self.dataSource.snapshot()
                var actions: [UIMenuElement] = []

                // 「最後に表示」アクションをメニュー先頭に追加する
                if let lastViewedID = self.lastViewedItemID,
                   snapshot.itemIdentifiers.contains(lastViewedID) {
                    let action = UIAction(
                        title: "最後に表示",
                        image: UIImage(systemName: "eye")
                    ) { [weak self] _ in
                        self?.jumpToLastViewed()
                    }
                    actions.append(action)
                }

                // 全セクションをジャンプアクションとして追加する
                let sectionActions = snapshot.sectionIdentifiers.compactMap { sec -> UIAction? in
                    guard case .date(let key) = sec else { return nil }
                    return UIAction(title: self.sectionTitle(for: key)) { [weak self] _ in
                        self?.jumpToSection(sec)
                    }
                }
                actions.append(contentsOf: sectionActions)
                return actions
            }
        }

        dataSource = UICollectionViewDiffableDataSource<Section, FileItem.ID>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, id in
            guard let self,
                  let item = viewModel.items.first(where: { $0.id == id }) else { return nil }
            switch viewMode {
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

    private func applySnapshot() {
        // ソート順を維持しながら日付キーでアイテムをグループ化する
        var dateMap: [String: [FileItem.ID]] = [:]
        var dateOrder: [String] = []

        for item in viewModel.items {
            let date = item.captureDate ?? Date.distantFuture
            let key = sectionKeyFormatter.string(from: date)
            if dateMap[key] == nil {
                dateOrder.append(key)
                dateMap[key] = []
            }
            dateMap[key]!.append(item.id)
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, FileItem.ID>()
        for key in dateOrder {
            let section = Section.date(key)
            snapshot.appendSections([section])
            snapshot.appendItems(dateMap[key]!, toSection: section)
        }
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // "yyyy-MM-dd" キーをローカライズされた日本語日付文字列に変換する
    private func sectionTitle(for dateKey: String) -> String {
        if let date = sectionKeyFormatter.date(from: dateKey) {
            return sectionDisplayFormatter.string(from: date)
        }
        return dateKey
    }

    // MARK: - レイアウトファクトリ

    private func makeLayout(for mode: ViewMode) -> UICollectionViewLayout {
        mode == .grid ? makeGridLayout() : makeListLayout()
    }

    private func makeListLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, layoutEnvironment in
            var listConfig = UICollectionLayoutListConfiguration(appearance: .plain)
            listConfig.showsSeparators = true
            let section = NSCollectionLayoutSection.list(using: listConfig, layoutEnvironment: layoutEnvironment)

            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(44)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            header.pinToVisibleBounds = true
            section.boundarySupplementaryItems = [header]

            return section
        }
    }

    private func makeGridLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1 / 3),
                heightDimension: .fractionalWidth(1 / 3)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalWidth(1 / 3)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize, subitems: [item, item, item]
            )

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)

            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(44)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            header.pinToVisibleBounds = true
            section.boundarySupplementaryItems = [header]

            return section
        }
    }

    // MARK: - 監視

    private func startObservingItems() {
        withObservationTracking {
            _ = viewModel.items
            _ = viewModel.hasFolder
            _ = viewModel.isLoading
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let hasFolder = self.viewModel.hasFolder
                let hasFolderChanged = hasFolder != self.lastKnownHasFolder
                self.lastKnownHasFolder = hasFolder
                self.applySnapshot()
                self.restoreLastViewedItemIfNeeded()
                self.updateEmptyState()
                if hasFolderChanged {
                    self.animateFolderButton(hasFolder: hasFolder)
                }
                self.startObservingItems()
            }
        }
    }

    /// UserDefaultsに保存されたファイル名からlastViewedItemIDを復元する。
    /// すでに設定済みの場合、またはアイテムが空の場合は何もしない。
    private func restoreLastViewedItemIfNeeded() {
        guard lastViewedItemID == nil,
              let fileName = UserDefaults.standard.fileBrowserLastViewedFileName,
              let item = viewModel.items.first(where: { $0.name == fileName }) else { return }
        lastViewedItemID = item.id
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
            config.title = "フォルダを開く"
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

    override func updateProperties() {
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

    @objc private func toggleViewMode() {
        viewMode = viewMode.toggled
        UserDefaults.standard.fileBrowserViewMode = viewMode

        // ボタンアイコンを更新する
        navigationItem.rightBarButtonItem?.image = viewMode.toggleButtonImage

        // レイアウトを切り替える（セルタイプ不一致のグリッチを避けるためアニメーションなし）
        collectionView.setCollectionViewLayout(makeLayout(for: viewMode), animated: false)

        // すべてのセルを新しい登録で再作成する
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - セクションジャンプ

    private func jumpToSection(_ section: Section) {
        let snapshot = dataSource.snapshot()
        guard let sectionIndex = snapshot.sectionIdentifiers.firstIndex(of: section) else { return }
        guard collectionView.numberOfItems(inSection: sectionIndex) > 0 else { return }
        collectionView.scrollToItem(
            at: IndexPath(item: 0, section: sectionIndex),
            at: .top,
            animated: true
        )
    }

    private func jumpToLastViewed() {
        guard let lastViewedID = lastViewedItemID,
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
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)

        guard let selectedID = dataSource.itemIdentifier(for: indexPath),
              let selectedItem = viewModel.items.first(where: { $0.id == selectedID }) else { return }
        let allURLs = viewModel.items.map(\.url)

        let input = PhotoViewerInput(initialURL: selectedItem.url, allURLs: allURLs)
        let photoViewer = PhotoViewerViewController(input: input, services: photoViewerServices)

        // ステータスバーの制御をPhotoViewerViewControllerに委譲する
        photoViewer.modalPresentationCapturesStatusBarAppearance = true

        // セルからズームイン/アウトするトランジションを設定する。
        // sourceViewProviderは表示時と閉じる時に呼ばれる。
        // photoViewer.currentURLは常に現在表示中のURLを返すため、両タイミングで正しいセルを指す。
        photoViewer.preferredTransition = .zoom { [weak self, weak photoViewer] _ in
            guard let self, let photoViewer else { return nil }
            return self.cellViewForURL(photoViewer.currentURL)
        }

        // 閉じる時: 最後に表示したアイテムを記録してセルを更新する
        photoViewer.onDismiss = { [weak self] currentURL in
            guard let self else { return }
            let newItemID = self.viewModel.items.first(where: { $0.url == currentURL })?.id
            let oldItemID = self.lastViewedItemID
            self.lastViewedItemID = newItemID
            // ファイル名をUserDefaultsに永続化する（起動をまたいで最後に表示を復元するため）
            UserDefaults.standard.fileBrowserLastViewedFileName = currentURL.lastPathComponent

            // 変化のあったセルのみを再設定する（不要な再描画を避けるため）
            var snapshot = self.dataSource.snapshot()
            var toReconfigure: [FileItem.ID] = []
            if let old = oldItemID, snapshot.itemIdentifiers.contains(old) {
                toReconfigure.append(old)
            }
            if let new = newItemID, new != oldItemID, snapshot.itemIdentifiers.contains(new) {
                toReconfigure.append(new)
            }
            if !toReconfigure.isEmpty {
                snapshot.reconfigureItems(toReconfigure)
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }

        present(photoViewer, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension FileBrowserViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        Task { await viewModel.selectFolder(url) }
    }
}

// MARK: - SectionHeaderView

private final class SectionHeaderView: UICollectionReusableView {

    private let glassView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIGlassEffect())
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 16
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        return v
    }()

    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .preferredFont(forTextStyle: .subheadline)
        l.textColor = .label
        return l
    }()

    // 日付ジャンプが可能であることを示すシェブロンアイコン
    private let chevronImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .secondaryLabel
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    // ガラスビューの前面に重ねる透明タッチ領域。タップ時にコンテキストメニューを表示する。
    private let menuButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(glassView)
        glassView.contentView.addSubview(label)
        glassView.contentView.addSubview(chevronImageView)
        addSubview(menuButton)  // ガラスビューの前面に配置

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            glassView.centerYAnchor.constraint(equalTo: centerYAnchor),
            glassView.heightAnchor.constraint(equalToConstant: 32),

            label.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -6),

            chevronImageView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -10),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12),

            glassView.trailingAnchor.constraint(equalTo: chevronImageView.trailingAnchor, constant: 10),

            // menuButtonをglassViewと同じ範囲に重ねる
            menuButton.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
            menuButton.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
            menuButton.topAnchor.constraint(equalTo: glassView.topAnchor),
            menuButton.bottomAnchor.constraint(equalTo: glassView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(title: String, menuProvider: @escaping () -> [UIMenuElement]) {
        label.text = title
        // UIDeferredMenuElement.uncached を使うことで、メニューが表示されるたびに
        // menuProvider が呼ばれ、常に最新の内容が反映される
        let deferred = UIDeferredMenuElement.uncached { completion in
            completion(menuProvider())
        }
        menuButton.menu = UIMenu(title: "", children: [deferred])
    }
}
