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
    /// SF Symbolsアイコンを持つ円形ガラスボタンを生成する。デフォルトは44×44。
    static func circle(systemImageName: String, diameter: CGFloat = 44) -> GlassButtonView {
        var config = UIButton.Configuration.borderless()
        config.image = UIImage(systemName: systemImageName)
        config.baseForegroundColor = .white
        // 44pt以外の直径の場合、アイコンサイズも比例して縮小する（44ptは既存ボタンと同じ既定サイズのまま）
        if diameter != 44 {
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: diameter * 0.45)
        }
        let button = UIButton(configuration: config)
        let view = GlassButtonView(button: button, cornerRadius: diameter / 2)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: diameter),
            view.heightAnchor.constraint(equalToConstant: diameter),
            button.widthAnchor.constraint(equalToConstant: diameter),
            button.heightAnchor.constraint(equalToConstant: diameter),
        ])
        return view
    }
}
