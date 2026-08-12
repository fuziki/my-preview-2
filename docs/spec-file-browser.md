# ファイルブラウザ画面の仕様

## 画面概要

アプリのメイン画面。ユーザーが選択したフォルダ内の JPEG 画像を `UICollectionView` でリスト／グリッド表示する。
サムネイル・星評価・カラーラベルの表示や、それらによる並び替え・絞り込みを行える。
サブフォルダ内への画面遷移は行わない。フォルダの変更はフローティングボタンから `UIDocumentPickerViewController` を介してのみ行う。

**クラス名：** `FileBrowserViewController`
**ViewModel：** `FileBrowserViewModel`

---

## MVVM 構成

### FileBrowserViewModel（@Observable）

```swift
@Observable
final class FileBrowserViewModel {
    private(set) var sections: [FileBrowserSection] = []
    private(set) var hasFolder: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var folderName: String? = nil
    var viewMode: ViewMode                     // didSet: 永続化
    var saveFormat: SaveFormat                 // didSet: 永続化
    var sortOrder: FileSortOrder               // didSet: 永続化 + updateSections()
    var gridColumnCount: Int                   // didSet: 永続化（範囲 2...5 にクランプ）
    var isRatingEnabled: Bool                  // didSet: 永続化 + updateSections()
    var ratingFilter: RatingFilter?            // didSet: 永続化 + updateSections()
    var colorLabelFilter: Set<PhotoColorLabel> // didSet: 永続化 + updateSections()
    private(set) var lastViewedItemID: FileItem.ID? = nil

    // 派生プロパティ
    var items: [FileItem] { sections.flatMap(\.items) }
    var lastViewedItem: FileItem? { get }
}
```

**init（引数にデフォルト値を持たせない、すべて protocol 型で注入）：**

```swift
init(
    fileSystemService: any FileSystemServiceProtocol,
    savedDateStore: any SavedDateStoreProtocol,
    ratingStore: any PhotoRatingStoreProtocol,
    colorLabelStore: any ColorLabelStoreProtocol,
    settings: any UserDefaultsSettingsStoreProtocol<UserDefaultsSettings>
)
```

初期化時に `viewMode`/`saveFormat`/`sortOrder`/`gridColumnCount`（クランプ済み）/`isRatingEnabled`/`ratingFilter`/`colorLabelFilter` を `settings` から復元する。

**ViewModel のメソッド：**

| メソッド                                    | 処理                                                                                          |
|---------------------------------------------|-----------------------------------------------------------------------------------------------|
| `rating(for url: URL) -> Int`               | `ratingsByURL[url] ?? 0` を返す                                                               |
| `colorLabel(for url: URL) -> PhotoColorLabel?` | `labelsByURL[url]` を返す                                                                  |
| `refreshRatingsAndLabels()`                 | 評価・カラーラベルのキャッシュをストアから再読込し `updateSections()`。フォトビューア閉じた後に呼ぶ |
| `consumeHasFolderChanged() -> Bool`         | `hasFolder` の変化を1回だけ検出する（フォルダボタンのアニメーション用）                        |
| `sectionTitle(for id: FileBrowserSection.ID) -> String` | セクションの日付キーをロケール対応の表示用文字列にフォーマットする                    |
| `section(for id: FileBrowserSection.ID) -> FileBrowserSection?` | セクションを ID で検索する                                                    |
| `makeMenuData() -> (showsLastViewed: Bool, sections: [(id: FileBrowserSection.ID, title: String)])` | セクションヘッダーのジャンプメニュー用データを生成する               |
| `selectFolder(_ url: URL) async`            | 前のセキュリティスコープを解放し、新しいスコープを取得後に `loadItems()` を呼ぶ               |
| `resetToDefaults()`                         | 設定・評価・カラーラベル・保存日時をすべて初期状態に戻す（「キャッシュを消去」機能）           |
| `saveLastViewed(url: URL)`                  | 現在のフォルダについて「最後に見た写真」を記憶する（フォルダごと最大10件、LRU）                |

**内部処理（private）：**

