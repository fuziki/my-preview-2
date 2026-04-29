# ファイルブラウザ画面の挙動仕様（UIKit 版）

## 画面概要

アプリのメイン画面。ユーザーが選択したフォルダ内の JPEG 画像を `UICollectionView` でリスト表示する。
リストには **JPEG 画像のみ** を表示する（フォルダ・その他のファイルは非表示）。
サブフォルダ内への画面遷移は行わない。フォルダの変更はフローティングボタンから `UIDocumentPickerViewController` を介してのみ行う。

**クラス名：** `FileBrowserViewController`
**ViewModel：** `FileBrowserViewModel`

---

## MVVM 構成

### FileBrowserViewModel（@Observable）

```swift
@Observable
final class FileBrowserViewModel {
    private(set) var items: [FileItem] = []
    private(set) var hasFolder: Bool = false
    private var rootURL: URL? = nil
}
```

**ViewModel のメソッド：**

| メソッド                         | 処理                                                                       |
|----------------------------------|----------------------------------------------------------------------------|
| `selectFolder(_ url: URL) async` | セキュリティスコープを取得し `loadItems()` を呼ぶ。前の権限を先に解放する |
| `loadItems() async`              | `rootURL` 配下の JPEG 画像を読み込み `items` を更新する                   |

### FileBrowserViewController の updateProperties

`FileBrowserViewController` は `updateProperties()` をオーバーライドし、`viewModel` のプロパティ変化を UI に反映する。

```swift
override func updateProperties() {
    super.updateProperties()
    // viewModel プロパティへのアクセスがここで追跡される
    let hasFolder = viewModel.hasFolder
    collectionView.isHidden = !hasFolder
    emptyStateView.isHidden = hasFolder
}
```

`items` の変更については、`updateProperties()` の外で `UICollectionViewDiffableDataSource` の `apply()` を呼び、差分更新する。`items` の変更を `observe` するには、`withObservationTracking` を用いるか、専用の監視タスクで `items` の変化を検知して `apply()` を呼ぶ。

`viewModel` の `@Observable` プロパティが変化すると、システムが自動的に `setNeedsUpdateProperties()` を呼び出し、次のランループで `updateProperties()` が実行される。

---

## 表示状態

### フォルダ未選択時（空状態）

- 画面中央に `EmptyStateView` を表示する。
  - ストレージアイコン（`UIImageView`、`externaldrive` システムアイコン）
  - 「フォルダを選択してください」テキスト（`UILabel`）
  - ボタン類は表示しない。
- `UICollectionView` は非表示にする。
- ナビゲーションタイトルは「My Preview」（固定）。
- フローティングボタンは空状態でも常に表示する。

### フォルダ選択後

- `EmptyStateView` を非表示にする。
- `UICollectionView` を表示し、選択したフォルダ内の JPEG 画像をリスト表示する。
- ナビゲーションタイトルは「My Preview」（固定）。

---

## ViewController 構成

```
UINavigationController
  └── FileBrowserViewController（唯一の画面）
```

- `FileBrowserViewController` が `UINavigationController` のルートとなる。
- サブフォルダへの遷移は行わないため、`UINavigationController` のプッシュ遷移は使用しない。
- セキュリティスコープドアクセス権限は `FileBrowserViewModel` が一元管理する。

---

## ナビゲーションバー

- ナビゲーションバーにはタイトル「My Preview」のみ表示する。
- `UIBarButtonItem` は配置しない。

---

## フローティングボタン（フォルダを開く）

- Safe Area 内の **左下隅** に固定配置するフローティングボタン（`UIButton`）を設置する。
- アイコン：`folder.badge.plus`（または `folder` 系のシステムアイコン）
- **iOS 26 の Liquid Glass エフェクト**（`UIGlassEffect` / `GlassEffectView` 相当）を適用する。
  - 背景に半透明のガラス調マテリアルエフェクトを適用する。
  - ボタン形状は円形またはカプセル形とする。
- 制約（Auto Layout）：
  - `leading` = `view.safeAreaLayoutGuide.leadingAnchor` + 16pt
  - `bottom` = `view.safeAreaLayoutGuide.bottomAnchor` - 16pt
  - 幅・高さ：56 × 56pt（円形）
- タップすると `UIDocumentPickerViewController` を表示する。
- 空状態・フォルダ選択後を問わず、常に表示する。

### フローティングボタンとリストのかぶり対策

- `FileBrowserViewController` の `additionalSafeAreaInsets.bottom` を `ボタン高さ (56pt) + 上下マージン (16pt × 2) = 88pt` 以上に設定する。
- `UICollectionView` の `contentInsetAdjustmentBehavior = .automatic` により、拡張された Safe Area が自動的にスクロール領域に反映される。
- これにより `contentInset.bottom` を手動管理することなく、リストの最下部アイテムがフローティングボタンの上方に収まる。

---

## フォルダ選択ダイアログ

- `UIDocumentPickerViewController` を使用する。
  - `forOpeningContentTypes: [.folder]`
  - `allowsMultipleSelection = false`
- フォルダを選択すると ViewController 側で `Task { await viewModel.selectFolder(url) }` を呼ぶ。
- 既にフォルダが選択済みの場合でも、新しいフォルダを選択し直せる。
- 前のフォルダへのセキュリティスコープ解放は `FileBrowserViewModel.selectFolder()` 内で行う。

---

## ファイルリスト（UICollectionView）

### 表示対象

リストには **JPEG 画像のみ** を表示する。フォルダ・その他のファイルは一切表示しない。

### レイアウト設定

- `UICollectionLayoutListConfiguration` を使用してリストレイアウトを構築する。
  - `appearance: .plain`（プレーンスタイル）
  - セパレーターラインを標準表示する。
- `UICollectionView` は `view` の全面に配置する（Safe Area を突き抜けて edge-to-edge）。
  - `contentInsetAdjustmentBehavior = .automatic`（ナビゲーションバー下から開始）

### データソース

- `UICollectionViewDiffableDataSource<Section, FileItem>` を使用する。
  - セクションは単一（`Section.main`）。
- `viewModel.items` の変化を検知したら `NSDiffableDataSourceSnapshot` を生成し `apply()` で差分更新する。

### セル（UICollectionViewListCell）

- `UICollectionViewListCell` をカスタム設定して使用する。
- `defaultContentConfiguration()` で取得した `contentConfiguration` に以下を設定する：
  - `image`：`photo` システムアイコン（`tintColor = .systemBlue`）
  - `text`：ファイル名（1 行、`lineBreakMode = .byTruncatingMiddle`）

### タップ処理

- `UICollectionViewDelegate` の `collectionView(_:didSelectItemAt:)` で処理する。
- 選択状態のハイライトを残さないよう `deselectItem(at:animated:)` を即座に呼ぶ。
- `viewModel.items` から全 URL リストを取得し、タップしたアイテムの URL を初期表示 URL として `PhotoViewerInput` を生成する。
- `PhotoViewerViewController` を生成し `modalPresentationStyle = .fullScreen` でモーダル表示する。

---

## ファイル読み込み処理（ViewModel の `loadItems() async`）

```swift
func loadItems() async {
    guard let url = rootURL else { return }
    let loaded = await Task.detached(priority: .userInitiated) {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        return (contents ?? [])
            .filter { ["jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { FileItem(url: $0) }
    }.value
    await MainActor.run {
        self.items = loaded
    }
}
```

- `Task.detached` でバックグラウンドスレッドでファイル列挙・フィルター・ソートを実行する。
- 結果は `MainActor.run` でメインスレッドに戻してから `items` を更新する。
