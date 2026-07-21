import UIKit

#if targetEnvironment(simulator)
/// モック画像を生成するファクトリ。
/// 青色背景の中央に黒色で番号を描画する。
public enum MockImageFactory {

    /// 指定サイズのモック画像を生成する
    public static func render(number: Int, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let text = "\(number)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.height * 0.25, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            let textSize = text.size(withAttributes: attributes)
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: origin, withAttributes: attributes)
        }
    }

    /// ファイル名末尾の数字から番号を取り出す（例: mock-12.jpg → 12）
    public static func number(from url: URL) -> Int {
        let digits = url.deletingPathExtension().lastPathComponent.filter(\.isNumber)
        return Int(digits) ?? 0
    }
}
#endif