- `loadItems() async` — `fileSystemService.scanForJPEGs(in:)` でバックグラウンド読込 → 評価・カラーラベルのキャッシュ再読込 → `updateSections()` → 直近表示位置の復元 → `isLoading = false`。
- `updateSections()` — 評価フィルタ・カラーラベルフィルタ（`isRatingEnabled` かつフィルタ設定時のみ）を適用し、撮影日（`captureDate ?? .distantFuture`）で日単位にグルーピング、`sortOrder` に従いセクション・アイテムを昇順/降順に並べ替える。
- `matchesFilters(_ url: URL) -> Bool` — 星評価フィルタとカラーラベルフィルタの AND 判定。
- `restoreLastViewedItemIDIfNeeded()` — `lastViewedItemID` が未設定の場合のみ、永続化されたエントリから復元する。

### FileBrowserSection

```swift
struct FileBrowserSection {
    struct ID: Hashable {
        let dateKey: String // "yyyy-MM-dd"（en_US_POSIX）
    }
    let id: ID
    let items: [FileItem]
}
```

撮影日（1日単位）でグルーピングしたセクション。`UICollectionViewDiffableDataSource<FileBrowserSection.ID, FileItem.ID>` のセクション識別子として使う。

### FileBrowserViewController の updateProperties

`FileBrowserViewController` は `updateProperties()` をオーバーライドし、`viewModel.sections`/`hasFolder`/`isLoading`/`folderName` の変化を UI に反映する。空状態の表示判定・タイトル更新・フォルダボタンのアニメーションもここから駆動する。

### 監視（withObservationTracking）

`updateProperties()` の外で2系統の監視を行い、変化のたびに再登録して継続的に監視する。

- `startObservingItems()` — `sections`/`hasFolder`/`isLoading`/`folderName` を監視し、スナップショット適用・空状態更新・フォルダボタンアニメーション（`consumeHasFolderChanged()` が真の場合のみ）・タイトル更新を行う。
- `startObservingViewMode()` — `viewMode`/`gridColumnCount` を監視し、レイアウトの差し替え（`setCollectionViewLayout`）とアイテムの再読込（`reloadItems`、非アニメーション）を行う。

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

- `EmptyStateView` を非表示にする。ローディング中／写真0件の場合も `EmptyStateView` の別状態（`.loading`/`.noPhotos`）を表示する。
- `UICollectionView` を表示し、選択したフォルダ内の JPEG 画像をリスト／グリッド表示する。
- ナビゲーションタイトルは選択したフォルダ名（`folderName`）。

---

## ViewController 構成

```
UINavigationController
  └── FileBrowserViewController（唯一の ViewController）
```

- `FileBrowserViewController` が `UINavigationController` のルートとなる。
- サブフォルダへの遷移は行わないため、`UINavigationController` のプッシュ遷移は使用しない。
- `init(viewModel:thumbnailService:photoViewerFactory:)` で ViewModel・サムネイルサービス・フォトビューア生成クロージャを注入する。`photoViewerFactory` により `PhotoViewer` モジュールへの直接依存を避ける。

---

## ナビゲーションバー

- タイトルはフォルダ未選択時「My Preview」、選択後は選択したフォルダ名。
- 右側の `UIBarButtonItem`：
  - 設定ボタン（歯車アイコン）：常に表示。メニューは `FileBrowserMenuBuilder.makeSettingsMenu()`。
  - フィルタボタン（`line.3.horizontal.decrease.circle`、フィルタ有効時は `.fill`）：`viewModel.isRatingEnabled` の場合のみ表示。タップで `FileBrowserFilterView`（SwiftUI）をハーフモーダル表示する。
- 設定メニューはアクション実行後、メニューを再構築して `.menu` に再代入し、チェック状態を最新に保つ。フィルタボタンのアイコン塗りつぶし状態は、ハーフモーダルが閉じたタイミング（`UISheetPresentationControllerDelegate.presentationControllerDidDismiss`）で更新する。

---

## フローティングボタン

### フォルダを開く（左下）

