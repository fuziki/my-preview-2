import UIKit
import Core

/// glass effect のカプセル形座布団の上に、レーティングの星1〜5とカラーラベル6色を
/// 横並びで載せる入力ビュー。
public final class RatingLabelBarView: UIView {

    /// 星がタップされた時に呼ばれる（引数はタップされた星の位置 1〜5）
    public var onStarTapped: ((Int) -> Void)?

    /// カラーラベルがタップされた時に呼ばれる
    public var onColorTapped: ((PhotoColorLabel) -> Void)?

    private var starButtons: [UIButton] = []
    /// PhotoColorLabel.allCases と同順のカラーボタン
    private var colorButtons: [UIButton] = []

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
        stack.alignment = .fill
        return stack
    }()

    // 星とカラーラベルの間の区切り線
    private let separatorView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        return v
    }()

    // MARK: - 初期化

    public init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
        setRating(0)
        setColorLabel(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - セットアップ

    private func setupViews() {
        addSubview(blurView)
        blurView.contentView.addSubview(stackView)

        // 星ボタン（1〜5）
        for position in 1...5 {
            var config = UIButton.Configuration.borderless()
            config.image = UIImage(systemName: "star")
            config.baseForegroundColor = .white
            config.contentInsets = .zero
            let button = UIButton(configuration: config)
            button.tag = position
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 36).isActive = true
            starButtons.append(button)
            stackView.addArrangedSubview(button)
        }

        // 区切り線（スタック内で高さを抑えるためコンテナに載せる）
        let separatorContainer = UIView()
        separatorContainer.addSubview(separatorView)
        NSLayoutConstraint.activate([
            separatorContainer.widthAnchor.constraint(equalToConstant: 9),
            separatorView.centerXAnchor.constraint(equalTo: separatorContainer.centerXAnchor),
            separatorView.centerYAnchor.constraint(equalTo: separatorContainer.centerYAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 1),
            separatorView.heightAnchor.constraint(equalToConstant: 20),
        ])
        stackView.addArrangedSubview(separatorContainer)

        // カラーラベルボタン（6色）
        for (index, label) in PhotoColorLabel.allCases.enumerated() {
            var config = UIButton.Configuration.borderless()
            config.image = UIImage(systemName: "circle.fill")
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13)
            config.baseForegroundColor = label.uiColor
            config.contentInsets = .zero
            let button = UIButton(configuration: config)
            button.tag = index
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 25).isActive = true
            colorButtons.append(button)
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
            stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -10),
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

    /// 現在のカラーラベルに合わせて選択状態を更新する
    public func setColorLabel(_ label: PhotoColorLabel?) {
        for (index, button) in colorButtons.enumerated() {
            let selected = PhotoColorLabel.allCases[index] == label
            var config = button.configuration ?? .borderless()
            // 選択中はリング付きのシンボルで示す
            config.image = UIImage(systemName: selected ? "circle.inset.filled" : "circle.fill")
            button.configuration = config
        }
    }

    // MARK: - アクション

    @objc private func starTapped(_ sender: UIButton) {
        onStarTapped?(sender.tag)
    }

    @objc private func colorTapped(_ sender: UIButton) {
        onColorTapped?(PhotoColorLabel.allCases[sender.tag])
    }
}
