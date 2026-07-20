import UIKit

/// UIVisualEffectViewとUIButtonをラップするLiquid Glassスタイルのコンテナ。
/// 44×44 アイコンボタンには `circle(systemImageName:)` ファクトリを使用する。
public final class GlassButtonView: UIView {

    // MARK: - プロパティ

    public let button: UIButton

    private let glassBackdrop: GlassBackdropView

    // MARK: - 初期化

    public init(button: UIButton, cornerRadius: CGFloat = 22) {
        self.button = button
        glassBackdrop = GlassBackdropView(cornerRadius: cornerRadius)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupViews()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - セットアップ

    private func setupViews() {
        addSubview(glassBackdrop)
        button.translatesAutoresizingMaskIntoConstraints = false
        glassBackdrop.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            glassBackdrop.topAnchor.constraint(equalTo: topAnchor),
            glassBackdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBackdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.centerXAnchor.constraint(equalTo: glassBackdrop.contentView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: glassBackdrop.contentView.centerYAnchor),
        ])
    }
}

// MARK: - ファクトリ

public extension GlassButtonView {
    /// SF Symbolsアイコンを持つ 44×44 の円形ガラスボタンを生成する。
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
