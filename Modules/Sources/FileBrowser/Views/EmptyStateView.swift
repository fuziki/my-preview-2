import UIKit

public final class EmptyStateView: UIView {

    public enum State {
        case noFolder
        case loading
        case noPhotos
    }

    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        return stack
    }()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(label)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
        ])

        configure(state: .noFolder)
    }

    public func configure(state: State) {
        switch state {
        case .noFolder:
            activityIndicator.stopAnimating()
            label.text = "フォルダを選択してください"
        case .loading:
            activityIndicator.startAnimating()
            label.text = "読み込み中..."
        case .noPhotos:
            activityIndicator.stopAnimating()
            label.text = "このフォルダには写真が含まれていません"
        }
    }
}
