import UIKit

/// 半透明グレーの層 + Liquid Glass（UIGlassEffect）を重ねた共通の座布団ビュー。
/// 明るい写真の上でもコンテンツが視認できるよう、ガラスの裏に半透明グレーを敷く。
public final class GlassBackdropView: UIView {

    // MARK: - プロパティ

    /// コンテンツを載せるビュー（ガラスのcontentViewをそのまま公開する）
    public var contentView: UIView { glassView.contentView }

    private let backdropView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.clipsToBounds = true
        return view
    }()

    private let glassView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        view.translatesAutoresizingMaskIntoConstraints = false
        // 写真の上に常時オーバーレイ表示するため、システムの外観設定に関わらずダークな見た目に固定する
        view.overrideUserInterfaceStyle = .dark
        view.clipsToBounds = true
        return view
    }()

    // MARK: - 初期化

    public init(cornerRadius: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backdropView.layer.cornerRadius = cornerRadius
        glassView.cornerConfiguration = .corners(radius: .fixed(cornerRadius))
        setupViews()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - セットアップ

    private func setupViews() {
        addSubview(backdropView)
        addSubview(glassView)
        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: glassView.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor),

            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
