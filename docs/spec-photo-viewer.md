# フォトビューア画面の挙動仕様（UIKit 版）

## 画面概要

JPEG 写真をフルスクリーンで表示するビューア画面。同フォルダ内の写真間をナビゲートし、写真を iOS の写真ライブラリに保存できる。

**クラス名：** `PhotoViewerViewController`
**ViewModel：** `PhotoViewerViewModel`

---

## MVVM 構成

### PhotoViewerViewModel（@Observable）

```swift
@Observable
final class PhotoViewerViewModel {
    private(set) var currentIndex: Int
    private(set) var allURLs: [URL]
    private(set) var currentImage: UIImage? = nil
    private(set) var previousOrientation: ImageOrientation? = nil
    var saveStatus: SaveStatus = .idle
    var isOverlayVisible: Bool = true

    // 派生プロパティ
    var currentURL: URL { allURLs[currentIndex] }
    var currentFileName: String { currentURL.lastPathComponent }
    var canGoPrevious: Bool { currentIndex > 0 }
    var canGoNext: Bool { currentIndex < allURLs.count - 1 }
}
```

**ViewModel のメソッド：**

| メソッド                | 処理                                                         |
|-------------------------|--------------------------------------------------------------|
| `loadCurrentImage() async` | 現在の URL から画像をバックグラウンドで読み込み `currentImage` を更新 |
| `navigatePrevious()`    | `currentIndex` をデクリメントし `loadCurrentImage()` を呼ぶ  |
| `navigateNext()`        | `currentIndex` をインクリメントし `loadCurrentImage()` を呼ぶ |
| `save() async`          | 現在の画像を写真ライブラリに保存し `saveStatus` を更新       |
| `toggleOverlay()`       | `isOverlayVisible` を反転する                                |

### PhotoViewerViewController の updateProperties

`PhotoViewerViewController` は `updateProperties()` をオーバーライドし、`viewModel` のプロパティ変化を UI に反映する。

```swift
override func updateProperties() {
    super.updateProperties()
    // viewModel プロパティへのアクセスがここで追跡される
    fileNameLabel.text = viewModel.currentFileName
    prevButton.isEnabled = viewModel.canGoPrevious
    nextButton.isEnabled = viewModel.canGoNext
    updateSaveButton(status: viewModel.saveStatus)
    updateOverlayVisibility(visible: viewModel.isOverlayVisible)

    if let image = viewModel.currentImage {
        updateImage(image)  // imageView の更新 + ズームリセット判定
    }
}
```

`viewModel` の `@Observable` プロパティが変化すると、システムが自動的に `setNeedsUpdateProperties()` を呼び出し、次のランループで `updateProperties()` が実行される。

---

## 表示レイアウト

- `view.backgroundColor = .black`。
- `modalPresentationStyle = .fullScreen` でフルスクリーン表示する。
- ステータスバーは UIオーバーレイの表示状態に連動して表示・非表示を切り替える（`setNeedsStatusBarAppearanceUpdate()` を使用）。
- ビュー階層：
  ```
  view（黒背景）
    ├── UIScrollView（写真のズーム・パン）
    │     └── UIImageView（写真）
    └── UIOverlayView（UIオーバーレイ、最前面）
          ├── 上部バー（UIView）
          │     └── 閉じるボタン（UIButton）
          └── 下部バー（UIView）
                ├── 前の写真ボタン（UIButton）
                ├── ファイル名ラベル（UILabel）
                ├── 保存ボタン（UIButton）
                └── 次の写真ボタン（UIButton）
  ```

---

## UIScrollView による写真表示

### 基本設定

```swift
scrollView.showsVerticalScrollIndicator = false
scrollView.showsHorizontalScrollIndicator = false
scrollView.contentInsetAdjustmentBehavior = .never
scrollView.delegate = self
```

