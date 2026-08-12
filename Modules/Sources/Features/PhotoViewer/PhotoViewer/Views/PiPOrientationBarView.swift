import UIKit

/// PiP開始ボタンと画面回転ボタンを1つの座布団にまとめた横長カプセル。
/// 高さ・アイコン構成はRatingLabelBarViewに合わせつつ、ボタンは32×32の正方形にしている。
final class PiPOrientationBarView: UIView {

    let pipButton: UIButton
    let orientationButton: UIButton

    private let glassBackdrop = GlassBackdropView(cornerRadius: 16)

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 0
        stack.alignment = .center
        return stack
    }()

    // MARK: - 初期化

    init(pipSystemImageName: String, orientationSystemImageName: String) {
        // シンボルのpointSizeは実際の描画幅より小さめに指定する（RatingLabelBarViewと同様）
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12)

        var pipConfig = UIButton.Configuration.borderless()
        pipConfig.image = UIImage(systemName: pipSystemImageName)
        pipConfig.preferredSymbolConfigurationForImage = iconConfig
        pipConfig.baseForegroundColor = .white
        pipConfig.contentInsets = .zero
        pipButton = UIButton(configuration: pipConfig)

        var orientationConfig = UIButton.Configuration.borderless()
        orientationConfig.image = UIImage(systemName: orientationSystemImageName)
        orientationConfig.preferredSymbolConfigurationForImage = iconConfig
        orientationConfig.baseForegroundColor = .white
        orientationConfig.contentInsets = .zero
        orientationButton = UIButton(configuration: orientationConfig)

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - セットアップ

    private func setupViews() {
        addSubview(glassBackdrop)
        glassBackdrop.contentView.addSubview(stackView)

        // ボタン: 32×32の正方形
        NSLayoutConstraint.activate([
            pipButton.widthAnchor.constraint(equalToConstant: 32),
            pipButton.heightAnchor.constraint(equalToConstant: 32),
        ])
        stackView.addArrangedSubview(pipButton)

        NSLayoutConstraint.activate([
            orientationButton.widthAnchor.constraint(equalToConstant: 32),
            orientationButton.heightAnchor.constraint(equalToConstant: 32),
        ])
        stackView.addArrangedSubview(orientationButton)

        NSLayoutConstraint.activate([
            glassBackdrop.topAnchor.constraint(equalTo: topAnchor),
            glassBackdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBackdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 32),

            stackView.centerYAnchor.constraint(equalTo: glassBackdrop.contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: glassBackdrop.contentView.leadingAnchor, constant: 6),
            stackView.trailingAnchor.constraint(equalTo: glassBackdrop.contentView.trailingAnchor, constant: -6),
        ])
    }
}
