# フォトビューア画面の仕様

## 画面概要

JPEG 写真をフルスクリーンで表示するビューア画面。同フォルダ内の写真間をナビゲートし、Exif メタデータを表示しながら、写真を iOS の写真ライブラリに保存できる。

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
    private(set) var isLoading: Bool = false
    private(set) var exifInfo: ExifInfo? = nil
    var saveStatus: SaveStatus = .idle
    var isOverlayVisible: Bool = true

    // 派生プロパティ
    var currentURL: URL { allURLs[currentIndex] }
    var currentFileName: String { currentURL.lastPathComponent }
    var canGoPrevious: Bool { currentIndex > 0 }
    var canGoNext: Bool { currentIndex < allURLs.count - 1 }
}
```

`init(input: PhotoViewerInput)` で `allURLs` と `currentIndex`（`initialURL` の位置）を初期化する。

**ViewModel のメソッド：**

| メソッド                      | 処理                                                                            |
|-------------------------------|---------------------------------------------------------------------------------|
| `loadCurrentImage() async`    | 現在の URL から画像と Exif 情報をバックグラウンドで読み込み各プロパティを更新する |
| `navigatePrevious() async`    | `previousOrientation` を保存後に `currentIndex` をデクリメントし `loadCurrentImage()` を呼ぶ |
| `navigateNext() async`        | `previousOrientation` を保存後に `currentIndex` をインクリメントし `loadCurrentImage()` を呼ぶ |
| `save() async`                | 権限確認後に現在の写真を写真ライブラリへ保存し `saveStatus` を更新する          |
| `toggleOverlay()`             | `isOverlayVisible` を反転する                                                   |

### PhotoViewerViewController の updateProperties

`PhotoViewerViewController` は `updateProperties()` をオーバーライドし、`viewModel` のプロパティ変化を UI に反映する。

```swift
override func updateProperties() {
    super.updateProperties()
    fileNameLabel.text = viewModel.currentFileName
    // exifParts を結合してラベルに設定、空の場合は非表示
    exifLabel.text = exifParts.joined(separator: "  ")
    exifLabel.isHidden = exifParts.isEmpty
    prevButtonView.button.isEnabled = viewModel.canGoPrevious
    prevButtonView.button.tintColor = viewModel.canGoPrevious ? .white : .systemGray
    nextButtonView.button.isEnabled = viewModel.canGoNext
    nextButtonView.button.tintColor = viewModel.canGoNext ? .white : .systemGray
    updateSaveButton(status: viewModel.saveStatus)
    viewModel.isLoading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    updateOverlayVisibility(visible: viewModel.isOverlayVisible)

    if let image = viewModel.currentImage, image !== displayedImage {
        displayedImage = image
        // サムネイルサイズ更新・imageView 更新・zoomScrollView への表示
        zoomScrollView.display(image: image, previousOrientation: viewModel.previousOrientation)
    }
}
```

---

## 表示レイアウト

- `view.backgroundColor = .black`。
- `modalPresentationStyle = .fullScreen` でフルスクリーン表示する。
- ステータスバーはオーバーレイの表示状態に連動して表示・非表示を切り替える（`setNeedsStatusBarAppearanceUpdate()` を使用）。
- ビュー階層：

```
view（黒背景）
  ├── PhotoZoomScrollView（全画面、写真のズーム・パン）
  │     └── UIImageView（写真）
  └── 各フローティング要素（view に直接追加、PhotoZoomScrollView より前面）
        ├── 閉じるボタン（GlassButtonView、左上）
        ├── ファイル名 + Exif パネル（UIVisualEffectView、右上）
        ├── サムネイル（UIImageView、ファイル名パネルの下・右寄せ）
        ├── 前へボタン（GlassButtonView、左下）
        ├── 次へボタン（GlassButtonView、右下）
        ├── 保存ボタン（GlassButtonView、下部中央）
        └── ローディングインジケーター（UIActivityIndicatorView、保存ボタンの上）
```

各フローティング要素はボタンが配置されていない領域のタッチを `PhotoZoomScrollView` に自然に伝播させる（`hitTest` オーバーライド不要）。

---

## PhotoZoomScrollView（写真表示エリア）

`UIScrollView` のサブクラスとして実装する。

### 基本設定

```swift
showsVerticalScrollIndicator = false
showsHorizontalScrollIndicator = false
contentInsetAdjustmentBehavior = .never
bouncesZoom = true
delegate = self
```

- `UIScrollViewDelegate` の `viewForZooming(in:)` で `imageView` を返す。
- `UIScrollViewDelegate` の `scrollViewDidZoom(_:)` でズーム後に `centerImageView()` を呼び、画像を常に中央に配置する。
- `imageView.contentMode = .scaleToFill`（ズームスケールで制御するため fill を使用）。

### ズームスケールの設定

画像をロードするたびに以下を計算する：

```
aspectFitScale = min(scrollView.bounds.width / image.size.width,
                     scrollView.bounds.height / image.size.height)

