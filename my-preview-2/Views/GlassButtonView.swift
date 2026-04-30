import UIKit

/// A glass-morphism style container that wraps UIVisualEffectView and a UIButton.
/// Use the `circle(systemImageName:)` factory for 44×44 icon buttons.
final class GlassButtonView: UIView {

    // MARK: - Properties

    let button: UIButton

    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.layer.borderWidth = 0.5
        view.clipsToBounds = true
        return view
    }()

    // MARK: - Init

    init(button: UIButton, cornerRadius: CGFloat = 22) {
        self.button = button
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = cornerRadius
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        addSubview(blurView)
        button.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
        ])
    }
}

// MARK: - Factory

extension GlassButtonView {
    /// Creates a 44×44 circular glass button with an SF Symbols icon.
    static func circle(systemImageName: String) -> GlassButtonView {
        var config = UIButton.Configuration.borderless()
        config.image = UIImage(systemName: systemImageName)
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        let view = GlassButtonView(button: button, cornerRadius: 22)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 44),
            view.heightAnchor.constraint(equalToConstant: 44),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        return view
    }
}
