import UIKit
import UniformTypeIdentifiers

nonisolated enum Section: Hashable, Sendable {
    case main
}

final class FileBrowserViewController: UIViewController {

    private let folderButtonSize: CGFloat = 56

    // MARK: - Properties

    private let viewModel = FileBrowserViewModel()
    private var dataSource: UICollectionViewDiffableDataSource<Section, FileItem.ID>!
    private var lastKnownHasFolder: Bool = false

    // MARK: - Folder Button Constraints

    private var folderButtonTrailingConstraint: NSLayoutConstraint!
    private var folderButtonWidthConstraint: NSLayoutConstraint!

    // MARK: - Views

    private lazy var collectionView: UICollectionView = {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = true
        let layout = UICollectionViewCompositionalLayout.list(using: config)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
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

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, URL> { cell, _, url in
            var config = cell.defaultContentConfiguration()
            config.image = UIImage(systemName: "photo")
            config.imageProperties.tintColor = .systemBlue
            config.text = url.lastPathComponent
            config.textProperties.lineBreakMode = .byTruncatingMiddle
            config.textProperties.numberOfLines = 1
            cell.contentConfiguration = config
        }

        dataSource = UICollectionViewDiffableDataSource<Section, FileItem.ID>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, id in
            guard let item = self?.viewModel.items.first(where: { $0.id == id }) else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item.url)
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, FileItem.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel.items.map(\.id), toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
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
