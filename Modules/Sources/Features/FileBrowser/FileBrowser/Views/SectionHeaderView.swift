import UIKit

/// セクションヘッダー（日付ラベル + ジャンプメニュー）を表示するガラス風ビュー。
final class SectionHeaderView: UICollectionReusableView {

    private let glassView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIGlassEffect())
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 16
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        return v
    }()

    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .preferredFont(forTextStyle: .subheadline)
        l.textColor = .label
        return l
    }()

    // 日付ジャンプが可能であることを示すシェブロンアイコン
    private let chevronImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .secondaryLabel
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    // ガラスビューの前面に重ねる透明タッチ領域。タップ時にコンテキストメニューを表示する。
    private let menuButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(glassView)
        glassView.contentView.addSubview(label)
        glassView.contentView.addSubview(chevronImageView)
        addSubview(menuButton)  // ガラスビューの前面に配置

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            glassView.centerYAnchor.constraint(equalTo: centerYAnchor),
            glassView.heightAnchor.constraint(equalToConstant: 32),

            label.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -6),

            chevronImageView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -10),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12),

            glassView.trailingAnchor.constraint(equalTo: chevronImageView.trailingAnchor, constant: 10),

            // menuButtonをglassViewと同じ範囲に重ねる
            menuButton.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
            menuButton.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
            menuButton.topAnchor.constraint(equalTo: glassView.topAnchor),
            menuButton.bottomAnchor.constraint(equalTo: glassView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(title: String, menuProvider: @escaping () -> [UIMenuElement]) {
        label.text = title
        // UIDeferredMenuElement.uncached を使うことで、メニューが表示されるたびに
        // menuProvider が呼ばれ、常に最新の内容が反映される
        let deferred = UIDeferredMenuElement.uncached { completion in
            completion(menuProvider())
        }
        menuButton.menu = UIMenu(title: "", children: [deferred])
    }
}
