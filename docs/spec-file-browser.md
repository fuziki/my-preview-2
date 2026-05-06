# ファイルブラウザ画面の仕様

## 画面概要

アプリのメイン画面。ユーザーが選択したフォルダ内の JPEG 画像を `UICollectionView` でリスト表示する。
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

| メソッド                         | 処理                                                                                          |
|----------------------------------|-----------------------------------------------------------------------------------------------|
| `selectFolder(_ url: URL) async` | 前のセキュリティスコープを解放し、新しいスコープを取得後に `loadItems()` を呼ぶ               |
| `loadItems() async`              | `rootURL` 配下の JPEG 画像をバックグラウンドで列挙・ソートし `items` をメインスレッドで更新する |

### FileBrowserViewController の updateProperties

`FileBrowserViewController` は `updateProperties()` をオーバーライドし、`viewModel.hasFolder` の変化を UI に反映する。

```swift
override func updateProperties() {
    super.updateProperties()
    let hasFolder = viewModel.hasFolder
    collectionView.isHidden = !hasFolder
    emptyStateView.isHidden = hasFolder
}
```

### items の変化の監視

`viewModel.items` の変化は `updateProperties()` の外で `withObservationTracking` を用いて監視し、変化のたびに DiffableDataSource の `apply()` を呼んで差分更新する。変化後は `withObservationTracking` を再登録して継続的に監視する。

```swift
private func startObservingItems() {
    withObservationTracking {
        _ = viewModel.items
    } onChange: { [weak self] in
        Task { @MainActor [weak self] in
            self?.applySnapshot()
            self?.startObservingItems()
        }
    }
}
```

---

## 表示状態

### フォルダ未選択時（空状態）

- 画面全体に `EmptyStateView` を表示する。
  - ストレージアイコン（`externaldrive` システムアイコン）
  - 「フォルダを選択してください」テキスト（`UILabel`）
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
  └── FileBrowserViewController（唯一の ViewController）
