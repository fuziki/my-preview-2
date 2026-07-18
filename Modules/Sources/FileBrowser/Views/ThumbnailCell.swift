import UIKit
import Core

public final class ThumbnailCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        return iv
    }()

    // 「最後に表示」バッジのラベル
    private let lastViewedLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "最後に表示"
        label.textColor = .white
        label.font = .systemFont(ofSize: 9, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    // 「最後に表示」バッジの背景（半透明の黒帯）
    private let lastViewedBadge: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        v.isHidden = true
        return v
    }()

    // レーティングの星表示ラベル（左上・半透明の黒背景）
    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .systemYellow
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    private var loadingTask: Task<Void, Never>?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        contentView.addSubview(imageView)
        contentView.addSubview(lastViewedBadge)
        lastViewedBadge.addSubview(lastViewedLabel)
        contentView.addSubview(ratingLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            lastViewedBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            lastViewedBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            lastViewedBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            lastViewedLabel.topAnchor.constraint(equalTo: lastViewedBadge.topAnchor, constant: 3),
            lastViewedLabel.bottomAnchor.constraint(equalTo: lastViewedBadge.bottomAnchor, constant: -3),
            lastViewedLabel.leadingAnchor.constraint(equalTo: lastViewedBadge.leadingAnchor, constant: 4),
            lastViewedLabel.trailingAnchor.constraint(equalTo: lastViewedBadge.trailingAnchor, constant: -4),

            ratingLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            ratingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            ratingLabel.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    required public init?(coder: NSCoder) { fatalError() }

    override public func prepareForReuse() {
        super.prepareForReuse()
        loadingTask?.cancel()
        loadingTask = nil
        imageView.image = nil
        lastViewedBadge.isHidden = true
        ratingLabel.isHidden = true
    }

    public func configure(with url: URL, thumbnailPixelSize: Int, thumbnailService: any ThumbnailServiceProtocol) {
        // キャッシュヒット（同期）— フリッカーなし
        if let cached = thumbnailService.cachedThumbnail(for: url) {
            imageView.image = cached
            return
        }

        loadingTask = Task { @MainActor [weak self] in
            let image = await thumbnailService.loadThumbnail(url: url, maxPixelSize: thumbnailPixelSize)
            guard !Task.isCancelled, let self else { return }
            imageView.image = image
        }
    }

    /// 「最後に表示」バッジの表示状態を設定する
    public func setLastViewed(_ show: Bool) {
        lastViewedBadge.isHidden = !show
    }

    /// レーティングの星表示を設定する（星0は非表示）
    public func setRating(_ rating: Int) {
        guard rating > 0 else {
            ratingLabel.isHidden = true
            return
        }
        // 前後に余白を入れて黒背景のバッジ風に見せる
        ratingLabel.text = " " + String(repeating: "★", count: rating) + " "
        ratingLabel.isHidden = false
    }
}