- `UIScrollViewDelegate` の `viewForZooming(in:)` で `UIImageView` を返す。
- `UIScrollViewDelegate` の `scrollViewDidZoom(_:)` でズーム後に `centerImageView()` を呼び、画像を常に中央に配置する。

### ズームスケールの設定

画像をロードするたびに `imageView.frame.size = image.size`（UIKit ポイント単位での自然サイズ）にセットし、以下を計算する：

```
aspectFitScale = min(scrollView.bounds.width / image.size.width,
                     scrollView.bounds.height / image.size.height)

minimumZoomScale = aspectFitScale          // aspectFit（全体表示）
maximumZoomScale = max(1.0, aspectFitScale) // 等倍（UIKit ポイント単位 1:1）
                                            // 画像が画面より小さい場合は aspectFit を上限とする
initialZoomScale = aspectFitScale          // 初期表示は全体表示
```

「等倍（1:1）」とは UIKit ポイント単位で画像の 1 ピクセルがそのまま 1 ポイントに対応する状態。これが最大拡大の上限となる。

### 画像の中央配置（centerImageView）

```swift
func centerImageView() {
    let boundsSize = scrollView.bounds.size
    var frame = imageView.frame
    frame.origin.x = contentFrame.width < boundsSize.width
        ? (boundsSize.width - frame.width) / 2 : 0
    frame.origin.y = contentFrame.height < boundsSize.height
        ? (boundsSize.height - frame.height) / 2 : 0
    imageView.frame = frame
}
```

### ナビゲーション時のズーム状態

`ImageOrientation`（縦長・横長）を比較して判定する：

- 縦横比の区別が変わった場合（例：縦長 → 横長）：`resetZoom()` でズームと位置をリセット。
- 縦横比の区別が同じ場合：現在の `zoomScale` を維持し `clampContentOffset()` のみ呼ぶ。

---

## UIオーバーレイ

### 表示・非表示の切り替え

- `viewModel.toggleOverlay()` を呼び `isOverlayVisible` を反転する。
- `updateProperties()` の中でオーバーレイの `alpha` と `setNeedsStatusBarAppearanceUpdate()` を処理する。
- アニメーション：`UIView.animate(withDuration: 0.2)` で `alpha` を 0.0 / 1.0 に切り替える。

### ジェスチャ認識

| ジェスチャ       | 認識クラス                | 挙動                                                        |
|------------------|---------------------------|-------------------------------------------------------------|
| シングルタップ   | `UITapGestureRecognizer`  | `viewModel.toggleOverlay()` を呼ぶ                          |
| ダブルタップ     | `UITapGestureRecognizer`  | 等倍（maximumZoomScale）にズームイン or aspectFit にリセット |

- シングルタップは `require(toFail:)` でダブルタップ認識の失敗を待つ。
- ジェスチャは `scrollView` に追加する（`UIScrollView` 自身のピンチ・ドラッグを活用）。

### ダブルタップの挙動

| 現在の状態             | 挙動                                                                         |
|------------------------|------------------------------------------------------------------------------|
| aspectFit（全体表示）  | タップした位置を中心に `maximumZoomScale`（等倍）へズームイン（アニメーション付き） |
| ズーム中               | `resetZoom()` で aspectFit に戻す（アニメーション付き）                       |

```swift
let zoomRect = zoomRect(for: scrollView.maximumZoomScale, center: tapPoint)
scrollView.zoom(to: zoomRect, animated: true)
```

---

## 上部バー

- `UIVisualEffectView`（`UIBlurEffect(style: .dark)`）の上に配置する。
- Safe Area の top に合わせて配置する。

| 要素            | 位置 | 実装                                         | 挙動                          |
|-----------------|------|----------------------------------------------|-------------------------------|
| ✕ 閉じるボタン | 左上 | `UIButton`（システムアイコン `xmark`）       | `dismiss(animated: true)`     |

---

## 下部バー

