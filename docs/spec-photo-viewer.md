# フォトビューア画面の仕様

## 画面概要

JPEG 写真をフルスクリーンで表示するビューア画面。同フォルダ内の写真間をナビゲートし、Exif メタデータを表示しながら、写真を iOS の写真ライブラリに保存できる。星評価・カラーラベルの設定、ファイル名/Exif のクリップボードコピーにも対応する。

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
    private(set) var saveStatus: SaveStatus = .idle
    private(set) var lastSavedDate: Date? = nil
    private(set) var currentRating: Int = 0
    private(set) var currentColorLabel: PhotoColorLabel? = nil
    private(set) var shouldDismiss: Bool = false
    var isOverlayVisible: Bool = true
    let isRatingEnabled: Bool

    // 派生プロパティ
    var currentURL: URL { allURLs[currentIndex] }
    var currentFileName: String { currentURL.lastPathComponent }
    var canGoPrevious: Bool { currentIndex > 0 }
    var canGoNext: Bool { currentIndex < allURLs.count - 1 }
}
```

`init(input: PhotoViewerInput, services: PhotoViewerServices)` で `allURLs`・`currentIndex`（`initialURL` の位置）・`isRatingEnabled`・評価/カラーラベルフィルタを初期化する。

**ViewModel のメソッド：**

| メソッド                                  | 処理                                                                                          |
|--------------------------------------------|-----------------------------------------------------------------------------------------------|
| `loadInitial() async`                      | 初期表示の画像・Exif をバックグラウンドで読み込む（VC 準備後に1回呼ぶ）                       |
| `navigatePrevious() async`                 | `previousOrientation` を保存後に `currentIndex` をデクリメントし画像・Exifを再読み込みする    |
| `navigateNext() async`                     | `previousOrientation` を保存後に `currentIndex` をインクリメントし画像・Exifを再読み込みする  |
| `didSwipeTo(index: Int, image: UIImage?) async` | スワイプ後、画像は既に表示済みとして Exif のみ再読み込み。`previousOrientation` は nil にリセット |
| `setRating(_ stars: Int) async`            | 星評価を設定。同じ値を再度指定すると 0（解除）。`ratingStore` へ永続化後、フィルタ外なら自動遷移 |
| `setColorLabel(_ label: PhotoColorLabel) async` | カラーラベルを設定。同じ値を再度指定すると nil（解除）。`colorLabelStore` へ永続化後、フィルタ外なら自動遷移 |
| `save() async`                              | 権限確認後に現在の写真を写真ライブラリへ保存し `saveStatus`・`lastSavedDate` を更新、触覚フィードバックを発行 |
| `toggleOverlay()`                          | `isOverlayVisible` を反転する                                                                 |

**評価・カラーラベルフィルタと自動遷移：** ViewModel は `PhotoViewerInput` 由来の `ratingFilter`/`colorLabelFilter` を保持する。`setRating`/`setColorLabel` で写真が現在のフィルタ条件に合わなくなった場合、`autoNavigateIfFilteredOut()` が呼ばれ、前方→後方の順でフィルタに一致する最も近い写真へ自動的に遷移する。一致する写真が他に無い場合は `shouldDismiss = true` となり、VC がフォトビューアを閉じる。

### PhotoViewerViewController の updateProperties

`PhotoViewerViewController` は `updateProperties()`（`UIViewController.updateProperties()`、Observation 駆動）をオーバーライドし、以下をすべて `viewModel` から同期する：

```swift
override func updateProperties() {
    super.updateProperties()
    photoInfoPillView.configure(fileName: viewModel.currentFileName, exifInfo: viewModel.exifInfo)
    prevButtonView.button.isEnabled = viewModel.canGoPrevious
    nextButtonView.button.isEnabled = viewModel.canGoNext
    updateSaveButton(status: viewModel.saveStatus)
    ratingLabelBarView.setRating(viewModel.currentRating)
    ratingLabelBarView.setColorLabel(viewModel.currentColorLabel)
    lastSavedDateLabel.text = /* viewModel.lastSavedDate をフォーマット */
    lastSavedDateLabel.isHidden = viewModel.lastSavedDate == nil
    viewModel.isLoading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
    updateOverlayVisibility(visible: viewModel.isOverlayVisible)
    if viewModel.shouldDismiss { dismiss(animated: true) }
    // 現在セルへの画像・サムネイル反映
}
```

---

## 表示レイアウト

- `view.backgroundColor = .black`。
- `preferredTransition = .zoom` を伴ってフルスクリーン表示する（呼び出し元でサムネイルセルとの拡大トランジションを構成）。
- ステータスバーはオーバーレイの表示状態に連動して表示・非表示を切り替える（`prefersStatusBarHidden`・`setNeedsStatusBarAppearanceUpdate()`）。
- ビュー階層：

```
view（黒背景）
  ├── UICollectionView（横スクロール・ページング、写真のページング表示）
  │     └── PhotoPageItemCell（各ページ）
  │           └── PhotoZoomScrollView（写真のズーム・パン）
  │                 └── UIImageView（写真）
  └── 各フローティング要素（view に直接追加、UICollectionView より前面）
        ├── 閉じるボタン（GlassButtonView、左上）
        ├── 画面回転ボタン（GlassButtonView、ファイル名 + Exif パネルの左隣・右上）
        ├── ファイル名 + Exif パネル（PhotoInfoPillView、右上）
        ├── サムネイル（UIImageView、パネルの下・右寄せ）
        ├── 前へボタン（GlassButtonView + 拡大ヒットエリア、左下）
        ├── 次へボタン（GlassButtonView + 拡大ヒットエリア、右下）
        ├── 保存ボタン（GlassButtonView、下部中央）
        ├── 評価・カラーラベルバー（RatingLabelBarView、保存ボタンの上。isRatingEnabled時のみ）
        ├── ローディングインジケーター（UIActivityIndicatorView、評価バー or 保存ボタンの上）
        └── 最終保存日時ラベル（lastSavedDateLabel、保存ボタンの下）
