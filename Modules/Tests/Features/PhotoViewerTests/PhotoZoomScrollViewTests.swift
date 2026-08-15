import Testing
import UIKit
import Core
@testable import PhotoViewer

// MARK: - テスト
// display(image:)（フィットへズームリセット）と swapImageKeepingZoom（ズーム状態維持で画像だけ差し替え）を検証する。
// レイアウト（画面のbounds）にのみ依存し、実機・シミュレータのウィンドウ表示は不要なため、
// frameを直接与えるだけで検証できる範囲にとどめる。

struct PhotoZoomScrollViewTests {

    /// 指定サイズのモック画像を生成する（実データは不要でサイズのみ使う）
    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { _ in }
    }

    @Test
    func display_setsZoomToAspectFit() {
        let scrollView = PhotoZoomScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let image = makeImage(width: 600, height: 300)  // 横長: フィットは幅300基準で0.5倍
        scrollView.display(image: image)

        // display は常にフィット（=最小ズーム）で表示する
        #expect(abs(scrollView.zoomScale - scrollView.minimumZoomScale) < 0.001)
        #expect(abs(scrollView.zoomScale - 0.5) < 0.001)
    }

    @Test
    func swapImageKeepingZoom_keepsZoomScale() {
        let scrollView = PhotoZoomScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        let firstImage = makeImage(width: 600, height: 300)
        scrollView.display(image: firstImage)

        // 2倍にズームしてから、ズーム維持で別画像へ差し替える
        scrollView.zoomScale = scrollView.minimumZoomScale * 2
        let scaleBeforeSwap = scrollView.zoomScale

        let secondImage = makeImage(width: 600, height: 300)
        scrollView.swapImageKeepingZoom(secondImage)

        // ズーム倍率は差し替え後も維持される（リセットされない）
        #expect(abs(scrollView.zoomScale - scaleBeforeSwap) < 0.001)
        #expect(scrollView.imageView.image === secondImage)
    }
}