- Safe Area 内の **左下隅** に固定配置する。
- アイコン：`folder` システムアイコン。**iOS 26 の Liquid Glass エフェクト**（`UIButton.Configuration.prominentGlass()`）を適用する。
- フォルダ未選択時は「フォルダを選択」ラベル付きの横長ボタン、選択後は 56×56pt の円形アイコンボタンにスプリングアニメーション（ダンピング0.7）で変形する。
- 制約（Auto Layout）：
  - `leading` = `view.safeAreaLayoutGuide.leadingAnchor` + 16pt（固定）
  - `bottom` = `view.safeAreaLayoutGuide.bottomAnchor` + `folderButtonSize`（56pt）
  - `trailing`/`width` はフォルダ有無の状態でアニメーション対象になる制約
- タップすると `UIDocumentPickerViewController` を表示する。
- 空状態・フォルダ選択後を問わず、常に表示する。

### 一番下へジャンプ（右下）

- `UIButton.Configuration.glass()`、`chevron.down` アイコン、56×56pt の円形（`cornerStyle = .large`）。
- フォルダボタンと同じ高さで右下に配置。フォルダ未選択時は `alpha = 0`、選択後はフォルダボタンのアニメーションと同時にフェードインする。
- タップするとリストの最終セクション末尾へスクロールする。

### フローティングボタンとリストのかぶり対策

- `FileBrowserViewController` の `additionalSafeAreaInsets.bottom` を `folderButtonSize + 32`（88pt）に設定する。
- `UICollectionView` の `contentInsetAdjustmentBehavior = .automatic` により、拡張された Safe Area が自動的にスクロール領域に反映される。

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

### レイアウト（UICollectionViewCompositionalLayout）

`Modules/Sources/FileBrowser/Views/UICollectionViewLayout+FileBrowser.swift` で2種類のレイアウトを構築し、`viewModel.viewMode` に応じて切り替える。両方とも `pinToVisibleBounds = true` のセクションヘッダーを持つ。

- **リストレイアウト**（`fileBrowserList()`）：`NSCollectionLayoutSection.list` + `UICollectionLayoutListConfiguration(appearance: .plain)`、セパレーター表示あり。
- **グリッドレイアウト**（`fileBrowserGrid(columnCount:)`）：正方形セル。`itemSize` は幅・高さともに `fractionalWidth(1 / columnCount)`。列数は `viewModel.gridColumnCount`（2〜5、設定メニューのステッパーで変更可能）。セル間隔 1pt、セクション下余白 8pt。

### データソース

- `UICollectionViewDiffableDataSource<FileBrowserSection.ID, FileItem.ID>` を使用する。
- セクション識別子は `FileBrowserSection.ID`、アイテム識別子は `FileItem.ID`（`UUID`）。
- `viewModel.sections` の変化を検知したらスナップショットを再構築し `apply(animatingDifferences: true)` で差分更新する。評価・フィルタ・キャッシュ消去の直後は `reconfigureItems` で全セルを再構成する。

### セル

2種類のセル登録（`UICollectionView.CellRegistration`）を `viewModel.viewMode` に応じて使い分ける。

**リストモード：** `UICollectionViewListCell` + `UIListContentConfiguration`。
- `image`：`photo` システムアイコン
- 主テキスト：ファイル名
- 副テキスト：星評価・カラーラベル（色付き `●`）・「最後に表示」ラベルを `" · "` で連結（評価機能有効時のみ星・ラベルを表示）

**グリッドモード：** `ThumbnailCell`（`Modules/Sources/FileBrowser/Views/ThumbnailCell.swift`）。
- サムネイル画像（`.scaleAspectFit`、黒背景）。`thumbnailService.cachedThumbnail(for:)` を同期取得できればそれを即表示（フリッカー防止）、無ければ `loadThumbnail(url:maxPixelSize:)` を非同期取得。
- 左上：星評価バッジ（黒 0.65 透過の角丸ラベル、`★` の数を表示、評価0は非表示）
- 右上：カラーラベルの色ドット（12×12pt円、評価機能有効時のみ）
- 下部：「最後に表示」バッジ（半透明の黒帯、白文字）
- 評価・カラーラベルの表示は `viewModel.isRatingEnabled` が true の場合のみ