minimumZoomScale = aspectFitScale       // 全体表示
maximumZoomScale = max(1.0, aspectFitScale)  // UIKit ポイント等倍（画像が画面より小さい場合は aspectFit が上限）
initialZoomScale = aspectFitScale       // 初期表示は全体表示
```

「等倍（1.0）」とは UIKit ポイント単位で画像の 1 ピクセルが 1 ポイントに対応する状態。

### ズームリセット時の注意事項

ズームスケール変更前に必ず `zoomScale = 1.0`・`minimumZoomScale = 1.0`・`maximumZoomScale = 1.0` にリセットする。非 identity な transform が適用されている状態で `imageView.frame` を変更することは Apple ドキュメントで禁止されているため。

### 画像の中央配置（centerImageView）

`imageView.frame` を直接変更せず、`contentInset` を操作して中央配置する。

```swift
let offsetX = max((bounds.width - contentSize.width) / 2, 0)
let offsetY = max((bounds.height - contentSize.height) / 2, 0)
contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
```

### bounds 変更への対応（デバイス回転など）

`layoutSubviews()` をオーバーライドし、bounds サイズが変化した場合は `resetZoom(for:)` を呼んでズームを再計算する。サイズが変わっていない場合は `centerImageView()` のみ呼ぶ。

### ナビゲーション時のズーム状態

`display(image:previousOrientation:)` を呼び出す際、`previousOrientation` との比較でズーム挙動を分岐する：

| 遷移パターン                          | 挙動                                                                     |
|---------------------------------------|--------------------------------------------------------------------------|
| 初回表示（`previousOrientation` が nil）   | `resetZoom(for:)` でズームをリセット                                      |
| 向きが変わった場合（縦 ↔ 横）          | `resetZoom(for:)` でズームをリセット                                      |
| 向きが同じ場合（縦 → 縦、横 → 横）    | `updateZoomForSameOrientation(for:)` で現在のズーム比率を新しい画像に適用 |

同じ向きの場合のズーム引き継ぎ計算：

```swift
let zoomRatio = zoomScale / minimumZoomScale  // 現在のズーム比率（fitの何倍か）
let targetZoom = clamp(newMinScale * zoomRatio, newMinScale, newMaxScale)
zoomScale = targetZoom
```

引き継ぎ後は `clampContentOffset()` でコンテンツオフセットを有効範囲に収める。

---

## フローティング UI 要素の配置

### 閉じるボタン（左上）

- `GlassButtonView.circle(systemImageName: "xmark")`
- 制約：
  - `top` = `view.safeAreaLayoutGuide.topAnchor` + 12pt
  - `leading` = `view.leadingAnchor` + 16pt

### ファイル名 + Exif パネル（右上）

- `UIVisualEffectView`（`UIBlurEffect(style: .systemUltraThinMaterialDark)`）にガラスモーフィズムを適用。
  - `cornerRadius = 16`
  - 白ボーダー（透明度 0.15、幅 0.5pt）
- 内部に `UIStackView`（縦 axis）で `fileNameLabel`・`exifLabel` を配置する。
- 制約：
  - `top` = `view.safeAreaLayoutGuide.topAnchor` + 12pt
  - `trailing` = `view.trailingAnchor` - 16pt
  - `leading` ≥ `closeButtonView.trailingAnchor` + 8pt（閉じるボタンに重ならない）
  - `height` ≥ 44pt
  - 内部パディング：上下 8pt、左右 14pt

#### ファイル名ラベル

- フォント：`UIFont.preferredFont(forTextStyle: .callout)`
- テキストカラー：白
- 行数：1行、`lineBreakMode = .byTruncatingMiddle`

#### Exif ラベル

- フォント：`UIFont.preferredFont(forTextStyle: .caption1)`
- テキストカラー：白（透明度 75%）
- 行数：1行
- 表示内容：取得できた Exif 項目を `"  "`（2スペース）区切りで連結
- Exif 項目が 1 件も取得できない場合は非表示にする

### サムネイル（ファイル名パネルの下・右寄せ）

- `contentMode = .scaleAspectFit`
- サイズ：最大辺 80pt でアスペクト比を維持する（動的に制約を更新）
- 制約：
  - `top` = `fileNameBlur.bottomAnchor` + 8pt
  - `trailing` = `fileNameBlur.trailingAnchor`

### 前へボタン（左下）

- `GlassButtonView.circle(systemImageName: "chevron.left")`
- 制約：
  - `bottom` = `view.safeAreaLayoutGuide.bottomAnchor` - 20pt
  - `leading` = `view.leadingAnchor` + 16pt

### 次へボタン（右下）

- `GlassButtonView.circle(systemImageName: "chevron.right")`
- 制約：
  - `bottom` = `view.safeAreaLayoutGuide.bottomAnchor` - 20pt
  - `trailing` = `view.trailingAnchor` - 16pt

### 保存ボタン（下部中央）

- `GlassButtonView`（カプセル形、`cornerRadius = 22`）
- ボタン構成：`UIButton.Configuration.borderless()`、タイトルテキスト、左右パディング 20pt
- テキストカラー：常に白（`configurationUpdateHandler` で disabled 時の自動調光を抑制）
- 制約：
  - `bottom` = `view.safeAreaLayoutGuide.bottomAnchor` - 20pt
  - `centerX` = `view.centerXAnchor`
  - `leading` ≥ `prevButtonView.trailingAnchor` + 8pt
  - `trailing` ≤ `nextButtonView.leadingAnchor` - 8pt
  - `height` = 44pt

### ローディングインジケーター（保存ボタンの上）

- `UIActivityIndicatorView(style: .medium)`
- カラー：白
- `hidesWhenStopped = true`
- 制約：
  - `centerX` = `saveButtonView.centerXAnchor`
  - `bottom` = `saveButtonView.topAnchor` - 8pt

---

## GlassButtonView の仕様

```swift
final class GlassButtonView: UIView {
    let button: UIButton
    private let blurView: UIVisualEffectView  // systemUltraThinMaterialDark
}
```

- 背景：`UIVisualEffectView`（`UIBlurEffect(style: .systemUltraThinMaterialDark)`）
- ボーダー：白（透明度 0.15）、幅 0.5pt
- `cornerRadius`：コンストラクタ引数で指定（デフォルト 22）

**circle ファクトリメソッド：**

```swift
static func circle(systemImageName: String) -> GlassButtonView
```

- 44 × 44pt の正円ボタンを生成する
- `baseForegroundColor = .white`

---

## オーバーレイの表示・非表示

- `viewModel.isOverlayVisible` の変化を `updateProperties()` で検知する。
- `UIView.animate(withDuration: 0.2)` でフローティング UI 要素全体の `alpha` を 0.0 / 1.0 に切り替える。
- オーバーレイが非表示の場合はステータスバーも非表示にする（`prefersStatusBarHidden` で制御）。
- `updateProperties()` 内で `setNeedsStatusBarAppearanceUpdate()` を呼ぶ。

---

## ジェスチャー認識

ジェスチャーは `PhotoZoomScrollView` に追加する。

| ジェスチャー     | 認識クラス               | 挙動                                                                     |
|------------------|--------------------------|--------------------------------------------------------------------------|
| シングルタップ   | `UITapGestureRecognizer`（`numberOfTapsRequired = 1`） | `viewModel.toggleOverlay()` を呼ぶ |
| ダブルタップ     | `UITapGestureRecognizer`（`numberOfTapsRequired = 2`） | ズームイン or ズームリセット        |
| ピンチ           | `UIScrollView` 組み込み  | ズームイン・ズームアウト                                                   |

- シングルタップは `require(toFail:)` でダブルタップ認識の失敗を待つ。

### ダブルタップの挙動

| 現在の状態                              | 挙動                                                                                        |
|-----------------------------------------|---------------------------------------------------------------------------------------------|
| `minimumZoomScale`（全体表示）に近い状態 | タップした位置を中心に `maximumZoomScale` へズームイン（`zoom(to:animated:)` でアニメーション） |
| ズーム中                                | `setZoomScale(minimumZoomScale, animated: true)` で全体表示に戻す                           |

ズームイン時の `zoomRect` 計算：

```swift
let tapPoint = gesture.location(in: zoomScrollView.imageView)
let width = zoomScrollView.bounds.width / zoomScrollView.maximumZoomScale
let height = zoomScrollView.bounds.height / zoomScrollView.maximumZoomScale
let rect = CGRect(
    x: tapPoint.x - width / 2,
    y: tapPoint.y - height / 2,
    width: width,
    height: height
)
zoomScrollView.zoom(to: rect, animated: true)
```

「ズーム中」の判定は `zoomScale > minimumZoomScale + 0.001` とする。

---

## 写真間のナビゲーション

- `navigatePrevious()` / `navigateNext()` は先頭・末尾の境界チェック（`canGoPrevious` / `canGoNext`）を内部で行う。
- ナビゲーション前に `previousOrientation = currentImage?.photoOrientation` を保存する。
- ナビゲーション後に `saveStatus = .idle` にリセットする。
- 前後ボタンの `tintColor`：有効時は `.white`、無効時は `.systemGray`。

---

## 写真保存（ViewModel の `save() async`）

```swift
func save() async {
    guard currentImage != nil else { return }
    let url = currentURL
    saveStatus = .saving
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
        saveStatus = .failure; return
    }
    do {
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = url.lastPathComponent
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: options)
        }
        saveStatus = .success
        try await Task.sleep(for: .seconds(2))
        saveStatus = .idle
    } catch {
        saveStatus = .failure
    }
}
```

- `PHAssetCreationRequest` + `addResource(with: .photo, fileURL:, options:)` でオリジナルデータをそのまま保存する。
- `options.originalFilename` に元ファイル名を設定してファイル名を保持する。
- 画像の再エンコードは行わない。
- 保存成功後、2 秒後に `saveStatus = .idle` に戻す（`Task.sleep(for: .seconds(2))`）。

### 保存ボタンの状態遷移

| 状態      | ボタン表示テキスト | ボタン有効/無効 | 次の遷移                           |
|-----------|-------------------|-----------------|------------------------------------|
| `.idle`   | `↓ 保存`          | 有効            | タップで `.saving` へ              |
| `.saving` | `⏳ 保存中...`    | 無効            | 完了後 `.success` または `.failure` へ |
| `.success`| `✓ 保存完了`      | 無効            | 2 秒後に自動で `.idle` へ          |
| `.failure`| `✕ 失敗`          | 有効（再試行可能） | タップで `.saving` へ             |

---

## 画像のロード（ViewModel の `loadCurrentImage() async`）

```swift
func loadCurrentImage() async {
    let url = currentURL
    isLoading = true
    let result = await Task.detached(priority: .userInitiated) {
        guard let data = try? Data(contentsOf: url) else { return (nil, nil) }
        return (UIImage(data: data), Self.extractExif(from: data))
    }.value
    currentImage = result.0
    exifInfo = result.1
    isLoading = false
}
```

- `Task.detached` でバックグラウンドスレッドで読み込む。
- `isLoading = true` → 画像・Exif 取得 → `currentImage`・`exifInfo` 更新 → `isLoading = false` の順で更新する。
- セキュリティスコープドアクセスは `FileBrowserViewModel` が保持しているため、追加のスコープ取得は不要。

---

## Exif 情報の抽出

`CGImageSource` を使用して JPEG データから直接 Exif メタデータを抽出する（画像デコード不要）。

```swift
private static func extractExif(from data: Data) -> ExifInfo? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
          let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
        return nil
    }
    // 各フィールドを取得・フォーマット
}
```

### 各フィールドの取得・フォーマット

| フィールド     | Exif キー                              | フォーマット例                                                |
|---------------|----------------------------------------|--------------------------------------------------------------|
| ISO 感度      | `kCGImagePropertyExifISOSpeedRatings`  | 配列の先頭要素を取得。`"ISO 400"`                             |
| 焦点距離      | `kCGImagePropertyExifFocalLength`      | `Double`。`"%.0fmm"` → `"50mm"`                              |
| 露出補正      | `kCGImagePropertyExifExposureBiasValue`| `Double`。0 の場合は `"±0EV"`、それ以外は `"%+.1fEV"` → `"+1.0EV"` |
| F 値          | `kCGImagePropertyExifFNumber`          | `Double`。`"f/%.1f"` → `"f/2.8"`                             |
| シャッタースピード | `kCGImagePropertyExifExposureTime` | `Double`（秒）。1秒以上は `"%.0fs"` → `"2s"`、1秒未満は `"1/\(round(1/et))s"` → `"1/125s"` |

Exif ディクショナリ自体が取得できない場合は `nil` を返す（Exif ラベルは非表示になる）。

---

## ステータスバーの挙動

```swift
override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
override var prefersStatusBarHidden: Bool { !viewModel.isOverlayVisible }
```

- `preferredStatusBarStyle` は常に `.lightContent`（白色）。
- `prefersStatusBarHidden` はオーバーレイが非表示の場合に `true` を返す。
- オーバーレイ切り替え時に `setNeedsStatusBarAppearanceUpdate()` を呼ぶ。
