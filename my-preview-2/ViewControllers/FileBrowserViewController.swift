import UIKit
import UniformTypeIdentifiers

// MARK: - ViewMode

private enum ViewMode: String {
    case list, grid

    var toggled: ViewMode { self == .list ? .grid : .list }

    /// Icon shown on the toggle button (depicts what the *next* mode will be)
    var toggleButtonImage: UIImage? {
        switch self {
        case .list: return UIImage(systemName: "square.grid.2x2")
        case .grid: return UIImage(systemName: "list.bullet")
        }
    }
}

private extension UserDefaults {
    private static let viewModeKey = "FileBrowser.viewMode"

    var fileBrowserViewMode: ViewMode {
        get { ViewMode(rawValue: string(forKey: Self.viewModeKey) ?? "") ?? .list }
        set { set(newValue.rawValue, forKey: Self.viewModeKey) }
    }
}

// MARK: - Section

nonisolated enum Section: Hashable, Sendable {
    case date(String) // "yyyy-MM-dd" key used for sorting
}

// MARK: - FileBrowserViewController

final class FileBrowserViewController: UIViewController {

    private let folderButtonSize: CGFloat = 56

    // MARK: - Properties

    private let viewModel = FileBrowserViewModel()
    private var dataSource: UICollectionViewDiffableDataSource<Section, FileItem.ID>!
    private var lastKnownHasFolder: Bool = false

    private var viewMode: ViewMode = UserDefaults.standard.fileBrowserViewMode

    // Cell registrations — initialised in configureDataSource()
    private var listCellRegistration: UICollectionView.CellRegistration<UICollectionViewListCell, URL>!
    private var gridCellRegistration: UICollectionView.CellRegistration<ThumbnailCell, URL>!

    // MARK: - Date Formatters

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

    // MARK: - Folder Button Constraints

    private var folderButtonTrailingConstraint: NSLayoutConstraint!
    private var folderButtonWidthConstraint: NSLayoutConstraint!

    // MARK: - Views

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

    // MARK: - Lifecycle

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

    // MARK: - Setup

    private func setupViews() {
        view.backgroundColor = .systemBackground

        // Collection view (edge-to-edge)
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Empty state view
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Folder button with switchable constraints
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

        // Jump to bottom button (right side, same vertical position as folderButton)
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
        listCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, URL> { cell, _, url in
            var config = cell.defaultContentConfiguration()
            config.image = UIImage(systemName: "photo")
            config.imageProperties.tintColor = .systemBlue
            config.text = url.lastPathComponent
            config.textProperties.lineBreakMode = .byTruncatingMiddle
            config.textProperties.numberOfLines = 1
            cell.contentConfiguration = config
        }

        let thumbnailPixelSize = if let cellWidth = view.window?.windowScene?.screen.bounds.width,
           let scale = view.window?.windowScene?.screen.scale {
            min(400, Int(cellWidth * scale))
        } else {
            400
        }

        gridCellRegistration = UICollectionView.CellRegistration<ThumbnailCell, URL> { cell, _, url in
            cell.configure(with: url, thumbnailPixelSize: thumbnailPixelSize)
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, _, indexPath in
            guard let self else { return }
            let snapshot = self.dataSource.snapshot()
            guard indexPath.section < snapshot.sectionIdentifiers.count else { return }
            let section = snapshot.sectionIdentifiers[indexPath.section]
            if case .date(let dateKey) = section {
                headerView.configure(title: self.sectionTitle(for: dateKey))
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
        // Group items by date key while preserving sorted order
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

    // Format "yyyy-MM-dd" key into localized Japanese date string
    private func sectionTitle(for dateKey: String) -> String {
        if let date = sectionKeyFormatter.date(from: dateKey) {
            return sectionDisplayFormatter.string(from: date)
        }
        return dateKey
    }

    // MARK: - Layout Factories

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

    // MARK: - Observation

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
                self.updateEmptyState()
                if hasFolderChanged {
                    self.animateFolderButton(hasFolder: hasFolder)
                }
                self.startObservingItems()
            }
        }
    }

    // MARK: - UI Updates

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

    // MARK: - Actions

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

        // Update button icon
        navigationItem.rightBarButtonItem?.image = viewMode.toggleButtonImage

        // Switch layout (no animation to avoid cell-type mismatch glitch)
        collectionView.setCollectionViewLayout(makeLayout(for: viewMode), animated: false)

        // Force all cells to be recreated with the new registration
        var snapshot = dataSource.snapshot()
        snapshot.reloadItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension FileBrowserViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let selectedID = dataSource.itemIdentifier(for: indexPath) else { return }
        guard let selectedURL = viewModel.items.first(where: { $0.id == selectedID })?.url else { return }
        let allURLs = viewModel.items.map(\.url)

        let input = PhotoViewerInput(initialURL: selectedURL, allURLs: allURLs)
        let photoViewer = PhotoViewerViewController(input: input)
        photoViewer.modalPresentationStyle = .fullScreen
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(glassView)
        glassView.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            glassView.centerYAnchor.constraint(equalTo: centerYAnchor),
            glassView.heightAnchor.constraint(equalToConstant: 32),

            label.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor),

            glassView.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(title: String) {
        label.text = title
    }
}