- `UIVisualEffectView`（`UIBlurEffect(style: .dark)`）の上に配置する。
- Safe Area の bottom に合わせて配置する。

| 要素               | 位置           | 実装                                                  | 挙動                                                             |
|--------------------|----------------|-------------------------------------------------------|------------------------------------------------------------------|
| ＜ 前の写真ボタン  | 左下           | `UIButton`（`chevron.left`）                          | `viewModel.navigatePrevious()`。先頭の場合は `isEnabled = false` |
| ファイル名ラベル   | 中央           | `UILabel`                                             | `viewModel.currentFileName`（1 行、中略）                        |
| 保存ボタン         | ファイル名の下 | `UIButton`                                            | `Task { await viewModel.save() }`                                |
| ＞ 次の写真ボタン  | 右下           | `UIButton`（`chevron.right`）                         | `viewModel.navigateNext()`。末尾の場合は `isEnabled = false`     |

- 前後ボタンが無効の場合は `tintColor = .systemGray` にする。

---

## 写真間のナビゲーション

- ViewModel の `navigatePrevious()` / `navigateNext()` でインデックスを変更し、`loadCurrentImage()` を内部で呼ぶ。
- 画像ロード完了後に `currentImage` が更新され、`updateProperties()` が呼ばれて `imageView.image` を更新する。
- 移動後は `saveStatus` を `.idle` に戻す（ViewModel 内で処理）。

---

## 写真の保存

### SaveStatus（保存状態）

```swift
enum SaveStatus {
    case idle       // 「↓ 保存」
    case saving     // 「⏳ 保存中...」（ボタン無効）
    case success    // 「✓ 保存完了」
    case failure    // 「✕ 失敗」
}
```

### 保存ボタンの状態遷移

| 状態    | 表示テキスト | ボタン有効/無効 | 次のアクション               |
|---------|-------------|----------------|------------------------------|
| idle    | ↓ 保存      | 有効           | タップで保存開始             |
| saving  | ⏳ 保存中...| 無効           | 処理完了まで待機             |
| success | ✓ 保存完了 | 無効           | 2 秒後に idle に戻る         |
| failure | ✕ 失敗     | 有効           | タップで再試行               |

### 保存の挙動（ViewModel の `save() async`）

```swift
func save() async {
    saveStatus = .saving
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
        saveStatus = .failure; return
    }
    do {
        try await PHPhotoLibrary.shared().performChanges { ... }
        saveStatus = .success
        try await Task.sleep(for: .seconds(2))
        saveStatus = .idle
    } catch {
        saveStatus = .failure
    }
}
```

- `PHAssetCreationRequest` + `PHAssetResourceCreationOptions` でオリジナルファイル名を保持する。
- 画像の再エンコードは行わない（元ファイルデータをそのまま使用）。

---

## 画像のロード（ViewModel の `loadCurrentImage() async`）

```swift
func loadCurrentImage() async {
    let url = currentURL
    let image = await Task.detached(priority: .userInitiated) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }.value
    await MainActor.run {
        self.currentImage = image
    }
}
```

- `Task.detached` でバックグラウンドスレッドで読み込む。
- `Data(contentsOf:)` と `UIImage(data:)` でデコードする。
- セキュリティスコープドアクセスは `FileBrowserViewController` が保持しているため、追加のスコープ取得は不要。

---

## ステータスバーの挙動

- `preferredStatusBarStyle` を `override` して `.lightContent` を返す。
- `prefersStatusBarHidden` を `override` して `viewModel.isOverlayVisible` の逆値を返す。
- `updateProperties()` 内で `setNeedsStatusBarAppearanceUpdate()` を呼ぶ。

---

## 画面回転・サイズ変更への対応

- `viewDidLayoutSubviews()` をオーバーライドし、`UIScrollView` のサイズ変更時に `resetZoom()` を呼んでレイアウトを再計算する。
- 画面回転時にもズームスケールと中央配置が正しく再計算されることを保証する。
