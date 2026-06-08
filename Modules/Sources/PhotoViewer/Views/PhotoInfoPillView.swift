import UIKit
import SwiftUI
import Core

// MARK: - PhotoInfoPillView

/// ファイル名とEXIF情報を表示し、タップでクリップボードにコピーするフローティングピルビュー
final class PhotoInfoPillView: UIView {

    // MARK: - サブビュー

    private let blurView: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 16
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth = 0.5
        blur.clipsToBounds = true
        return blur
    }()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        return stack
    }()

    let fileNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .callout)
        label.lineBreakMode = .byTruncatingMiddle
        label.numberOfLines = 1
        return label
    }()

    let exifLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.font = .preferredFont(forTextStyle: .caption1)
        label.numberOfLines = 1
        label.isHidden = true
        return label
    }()

    // 全幅タップ領域（テキストより前面に配置）
    private let copyButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - 状態

    private var fileName: String = ""
    private var exifInfo: ExifInfo?

    // MARK: - 初期化

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - セットアップ

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            // コンテンツ幅で右寄せ。leadingは>=にしてスタック幅で決まるようにする
            blurView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        stack.addArrangedSubview(fileNameLabel)
        stack.addArrangedSubview(exifLabel)
        blurView.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: blurView.contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: blurView.contentView.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -14),
        ])

        // copyButton を最前面に配置し全幅タップ領域を確保する
        addSubview(copyButton)
        NSLayoutConstraint.activate([
            copyButton.topAnchor.constraint(equalTo: topAnchor),
            copyButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            copyButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
    }

    // MARK: - 更新

    func configure(fileName: String, exifInfo: ExifInfo?) {
        self.fileName = fileName
        self.exifInfo = exifInfo

        fileNameLabel.text = fileName

        let exifParts = [
            exifInfo?.iso,
            exifInfo?.focalLength,
            exifInfo?.exposureValue,
            exifInfo?.fNumber,
            exifInfo?.shutterSpeed,
        ].compactMap { $0 }
        let flashSuffix = exifInfo?.flashFired == true ? "  ⚡️" : ""
        exifLabel.text = exifParts.joined(separator: "  ") + flashSuffix
        exifLabel.isHidden = exifParts.isEmpty
    }

    // MARK: - クリップボードコピー

    @objc private func copyTapped() {
        let exifText = formattedExifForClipboard()
        let text = exifText.isEmpty ? fileName : "\(fileName)\n\(exifText)"
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        ToastKit.show {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                Text("クリップボードにコピーしました")
            }
        }
    }

    private func formattedExifForClipboard() -> String {
        guard let exifInfo else { return "" }
        var parts: [String] = []
        // iso は "ISO 100" 形式なので数値部分のみ取り出してラベルを付け直す
        if let iso = exifInfo.iso {
            let value = iso.replacingOccurrences(of: "ISO ", with: "")
            parts.append("ISO: \(value)")
        }
        if let fn = exifInfo.fNumber  { parts.append("F値: \(fn)") }
        if let ss = exifInfo.shutterSpeed { parts.append("SS: \(ss)") }
        if let fl = exifInfo.focalLength { parts.append("焦点距離: \(fl)") }
        if let ev = exifInfo.exposureValue { parts.append("EV: \(ev)") }
        if exifInfo.flashFired { parts.append("フラッシュあり") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#if DEBUG

#Preview("ファイル名＋EXIF（フラッシュあり）") {
    let vc = UIViewController()
    vc.view.backgroundColor = .black

    let pill = PhotoInfoPillView()
    pill.configure(
        fileName: "IMG_1234.HEIC",
        exifInfo: ExifInfo(
            iso: "ISO 100",
            focalLength: "50mm",
            exposureValue: "+0.3EV",
            fNumber: "f/2.8",
            shutterSpeed: "1/250s",
            flashFired: true
        )
    )
    vc.view.addSubview(pill)
    NSLayoutConstraint.activate([
        pill.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 12),
        pill.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -16),
        pill.leadingAnchor.constraint(greaterThanOrEqualTo: vc.view.leadingAnchor, constant: 80),
    ])
    return vc
}

#Preview("ファイル名のみ（EXIFなし）") {
    let vc = UIViewController()
    vc.view.backgroundColor = .black

    let pill = PhotoInfoPillView()
    pill.configure(fileName: "DSC_0001.JPG", exifInfo: nil)
    vc.view.addSubview(pill)
    NSLayoutConstraint.activate([
        pill.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 12),
        pill.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -16),
        pill.leadingAnchor.constraint(greaterThanOrEqualTo: vc.view.leadingAnchor, constant: 80),
    ])
    return vc
}
#endif