```

各フローティング要素はボタンが配置されていない領域のタッチを下層のスクロールビューへ自然に伝播させる。

---

## ページング（UICollectionView）

写真間の移動は `UIPageViewController` ではなく、横スクロール・ページング設定の `UICollectionView`（`UICollectionViewFlowLayout`、`interPageSpacing = 16`）で行う。

| ナビゲーション種別 | セルの扱い                                                                 | ズーム状態                                               |
|--------------------|---------------------------------------------------------------------------|------------------------------------------------------------|
| 前後ボタン         | 同じ `PhotoPageItemCell` を再利用し、`index` を更新して画像を上書き        | 同じ向きの場合は維持、向きが変わった場合はリセット        |
| 左右スワイプ       | `UICollectionView` が隣接セルを自然に表示（`didSwipeTo(index:image:)` で通知） | 常にリセット（`previousOrientation = nil`）              |

前後ボタンには長押しジェスチャー（`UILongPressGestureRecognizer`、`minimumPressDuration = 1.0`）による連続ナビゲーション（0.12秒間隔で自動送り）が拡大ヒットエリア（`prevHitAreaButton`/`nextHitAreaButton`）に設定されている。

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

| 遷移パターン                                          | 挙動                                                                     |
|-------------------------------------------------------|--------------------------------------------------------------------------|
| 初回表示（`previousOrientation` が nil）              | `resetZoom(for:)` でズームをリセット                                      |
| 向きが変わった場合（縦 ↔ 横）                          | `resetZoom(for:)` でズームをリセット                                      |
| 向きが同じ場合（縦 → 縦、横 → 横）                    | `updateZoomForSameOrientation(for:)` で現在のズーム比率を新しい画像に適用 |

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
- 制約：`top` = `view.safeAreaLayoutGuide.topAnchor` + 12pt、`leading` = `view.safeAreaLayoutGuide.leadingAnchor` + 16pt

### 画面回転ボタン（ファイル名 + Exif パネルの左隣）

- `GlassButtonView.circle(systemImageName:)`。タップエリアの拡張は無し（44×44）。
- 制約：`top` = `safeArea` + 12pt（`photoInfoPillView`・`closeButtonView` と同じ）、`trailing` = `photoInfoPillView.leading` - 8pt。
- タップするたびに画面回転設定を「端末の設定に追従」→「縦画面固定」→「横画面固定」→（最初に戻る）の順に循環させる（`PhotoViewerViewModel.cycleOrientationLock()`）。設定は `UserDefaultsSettings.orientationLock`（`PhotoViewerOrientationLock`、デフォルト `.followSystem`）として永続化され、次回フォトビューア表示時にも引き継がれる。この設定が影響するのはフォトビューア画面のみで、他の画面は常に端末の設定に従う。
- アイコンは現在の状態を表す（`updateProperties()` で反映）：

  | 状態             | アイコン（SF Symbols）      |
  |------------------|------------------------------|
  | 端末の設定に追従 | `arrow.triangle.2.circlepath` |
  | 縦画面固定       | `iphone`                     |
  | 横画面固定       | `iphone.landscape`           |

**回転の反映方法：**

- `PhotoViewerViewController.supportedInterfaceOrientations` を `viewModel.orientationLock` に応じてオーバーライドする（`.followSystem` は `super.supportedInterfaceOrientations` でInfo.plist準拠の端末設定、`.portrait` は `.portrait`、`.landscape` は `.landscape`）。
- 許可範囲を絞るだけでは実際には回転しないため、`windowScene.requestGeometryUpdate(.iOS(interfaceOrientations:))` を能動的に呼んで回転を発生させる（ボタンタップ時・表示直後の `viewDidAppear` で発火。`setNeedsUpdateOfSupportedInterfaceOrientations()` とセットで呼ぶ）。
- 縦/横固定中（`.followSystem` 以外）にフォトビューアを閉じる場合、コントロールセンターの回転ロック（縦固定）を一時的に上書きしていた可能性があるため、`presentingViewController` の許容範囲へ `requestGeometryUpdate` を出し直し、遷移先画面が向きを引き継がないようにする。dismissアニメーション中に発行すると進行中のビュー階層と衝突して表示が崩れるため、`transitionCoordinator` のトランジション完了コールバックで発行する。それ以外（`.followSystem`）の場合はUIKit標準の再評価に任せる。
- `SceneDelegate.windowScene(_:didUpdateEffectiveGeometry:)`（実体は`AppMain.handleWindowSceneGeometryChange(_:)`）で、ジオメトリ変化のたびに`rootViewController.view.setNeedsLayout()`を呼び通常のレイアウトパスに再計算を促す（`window.frame`/`UIScreen`は直接読み書きしない）。詳細は [画面回転制御の実装知見](orientation-control.md) を参照。

### ファイル名 + Exif パネル（右上・PhotoInfoPillView）

`Modules/Sources/PhotoViewer/Views/PhotoInfoPillView.swift`。従来の素の `UIVisualEffectView` パネルを置き換え、共通の `GlassBackdropView`（`cornerRadius: 16`）を背景に使う。

- 内部に縦 `UIStackView` で `fileNameLabel`（callout・白文字・1行）・`exifLabel`（caption1・白75%透過・Exif取得0件なら非表示）を配置する。
- Exif ラベルは `iso · focalLength · exposureValue · fNumber · shutterSpeed` を連結し、`flashFired` が true の場合は末尾に `"  ⚡️"` を付与する。
- パネル全体に透明な `copyButton` を重ねており、タップでファイル名＋Exifの整形テキストをクリップボードへコピーし、中程度の触覚フィードバック（`UIImpactFeedbackGenerator`）と `ToastKit` によるトースト通知（クリップボードアイコン＋コピー完了メッセージ）を発行する。
- パネル自身の `leadingAnchor` はコンテンツ幅（ファイル名・Exifの長さ）に応じて収縮する（内部でガラス背景の `leadingAnchor` と一致させているため）。外側からは `trailing` を固定し、`leading` は他要素との重なりを防ぐための床（下限）のみを与える。
- 制約：`top` = `safeArea` + 12pt、`trailing` = `view.safeAreaLayoutGuide.trailingAnchor` - 16pt、`leading` ≥ `closeButtonView.trailing` + 8pt、`height` ≥ 44pt。

### サムネイル（パネルの下・右寄せ）

- `contentMode = .scaleAspectFit`、最大辺 80pt でアスペクト比を維持。
- 制約：`top` = `photoInfoPillView.bottom` + 8pt、`trailing` = `photoInfoPillView.trailing`。
- 現在表示中の写真がズームされている場合のみ表示する（`isHidden` で制御。ズーム倍率は `PhotoPageItemCell.isZoomed`）。ズーム状態の変化は `PhotoZoomScrollView.onZoomChange` → `PhotoPageItemCellDelegate.pageItemCellDidChangeZoom(_:)` 経由で通知される。オーバーレイの表示・非表示に伴う `alpha` アニメーションとは独立して制御する。

### 前へ／次へボタン（左下・右下）

- `GlassButtonView.circle(systemImageName: "chevron.left"/"chevron.right")`
- 制約：`bottom` = `safeArea` - 20pt、`leading`/`trailing` = `view.safeAreaLayoutGuide` ± 16pt
- ビジュアルボタンの前面に透明な拡大ヒットエリア（`prevHitAreaButton`/`nextHitAreaButton`、上下左右に数十pt拡張）を重ね、通常タップと長押し連続送りの両方を検出する。

### 保存ボタン（下部中央）

- `GlassButtonView`（カプセル形、`cornerRadius = 22`）
- ボタン構成：`UIButton.Configuration.borderless()`、タイトルテキスト、左右パディング 20pt
- テキストカラー：常に白（`configurationUpdateHandler` で disabled 時の自動調光を抑制）
- 制約：`bottom` = `safeArea` - 20pt、`centerX` = `view.centerXAnchor`、`leading` ≥ `prevButtonView.trailing` + 8pt、`trailing` ≤ `nextButtonView.leading` - 8pt、`height` = 44pt

### 評価・カラーラベルバー（RatingLabelBarView、保存ボタンの上）

`Modules/Sources/PhotoViewer/Views/RatingLabelBarView.swift`。`viewModel.isRatingEnabled` が true の場合のみ追加する。`GlassBackdropView`（`cornerRadius: 16`）ベースの横長カプセル、高さ32pt。

- 星ボタン5個（`star`/`star.fill`、24×32pt、tag 1〜5）
- 縦の区切り線
- カラーラベルボタン6個（`circle.fill`/`circle.inset.filled`、24×32pt、`PhotoColorLabel` の色でtint）
- タップは UIMenu ではなく直接の `UIButton.touchUpInside`。`onStarTapped`/`onColorTapped` コールバック経由で `viewModel.setRating`/`setColorLabel` を呼ぶ（トグルオフのロジックは ViewModel 側が持つ）。
- 制約（縦持ち）：`bottom` = `saveButtonView.top` - 8pt、`centerX` = `view.centerXAnchor`。`saveButtonView.centerX` も `view.centerXAnchor` に揃える。
- 制約（横持ち）：`centerY` = `saveButtonView.centerYAnchor`、`trailing` = `saveButtonView.leading` - 8pt（保存ボタンと左右に並ぶ）。`saveButtonView` 単体は中央揃えせず、`bottomBarGroupGuide`（不可視の `UILayoutGuide`。`leading` = `ratingLabelBarView.leading`、`trailing` = `saveButtonView.trailing`）の `centerX` を `view.centerXAnchor` に揃えることで、レーティングバー＋保存ボタンの組を左右中央に配置する。
- 縦持ち/横持ちの切り替えは `PhotoViewerViewController.viewWillLayoutSubviews()` 内で `view.bounds.width > view.bounds.height` を判定し、該当する制約セットを activate/deactivate して行う。

### ローディングインジケーター

- `UIActivityIndicatorView(style: .medium)`、白、`hidesWhenStopped = true`
- 制約：`centerX` = `saveButtonView.centerXAnchor`
- `bottom`（縦持ち）：`ratingLabelBarView` があればその上 - 8pt、無ければ `saveButtonView` の上 - 8pt
- `bottom`（横持ち）：`isRatingEnabled` の有無に関わらず常に `saveButtonView` の上 - 8pt（横持ちではレーティングバーが保存ボタンの上ではなく横に並ぶため）

### 最終保存日時ラベル（保存ボタンの下）

- `lastSavedDateLabel`（caption2）。`viewModel.lastSavedDate` が nil の場合は非表示。
- 制約：`top` = `saveButtonView.bottom` + 4pt、`centerX` = `view.centerXAnchor`

---

## GlassBackdropView（ガラス背景の共通コンポーネント）

`Modules/Sources/PhotoViewer/Views/GlassBackdropView.swift`。半透明の黒レイヤー（`alpha 0.4`）の上に `UIGlassEffect(style: .clear)` の `UIVisualEffectView`（`overrideUserInterfaceStyle = .dark`）を重ねた「座布団」。`contentView` を公開し、呼び出し側がその上にサブビューを積む。`GlassButtonView`・`PhotoInfoPillView`・`RatingLabelBarView` が共通で利用し、各所に重複していたガラス調背景の実装を集約している。

## GlassButtonView の仕様

```swift
final class GlassButtonView: UIView {
    let button: UIButton
}
```

- 背景は `GlassBackdropView` を利用する。
- `cornerRadius`：コンストラクタ引数で指定（デフォルト 22）。

**circle ファクトリメソッド：**

```swift
static func circle(systemImageName: String) -> GlassButtonView
```

- 44 × 44pt の正円ボタンを生成する
- `baseForegroundColor = .white`

---

## オーバーレイの表示・非表示

- `viewModel.isOverlayVisible` の変化を `updateProperties()` で検知する。
- `UIView.animate(withDuration: 0.2)` で閉じるボタン・画面回転ボタン・前後ボタン（ヒットエリア含む）・`photoInfoPillView`・サムネイル・保存ボタン・`ratingLabelBarView`・`lastSavedDateLabel` の `alpha` を 0.0 / 1.0 に切り替える。
- オーバーレイが非表示の場合はステータスバーも非表示にする（`prefersStatusBarHidden` で制御）。
- `updateProperties()` 内で `setNeedsStatusBarAppearanceUpdate()` を呼ぶ。

---

## ジェスチャー認識

タップ系ジェスチャーは各ページの `PhotoPageItemCell`（`zoomScrollView`）に追加し、`PhotoPageItemCellDelegate` 経由で VC に通知する。

| ジェスチャー         | 認識クラス                                              | 挙動                                                                     |
|----------------------|-----------------------------------------------------------|--------------------------------------------------------------------------|
| シングルタップ       | `UITapGestureRecognizer`（`numberOfTapsRequired = 1`）    | `viewModel.toggleOverlay()` を呼ぶ                                       |
| ダブルタップ         | `UITapGestureRecognizer`（`numberOfTapsRequired = 2`）    | ズームイン or ズームリセット                                              |
| ピンチ               | `UIScrollView` 組み込み                                   | ズームイン・ズームアウト                                                   |
| 前/次ボタン長押し    | `UILongPressGestureRecognizer`（`minimumPressDuration = 1.0`）、ヒットエリア上 | 0.12秒間隔で `navigatePrevious()`/`navigateNext()` を連続実行 |
| ドラッグズーム       | `UILongPressGestureRecognizer`（`minimumPressDuration = 0.5`）、`UICollectionView` 上 | 縦方向ドラッグ量からズームスケールを連続変更（`exp((dx-dy)*0.01)`） |

- シングルタップは `require(toFail:)` でダブルタップ認識の失敗を待つ。
- `presentationController?.delegate = self` により、ズーム中は `presentationControllerShouldDismiss` が `false` を返し、スワイプでの誤ドロー・ダウン・ドミスを防止する。

### ダブルタップの挙動

| 現在の状態                              | 挙動                                                                                        |
|-----------------------------------------|-----------------------------------------------------------------------------------------------|
| `minimumZoomScale`（全体表示）に近い状態 | タップした位置を中心に `maximumZoomScale` へズームイン（`zoom(to:animated:)` でアニメーション） |
| ズーム中                                | `setZoomScale(minimumZoomScale, animated: true)` で全体表示に戻す                             |

「ズーム中」の判定は `zoomScale > minimumZoomScale + 0.001` とする。

---

## 写真間のナビゲーション

- `navigatePrevious()` / `navigateNext()` は先頭・末尾の境界チェック（`canGoPrevious` / `canGoNext`）を内部で行う。
- ナビゲーション前に `previousOrientation = currentImage?.photoOrientation` を保存する。
- ナビゲーション後に `saveStatus = .idle` にリセットする。
- 前後ボタンの `tintColor`：有効時は `.white`、無効時は `.systemGray`。

---

## 評価・カラーラベルの設定（ViewModel の `setRating`/`setColorLabel`）

- `setRating(_ stars: Int)`：現在値と同じ場合は 0（解除）にする。`PhotoRatingStoreProtocol.setRating(_:for:)` で永続化後、`autoNavigateIfFilteredOut()` を呼ぶ。
- `setColorLabel(_ label: PhotoColorLabel)`：現在値と同じ場合は nil（解除）にする。`ColorLabelStoreProtocol.setLabel(_:for:)` で永続化後、`autoNavigateIfFilteredOut()` を呼ぶ。
- `autoNavigateIfFilteredOut()`：`ratingFilter`/`colorLabelFilter` が設定されている場合のみ動作。現在の写真が条件を満たさなくなったら、後方→前方の順で最も近い一致写真へ遷移する。一致する写真が無ければ `shouldDismiss = true`。

---

## 写真保存（ViewModel の `save() async`）

```swift
func save() async {
    guard currentImage != nil else { return }
    let url = currentURL
    saveStatus = .saving
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
        saveStatus = .failure
        hapticsService.notifyError()
        return
    }
    do {
        try await photoLibrary.save(fileURL: url)
        let now = Date()
        savedDateStore.setDate(now, for: url)
        lastSavedDate = now
        saveStatus = .success
        hapticsService.notifySuccess()
        try await Task.sleep(for: .seconds(2))
        saveStatus = .idle
    } catch {
        saveStatus = .failure
        hapticsService.notifyError()
    }
}
```

- `PhotoLibraryServiceProtocol.save(fileURL:)` が `PHAssetCreationRequest` + `addResource(with: .photo, fileURL:, options:)` でオリジナルデータをそのまま保存する（`options.originalFilename` で元ファイル名を保持、再エンコードなし）。
- 保存フォーマット設定が `.jpegAndRaw` の場合、同名の RAW ファイル（対応拡張子: dng/arw/cr2/cr3/nef/orf/raf/rw2/pef/srw/3fr）が同フォルダに存在すれば併せて保存する。
- 保存成功・失敗を `HapticsServiceProtocol` の触覚フィードバックで通知する。
- 保存成功後、`SavedDateStore` に保存日時を記録し `lastSavedDate` を更新、2 秒後に `saveStatus = .idle` に戻す（`Task.sleep(for: .seconds(2))`）。

### 保存ボタンの状態遷移

| 状態      | ボタン表示テキスト | ボタン有効/無効 | 次の遷移                           |
|-----------|-------------------|-----------------|-------------------------------------|
| `.idle`   | `↓ 保存`          | 有効            | タップで `.saving` へ              |
| `.saving` | `⏳ 保存中...`    | 無効            | 完了後 `.success` または `.failure` へ |
| `.success`| `✓ 保存完了`      | 無効            | 2 秒後に自動で `.idle` へ          |
| `.failure`| `✕ 失敗`          | 有効（再試行可能） | タップで `.saving` へ             |

---

## 画像・Exif のロード（ViewModel の `loadImageAndExif`）

- `ImageLoaderServiceProtocol.loadImage(from:)` と `ExifServiceProtocol.extractExif(from:)` を並行してバックグラウンドで読み込む。両サービスとも `FileLoadingTracker` に処理を登録し、`isLoading` の重複解除を防ぐ。
- `isLoading = true` → 画像・Exif 取得 → `currentImage`・`exifInfo` 更新 → `isLoading = false` の順で更新する。
- セキュリティスコープドアクセスは `FileBrowserViewModel` が保持しているため、追加のスコープ取得は不要。
- スワイプ後の `didSwipeTo(index:image:)` は画像がすでに表示済みのため Exif のみ再取得する。

---

## Exif 情報の抽出

`ExifServiceProtocol`（`CGImageSource`）が JPEG データから直接 Exif メタデータを抽出する（画像デコード不要）。

| フィールド     | Exif キー                              | フォーマット例                                                |
|---------------|----------------------------------------|--------------------------------------------------------------|
| ISO 感度      | `kCGImagePropertyExifISOSpeedRatings`  | 配列の先頭要素を取得。`"ISO 400"`                             |
| 焦点距離      | `kCGImagePropertyExifFocalLength`      | `Double`。`"%.0fmm"` → `"50mm"`                              |
| 露出補正      | `kCGImagePropertyExifExposureBiasValue`| `Double`。0 の場合は `"±0EV"`、それ以外は `"%+.1fEV"` → `"+1.0EV"` |
| F 値          | `kCGImagePropertyExifFNumber`          | `Double`。`"f/%.1f"` → `"f/2.8"`                             |
| シャッタースピード | `kCGImagePropertyExifExposureTime` | `Double`（秒）。1秒以上は `"%.0fs"` → `"2s"`、1秒未満は `"1/\(round(1/et))s"` → `"1/125s"` |
| フラッシュ    | `kCGImagePropertyExifFlash`            | 発光ビットを判定し `flashFired: Bool` を設定                  |

Exif ディクショナリ自体が取得できない場合は `nil` を返す（Exif ラベルは非表示になる）。

---

## トースト通知（ToastKit）

`Modules/Sources/ToastKit/` に実装されたトースト表示の仕組み。`UIWindow`（`windowLevel = .alert + 1`）にSwiftUIビューをホストし、複数トーストはキューで直列表示する。

**公開 API：**

```swift
ToastKit.setup(windowScene: UIWindowScene)                       // 起動時に一度だけ呼ぶ
ToastKit.show(duration: TimeInterval? = nil) { /* SwiftUI View */ }
```

**現在の呼び出し箇所：** `PhotoInfoPillView` のファイル名＋Exifコピー時のみ（クリップボードアイコン＋コピー完了メッセージ）。保存成功・失敗や評価変更はトーストではなく、保存ボタンの表示・触覚フィードバック・`lastSavedDateLabel` で通知する。

---

## ステータスバーの挙動

```swift
override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
override var prefersStatusBarHidden: Bool { !viewModel.isOverlayVisible }
```

- `preferredStatusBarStyle` は常に `.lightContent`（白色）。
- `prefersStatusBarHidden` はオーバーレイが非表示の場合に `true` を返す。
- オーバーレイ切り替え時に `setNeedsStatusBarAppearanceUpdate()` を呼ぶ。

---

## 画面ロック防止

- `viewWillAppear(_:)` で `UIApplication.shared.isIdleTimerDisabled = true` を設定し、写真閲覧中に画面が自動ロックされないようにする。
- `viewWillDisappear(_:)` で `UIApplication.shared.isIdleTimerDisabled = false` に戻す。