### タップ処理

- `UICollectionViewDelegate.collectionView(_:didSelectItemAt:)` で処理する。
- `dataSource.itemIdentifier(for:indexPath)` で `FileItem.ID` を取得し、対応する URL を特定する。
- `viewModel.items` から全 URL リストを取得し、評価機能有効フラグ・現在のフィルタ設定とあわせて `PhotoViewerInput` を生成する。
- `photoViewerFactory(input)` で生成した ViewController を `preferredTransition = .zoom`（`CurrentURLProvider` からタップ元セルを特定）でモーダル表示する。
- `DismissNotifiable` 経由で `onDismiss` を設定し、閉じられた際に `viewModel.saveLastViewed(url:)` → `viewModel.refreshRatingsAndLabels()` → 全セル再構成を行う。

---

## 設定メニュー（FileBrowserMenuBuilder.makeSettingsMenu）

歯車アイコンのメニュー。すべて `UIDeferredMenuElement.uncached` でラップし、開くたびに最新状態で再構築する。

| 項目               | 内容                                                                                     |
|--------------------|------------------------------------------------------------------------------------------|
| 表示形式           | 「リスト」「グリッド」の単一選択インラインメニュー                                        |
| 列数（グリッド時のみ） | 減算／現在値表示（無効ボタン）／加算の3ボタン、範囲 2〜5 でクランプ                     |
| 保存フォーマット   | 「JPEG」「JPEG + RAW」の単一選択インラインメニュー                                        |
| 並び順             | 「古い順」「新しい順」の単一選択インラインメニュー                                        |
| 評価機能のON/OFF   | 星評価・フィルタ UI 全体の表示/非表示を切り替える単一アクション                           |
| PiP自動送り間隔    | フォトビューアのPiP表示中、再生状態で自動的に次の写真へ進む間隔（秒）。減算／現在値表示（無効ボタン）／加算の3ボタン、範囲 1〜30秒でクランプ |
| キャッシュを消去   | 破壊的アクション。確認ダイアログ後 `viewModel.resetToDefaults()` を実行                   |

## フィルタ設定（FileBrowserFilterViewController / FileBrowserFilterView / FileBrowserFilterViewModel）

`line.3.horizontal.decrease.circle` アイコンをタップすると表示するボトムシート風のハーフモーダル（評価機能が有効な場合のみ表示）。

### 画面生成（AppContainer経由）

- `FileBrowserViewController` は自分でViewModel・Viewを組み立てず、init時に注入された `filterViewControllerFactory` クロージャ（`photoViewerFactory` と同様のパターン）を呼び出す。渡す引数は現在の `ratingFilter`/`colorLabelFilter` と、変更のたびに呼ばれる `onChange: (RatingFilter?, Set<PhotoColorLabel>) -> Void`。
- `AppContainer` はこのクロージャの実体として `FileBrowserFilterViewController(ratingFilter:colorLabelFilter:onChange:)` をそのまま呼ぶだけ（`FileBrowserFilterViewModel`・`FileBrowserFilterView` を直接構築しない）。
- `FileBrowserFilterViewController`（`UIHostingController<FileBrowserFilterView>` のサブクラス、`Modules/Sources/FileBrowser/Views/FileBrowserFilterViewController.swift`）が公開initで `ratingFilter`/`colorLabelFilter`/`onChange` の3引数のみを受け取り、内部で `FileBrowserFilterViewModel` を生成して `FileBrowserFilterView` に渡す。`FileBrowserFilterViewModel`・`FileBrowserFilterView.init` はモジュール内部にのみ公開し、AppContainer側からは見えない。
  - `sizingOptions = [.preferredContentSize]` を設定し、SwiftUIコンテンツの理想サイズを `preferredContentSize` に反映させる。
  - `view.backgroundColor = .systemBackground.withAlphaComponent(0.4)` を設定し、UIHostingControllerの既定の不透明背景を外して半透明にする。
