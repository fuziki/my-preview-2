import UIKit
import UniformTypeIdentifiers

nonisolated enum Section: Hashable, Sendable {
    case main
}

final class FileBrowserViewController: UIViewController {

    // MARK: - Properties

    private let viewModel = FileBrowserViewModel()
    private var dataSource: UICollectionViewDiffableDataSource<Section, FileItem.ID>!

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
        var config = UIButton.Configuration.borderless()
        config.image = UIImage(
            systemName: "folder.badge.plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        )
        config.baseForegroundColor = .label
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 28
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(openFolderPicker), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Preview"
        additionalSafeAreaInsets.bottom = 88
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

        // Folder button with glass effect
        let glassView = UIVisualEffectView(effect: UIGlassEffect())
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.isUserInteractionEnabled = false
        folderButton.insertSubview(glassView, at: 0)
        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: folderButton.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: folderButton.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: folderButton.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: folderButton.bottomAnchor),
        ])

        view.addSubview(folderButton)
        NSLayoutConstraint.activate([
            folderButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            folderButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            folderButton.widthAnchor.constraint(equalToConstant: 56),
            folderButton.heightAnchor.constraint(equalToConstant: 56),
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
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.applySnapshot()
                self?.startObservingItems()
            }
        }
    }

    // MARK: - updateProperties

    override func updateProperties() {
        super.updateProperties()
        let hasFolder = viewModel.hasFolder
        collectionView.isHidden = !hasFolder
        emptyStateView.isHidden = hasFolder
    }

    // MARK: - Actions

    @objc private func openFolderPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = self
        present(picker, animated: true)
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
