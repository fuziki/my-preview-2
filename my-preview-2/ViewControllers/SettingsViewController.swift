import UIKit

// MARK: - SettingsViewController

final class SettingsViewController: UIViewController {

    private let viewModel = SettingsViewModel()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tv
    }()

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "設定"
        view.backgroundColor = .systemGroupedBackground
        setupViews()
    }

    // MARK: - セットアップ

    private func setupViews() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "表示モード" : "保存形式"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            let modes: [ViewMode] = [.list, .grid]
            let mode = modes[indexPath.row]
            config.text = mode == .list ? "リスト" : "グリッド"
            cell.accessoryType = viewModel.viewMode == mode ? .checkmark : .none
        } else {
            let formats: [SaveFormat] = [.jpeg, .jpegAndRaw]
            let format = formats[indexPath.row]
            config.text = format.displayName
            cell.accessoryType = viewModel.saveFormat == format ? .checkmark : .none
        }

        cell.contentConfiguration = config
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            viewModel.viewMode = [.list, .grid][indexPath.row]
        } else {
            viewModel.saveFormat = [.jpeg, .jpegAndRaw][indexPath.row]
        }

        tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
    }
}
