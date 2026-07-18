import UIKit

/// glass effect のカプセル形座布団の上に星1〜5のボタンを並べるレーティング入力ビュー。
public final class RatingStarsView: UIView {

    /// 星がタップされた時に呼ばれる（引数はタップされた星の位置 1〜5）
    public var onStarTapped: ((Int) -> Void)?

    private var starButtons: [UIButton] = []

    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.layer.borderWidth = 0.5
        view.layer.cornerRadius = 22
        view.clipsToBounds = true
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 0
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - 初期化

    public init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        setRating(0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - セットアップ

    private func setupViews() {
        addSubview(blurView)
        blurView.contentView.addSubview(stackView)

        for position in 1...5 {
            var config = UIButton.Configuration.borderless()
            config.image = UIImage(systemName: "star")
            config.baseForegroundColor = .white
            let button = UIButton(configuration: config)
            button.tag = position
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 40),
            ])
            starButtons.append(button)
            stackView.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 44),

            stackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -12),
        ])
    }

    // MARK: - 表示更新

    /// 現在のレーティングに合わせて星の塗りつぶし状態を更新する
    public func setRating(_ rating: Int) {
        for (index, button) in starButtons.enumerated() {
            let filled = index < rating
            var config = button.configuration ?? .borderless()
            config.image = UIImage(systemName: filled ? "star.fill" : "star")
            config.baseForegroundColor = filled ? .systemYellow : .white
            button.configuration = config
        }
    }

    // MARK: - アクション

    @objc private func starTapped(_ sender: UIButton) {
        onStarTapped?(sender.tag)
    }
}