- `FileBrowserViewController.presentFilterSheet()` はfactoryから受け取ったViewControllerに対して `UISheetPresentationController` を設定してモーダル表示する。固定の `.medium()` ではなく、`UIViewController.contentFittingSheetDetent(presentingViewWidth:)`（`Core/Extensions/UIViewController+ContentFittingSheetDetent.swift`、`public extension UIViewController`）が返すコンテンツの理想の高さにフィットするカスタムdetentを使う。
  - このCore共通実装は、`present` を呼ぶ**前**に `loadViewIfNeeded()` + `view.layoutIfNeeded()` でレイアウトを確定し、`systemLayoutSizeFitting` で算出した高さを `preferredContentSize` へ反映してからdetentを返す。未確定のまま（`preferredContentSize.height == 0`の状態で）presentすると、iOS 26のシート遷移で左下から浮き出るような見え方になる不具合を避けるための対応。ハーフモーダルの高さをコンテンツに合わせたい他画面でも再利用できる。
  - `sheet.largestUndimmedDetentIdentifier = .contentFitting`（同じくCoreで定義する `UISheetPresentationController.Detent.Identifier.contentFitting`）を設定し、ダイミングビューを外す。これによりシート表示中も裏のファイルリスト（フォルダボタン・写真タップなど）をそのまま操作できる。
  - グラバー・Doneボタンは表示しない（閉じるのはスワイプのみ）。画面遷移の生成はAppContainer、表示・破棄（sheetの詳細設定）はFileBrowserViewControllerが担う。

### FileBrowserFilterViewModel

- `FileBrowserViewModel` とは独立した、フィルター画面専用の `@Observable` ViewModel（`Modules/Sources/FileBrowser/ViewModels/FileBrowserFilterViewModel.swift`、モジュール内部限定）。
- `ratingFilter`/`colorLabelFilter` をローカルに保持し、`didSet` のたびにinit時に注入された `onChange` クロージャを呼ぶ。
- `FileBrowserViewController.presentFilterSheet()` 側の `onChange` 実装が `viewModel.ratingFilter`/`colorLabelFilter`（＝`FileBrowserViewModel`）へ書き戻すことで、変更が即座に裏のファイルリストへ反映される（`FileBrowserViewModel` の `didSet` で `updateSections()` が走るため）。

### 画面内容

`FileBrowserFilterView` は `@State private var viewModel: FileBrowserFilterViewModel` として保持する（参照型かつ`@Observable`のため、`@State`でもプロパティの変更はonChangeへ伝播する）。`SwiftUI.Form`・`NavigationStack`・ナビゲーションバーは使わず、コンテンツを直接並べたボトムシート風の1画面。星・カラーラベルのアイコン表現はPhotoViewerの`RatingLabelBarView`（既存UIView）に合わせている。

| 項目           | 内容                                                                                     |
|----------------|--------------------------------------------------------------------------------------------|
| タイトル       | 「フィルター」（プレーンな`Text`。ナビゲーションバーは使わない）                          |
| 星評価＋条件   | 同じ行にまとめて表示。★1〜5（タップでその位置まで選択、同じ位置を再タップで0に戻す。選択中は`Color.primary`＝ライトテーマ黒・ダークテーマ白、未選択は`Color.secondary`）＋区切り線＋比較条件を`Picker`（`.pickerStyle(.segmented)`、ラベルは≧・≦・半角=）で選択 |
| カラーラベル   | 緑・黄・青・ピンク・赤・白の6色を横並び（各44×44ptのタップ領域）。タップで複数選択のON/OFFを切り替える。アイコンは`RatingLabelBarView`と同じ組み合わせ（未選択`circle.fill`／選択中`circle.inset.filled`、いずれもラベル自身の色でtint） |
| フィルタークリア | 最下部に配置した破壊的ボタン（`.buttonStyle(.bordered)`、赤）。星評価・カラーラベルフィルタを両方クリアする（`viewModel.clearFilters()`） |

星評価・比較条件の変更は `RatingFilter(stars:comparison:)` を都度組み立てて `viewModel.ratingFilter` に反映する。変更はリアルタイムに反映されるため、閉じる操作は下スワイプのみで良い（Doneボタン・グラバーは表示しない）。