```

- `FileBrowserViewController` が `UINavigationController` のルートとなる。
- サブフォルダへの遷移は行わないため、`UINavigationController` のプッシュ遷移は使用しない。

---

## ナビゲーションバー

- タイトル「My Preview」のみ表示する。
- `UIBarButtonItem` は配置しない。

---

## フローティングボタン（フォルダを開く）

- Safe Area 内の **左下隅** に固定配置するフローティングボタンを設置する。
- アイコン：`folder` システムアイコン
- **iOS 26 の Liquid Glass エフェクト**（`UIButton.Configuration.prominentGlass()`）を適用する。
- サイズ：56 × 56pt（円形）
- 制約（Auto Layout）：
  - `leading` = `view.safeAreaLayoutGuide.leadingAnchor` + 16pt
  - `bottom` = `view.safeAreaLayoutGuide.bottomAnchor` + `folderButtonSize`（56pt）
- タップすると `UIDocumentPickerViewController` を表示する。
- 空状態・フォルダ選択後を問わず、常に表示する。

### フローティングボタンとリストのかぶり対策

- `FileBrowserViewController` の `additionalSafeAreaInsets.bottom` を `folderButtonSize + 32`（88pt）に設定する。
- `UICollectionView` の `contentInsetAdjustmentBehavior = .automatic` により、拡張された Safe Area が自動的にスクロール領域に反映される。
- これにより `contentInset.bottom` を手動管理することなく、リスト末尾のアイテムがフローティングボタンの上方に収まる。

---

## フォルダ選択ダイアログ

- `UIDocumentPickerViewController` を使用する。
  - `forOpeningContentTypes: [.folder]`
  - `allowsMultipleSelection = false`
- フォルダを選択すると `documentPicker(_:didPickDocumentsAt:)` が呼ばれ、`Task { await viewModel.selectFolder(url) }` を実行する。
- 既にフォルダが選択済みの場合でも、新しいフォルダを選択し直せる。
- 前のフォルダへのセキュリティスコープ解放は `FileBrowserViewModel.selectFolder()` 内で行う。

---

## ファイルリスト（UICollectionView）

### 表示対象

リストには **JPEG 画像のみ** を表示する。フォルダ・その他のファイルは一切表示しない。

### レイアウト設定

- `UICollectionLayoutListConfiguration` を使用してリストレイアウトを構築する。
  - `appearance: .plain`（プレーンスタイル）
  - セパレーターラインを標準表示する（`showsSeparators = true`）
- `UICollectionView` は `view` の全面に配置する（edge-to-edge）。
  - `contentInsetAdjustmentBehavior = .automatic`

### データソース

- `UICollectionViewDiffableDataSource<Section, FileItem.ID>` を使用する。
  - セクション型 `Section` は `nonisolated enum`、値は単一（`.main`）。
  - 識別子は `FileItem.ID`（`UUID`）を使用する。
- `viewModel.items` の変化を検知したら `NSDiffableDataSourceSnapshot` を生成し `apply(animatingDifferences: true)` で差分更新する。

### セル（UICollectionViewListCell）

- `UICollectionViewListCell` を `CellRegistration` で使用する。
- `defaultContentConfiguration()` で取得した `contentConfiguration` に以下を設定する：
  - `image`：`photo` システムアイコン（`tintColor = .systemBlue`）
  - `text`：ファイル名（1 行、`lineBreakMode = .byTruncatingMiddle`）

### タップ処理

- `UICollectionViewDelegate` の `collectionView(_:didSelectItemAt:)` で処理する。
- `deselectItem(at:animated:)` を即座に呼んでハイライト状態を解除する。
- `dataSource.itemIdentifier(for:indexPath)` で `FileItem.ID` を取得し、`viewModel.items` から対応する URL を特定する。
- `viewModel.items` から全 URL リストを取得して `PhotoViewerInput` を生成する。
- `PhotoViewerViewController` を生成し `modalPresentationStyle = .fullScreen` でモーダル表示する。

---

## セクションヘッダー（SectionHeaderView）

### 外観

- `UIGlassEffect` を使用したガラス形態素のピルバッジ（高さ 32pt、角丸 16pt）を左端に配置する。
- ガラスバッジ内にはローカライズされた日付テキストと `chevron.up.chevron.down` アイコンを横並びで表示する。
- ヘッダーはスクロール中も画面上部に固定される（`pinToVisibleBounds = true`）。

### コンテキストメニュー（日付ジャンプ）

- ヘッダーをタップするとコンテキストメニューが開く。
- メニューには現在のデータソースにある全セクションの日付が一覧表示される。
- 日付を選択すると対象セクションの先頭アイテムへスクロールする。

#### 実装方針

- `SectionHeaderView` 内のガラスビューの前面に透明な `UIButton(type: .custom)` を重ねる。
- `showsMenuAsPrimaryAction = true` を設定し、タップ時にコンテキストメニューを表示する。
- ヘッダー登録クロージャ（`configureDataSource` 内）でスナップショットの全セクションから `UIAction` を生成し `UIMenu` を組み立てて渡す。
- セクションへのジャンプは `scrollToItem(at:IndexPath(item:0, section:), at:.top, animated:true)` で行う。

```swift
// ヘッダー登録クロージャでのメニュー生成
let menuActions = snapshot.sectionIdentifiers.compactMap { sec -> UIAction? in
    guard case .date(let key) = sec else { return nil }
    return UIAction(title: sectionTitle(for: key)) { [weak self] _ in
        self?.jumpToSection(sec)
    }
}
let menu = UIMenu(title: "", children: menuActions)
headerView.configure(title: sectionTitle(for: dateKey), menu: menu)
```

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
- 列挙オプションは `.skipsHiddenFiles`（隠しファイルを除外）。
- 拡張子フィルターは `.jpg`、`.jpeg`（`pathExtension.lowercased()` で大文字小文字を問わない）。
- ソートは `localizedStandardCompare`（ロケール対応昇順）。
- 結果は `MainActor.run` でメインスレッドに戻してから `items` を更新する。

---

## フォルダ選択処理（ViewModel の `selectFolder(_ url: URL) async`）

```swift
func selectFolder(_ url: URL) async {
    rootURL?.stopAccessingSecurityScopedResource()
    guard url.startAccessingSecurityScopedResource() else { return }
    rootURL = url
    hasFolder = true
    await loadItems()
}
```

- 既存の `rootURL` がある場合は先にセキュリティスコープを解放する。
- 新しい URL のセキュリティスコープ取得に失敗した場合は処理を中断する。
- `hasFolder = true` に更新後、`loadItems()` を呼んでファイルリストを取得する。