---

## セクションヘッダー（SectionHeaderView）

### 外観

- `UIGlassEffect` を使用したガラス形態素のピルバッジ（高さ 32pt、角丸16pt、セクション左端から16ptの位置に配置）を配置する。
- ガラスバッジ内にはローカライズされた日付＋件数テキストと `chevron.up.chevron.down` アイコンを横並びで表示する。
- ヘッダーはスクロール中も画面上部に固定される（`pinToVisibleBounds = true`）。list/grid 両レイアウトで共通。

### メニュー（ジャンプ）

- ピル全体に透明な `UIButton(type: .custom)` を重ね、`showsMenuAsPrimaryAction = true` でタップ即座にメニューを表示する（長押しのコンテキストメニューではない）。
- メニュー内容は `viewModel.makeMenuData()` から都度生成する `UIDeferredMenuElement.uncached`：
  - 「最後に見た写真へ」ジャンプ項目（該当写真が現在のフィルタで表示されている場合のみ）
  - 現在表示中の全セクションへのジャンプ項目（タイトルは日付＋件数）
- ジャンプは `scrollToItem(at:IndexPath(item:0, section:), at:.top, animated:true)`、または直近表示位置は `.centeredVertically` で行う。

---

## ファイル読み込み処理（ViewModel の `loadItems() async`）

```swift
func loadItems() async {
    guard let url = rootURL else { return }
    isLoading = true
    loadedItems = await fileSystemService.scanForJPEGs(in: url)
    // 評価・カラーラベルのキャッシュを再読込
    updateSections()
    restoreLastViewedItemIDIfNeeded()
    isLoading = false
}
```

- `FileSystemServiceProtocol.scanForJPEGs(in:)` がバックグラウンドで列挙・フィルタ・撮影日付与・ソートまで行う（隠しファイル除外、拡張子 `.jpg`/`.jpeg` のみ、`captureDate` 昇順、日付なしは `.distantFuture` 扱い）。
- `updateSections()` で評価・カラーラベルのフィルタ適用と日付グルーピング・並び替えを行う。

---

## フォルダ選択処理（ViewModel の `selectFolder(_ url: URL) async`）

```swift
func selectFolder(_ url: URL) async {
    rootURL?.stopAccessingSecurityScopedResource()
    guard url.startAccessingSecurityScopedResource() else { return }
    rootURL = url
    folderName = url.lastPathComponent
    hasFolder = true
    await loadItems()
}
```

- 既存の `rootURL` がある場合は先にセキュリティスコープを解放する。
- 新しい URL のセキュリティスコープ取得に失敗した場合は処理を中断する。
- `hasFolder = true` に更新後、`loadItems()` を呼んでファイルリストを取得する。

---

## 直近に見た写真の記憶（ViewModel の `saveLastViewed(url:)`）

- `rootURL` のパスをキーに、`UserDefaultsSettings.lastViewedEntries` へ `(directoryPath, fileName)` を追加・更新する。
- `updatingLastViewed(directoryPath:fileName:limit:)`（`limit = UserDefaultsSettings.maxLastViewedDirectoryCount` = 10）で、同一フォルダの既存エントリを置き換えつつ、フォルダ数の上限を超えたら最も古いフォルダから削除する（フォルダ単位の LRU）。
- 併せて `lastViewedItemID` を該当 `FileItem` に更新し、セルのバッジ・ジャンプメニューに反映する。

---

## キャッシュを消去（ViewModel の `resetToDefaults()`）

- `settings.removeAll()` で `UserDefaults` の設定値をすべて削除し、各プロパティをデフォルト値で再読込する。
- `savedDateStore.removeAll()` / `ratingStore.removeAll()` / `colorLabelStore.removeAll()` で SwiftData 上の保存日時・評価・カラーラベルをすべて削除する。
- `lastViewedItemID` および評価・カラーラベルのキャッシュもクリアし、`updateSections()` を呼ぶ。
- UI 側では確認ダイアログ（`UIAlertController`、破壊的アクション）を経てから実行する。
