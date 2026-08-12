# My Preview - アプリ全体仕様

## アプリ概要

iOS 向けの JPEG 写真ブラウザアプリ。ユーザーが指定したフォルダ内の JPEG ファイルを閲覧し、Exif メタデータを表示しながら、iOS の写真ライブラリへ保存できる。星評価・カラーラベルによる整理、直近に見た写真の記憶、サムネイル表示にも対応する。UIKit で実装する。

---

## 画面構成

```
アプリ起動
  └── ファイルブラウザ画面（FileBrowserViewController）
        ├── フォルダ未選択状態（EmptyStateView）
        ├── JPEG リスト（UICollectionView・list/grid切替可能）
        └── 写真タップ → フォトビューア画面（PhotoViewerViewController）
```

---

## ナビゲーションフロー

1. アプリ起動時は `FileBrowserViewController` が `UINavigationController` のルートとして表示される。
2. フォルダが未選択の場合、フォルダ選択を促す空状態 View が表示される。
3. 左下のフローティングボタンをタップすると `UIDocumentPickerViewController` が開く。
4. フォルダ選択後、そのフォルダ直下の JPEG 画像が `UICollectionView` でリスト表示される（サブフォルダ内への遷移なし）。撮影日ごとにセクション分けされる。
5. 写真セルをタップすると、`PhotoViewerViewController` が `preferredTransition = .zoom` を伴ってフルスクリーンでモーダル表示される（`modalPresentationStyle` は zoom transition 経由、ステータスバー制御込み）。
6. フォトビューア画面を閉じると、ファイルブラウザ画面に戻る。閉じた時点の写真を「このフォルダで最後に見た写真」として記憶し、評価・カラーラベルの変更をリストへ反映する。

詳細は各画面の仕様書を参照：[ファイルブラウザ画面の仕様](spec-file-browser.md) / [フォトビューア画面の仕様](spec-photo-viewer.md)

---

## アーキテクチャ

### MVVM パターン

各 ViewController に対応する ViewModel を 1 つ用意する。

| ViewController               | ViewModel               |
|------------------------------|-------------------------|
| `FileBrowserViewController`  | `FileBrowserViewModel`  |
| `PhotoViewerViewController`  | `PhotoViewerViewModel`  |

### ViewModel（@Observable）

ViewModel には `@Observable` マクロ（Swift Observation フレームワーク）を付与する。

```swift
@Observable
final class FileBrowserViewModel { ... }

@Observable
final class PhotoViewerViewModel { ... }
```

- ViewModel は UI フレームワークに依存しない純粋な Swift クラスとする。
- 非同期処理はすべて Swift Concurrency（`async/await`、`Task`、`Task.detached`、`MainActor`）で実装する。
- `DispatchQueue` は使用しない。

### ViewModel → View の伝達（updateProperties）

iOS 26 で UIKit に導入された `updateProperties()` メソッドを使用する。

```swift
class MyViewController: UIViewController {
    let viewModel = MyViewModel()

    override func updateProperties() {
        super.updateProperties()
        // このメソッド内で viewModel プロパティにアクセスすると
        // システムが自動的にアクセスを追跡する
        label.text = viewModel.someText
        button.isEnabled = viewModel.isEnabled
    }
}
```

`viewModel` の `@Observable` プロパティが変化すると、システムが自動的に `setNeedsUpdateProperties()` をスケジュールし、次のランループで `updateProperties()` が呼ばれる。これは `setNeedsLayout()` / `layoutSubviews()` と同じ仕組み。

`items`/`sections` のような配列プロパティの変化は `updateProperties()` の外で `withObservationTracking` を用いて監視し、変化のたびに再登録して継続的に監視する（詳細は各画面の仕様書を参照）。

### モジュール構成と依存方向

`Modules/Sources/` は `AppMain`（エントリーポイント）・`Core`（Core, Localization, Resources, Mocks）・`Features`（FileBrowser, PhotoViewer）・`Kits`（ImagePiPKit, ToastKit）にグループ化されている。詳細は `feature-planning` スキルの `references/architecture.md` を参照。

- `Kits` は独立ライブラリで、このリポジトリの他のどのモジュールにも依存しない（`ImagePiPKit`・`ToastKit`いずれも UIKit/AVKit 等のシステムフレームワークのみに依存）。
- `Core` 配下のモジュール同士は依存の順番に注意すれば依存し合ってよい（`Core` は `Resources` に依存、`Mocks` は `Core` に依存）。
- `FileBrowser` ↔ `PhotoViewer` は直接依存しない。`Features` のモジュールは他の `Features` モジュールと `AppMain` 以外なら依存してよく、`PhotoViewer` は `Core` に加えて `ToastKit`・`Localization`・`ImagePiPKit` にも依存している。
- `AppMain` だけが全モジュールに依存し、`AppContainer`（`Modules/Sources/AppMain/AppContainer.swift`）がサービス層のインスタンス生成と注入を一元管理する。`FileBrowser` は `photoViewerFactory` クロージャ経由で `PhotoViewer` の ViewController を生成する（`PhotoViewer` を直接 import しない）。
- `FileBrowserViewController` → `PhotoViewerViewController` の情報取得（表示中 URL・dismiss 通知）は `Core/Core/Services/ViewControllerBridges.swift` の `CurrentURLProvider` / `DismissNotifiable` プロトコルを介して行う。
- `AppState`（`Modules/Sources/AppMain/AppState.swift`）が `Core`・`Features`・`AppMain` の中で唯一許容される singleton で、`AppContainer` のライフタイムをアプリ起動〜終了まで保持する。`Kits` は独立ライブラリとしての可用性を優先するため、この制約の対象外（`ToastWindowManager.shared`・`ToastQueue.shared`が実例）。

---

## 技術スタック

| 用途                   | 技術選定                                                          | 理由                                                  |
|------------------------|-------------------------------------------------------------------|-------------------------------------------------------|
| ファイルリスト表示       | `UICollectionView` + `UICollectionViewCompositionalLayout`         | list/grid の切替、日付セクションのピン留めヘッダーに対応 |
| データソース管理         | `UICollectionViewDiffableDataSource`                              | 安全な差分更新・アニメーション付きリロードが可能       |
| 写真のズーム・パン       | `PhotoZoomScrollView`（`UIScrollView` サブクラス）                | ズーム・バウンス・スクロールの実績ある実装             |
| フォトビューアのページング | `UICollectionView`（横スクロール・ページング）＋前後ボタン       | スワイプと前後ボタン両方で同一セル/ズーム状態を扱うため |
| ナビゲーション           | `UINavigationController`                                          | ナビゲーションバーのタイトル表示に使用（プッシュ遷移なし） |
| フォルダ選択             | `UIDocumentPickerViewController`                                  | iOS 標準のドキュメントピッカー                         |
| フォトビューア表示       | `preferredTransition = .zoom`                                    | サムネイルからの拡大トランジション、ステータスバー制御込み |
| レイアウト               | Auto Layout（`NSLayoutConstraint`）                               | Storyboard 不使用、コードベース                        |
| フォルダ／各種ボタン     | iOS 26 Liquid Glass（`UIButton.Configuration.prominentGlass()`/`glass()`、`GlassBackdropView`） | システムと一貫したガラス調素材。ガラス背景の共通実装は `GlassBackdropView` に集約 |
| サムネイル生成           | `ThumbnailServiceProtocol`（`CGImageSourceCreateThumbnailAtIndex`）| 再デコードなしで軽量なサムネイルを生成、`NSCache` でキャッシュ |
| 評価・カラーラベル永続化 | SwiftData（`PhotoRatingStore`/`ColorLabelStore`）                 | URL 単位のメタデータをアプリ再起動後も保持              |
| 保存日時の記憶           | SwiftData（`SavedDateStore`）                                     | 「いつ保存したか」をセッションを跨いで記憶              |
| 設定・直近表示位置の永続化 | `UserDefaultsSettingsStore`（`UserDefaults` + `Codable`）        | view mode・並び順・フィルタ・直近表示ファイルなどを保存 |
| トースト通知             | `ToastKit`（別ウィンドウ + SwiftUI ホスティング）                 | クリップボードコピー等の一時的なフィードバック表示      |
| PiP表示                 | `ImagePiPKit`（`AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer:playbackDelegate:)`） | 動画を使わず静止画をシステムPiPウィンドウへ表示するため |
| 触覚フィードバック       | `HapticsServiceProtocol`（`UINotificationFeedbackGenerator`）     | 保存成功・失敗を触覚で通知                              |
| Exif 抽出               | `ImageIO`（`CGImageSource`）                                      | 再デコードなしでメタデータのみ高速取得                 |
| 写真保存                 | `PHPhotoLibrary`                                                  | 元データをそのまま保存し再エンコードを避ける           |
| 非同期処理               | Swift Concurrency（`async/await`）                                | 画像読み込み・保存処理をメインスレッドから分離         |

---

## フォルダアクセス権限

- アプリはユーザーが明示的に選択したフォルダに対してセキュリティスコープドアクセス権限を取得する。
- 取得した権限はアプリのセッション中（別のフォルダを選択するまで）保持される。
- 新しいフォルダを選択した際は、前のフォルダへの権限を解放した後に新しい権限を取得する。
- 権限は `FileBrowserViewModel` が一元管理する（サブフォルダ遷移がないため、権限の引き渡し不要）。

---

## 表示対象ファイル

- ファイルリストには **JPEG 画像のみ** を表示する（フォルダ・その他のファイルは非表示）。
- 選択したフォルダの直下のみを対象とし、サブフォルダの再帰探索は行わない。
- 隠しファイル（`.` で始まるファイル）は表示しない。

---

## ファイル判定

- 拡張子が `.jpg` または `.jpeg`（大文字小文字を問わない）のファイルのみリストに表示する。
- それ以外（フォルダ・他の拡張子）は一切表示しない。

---

## 表示順・グルーピング・フィルタ

- JPEG 画像は撮影日（Exif の作成日時、取得できない場合は取得日時 `.distantFuture` 扱い）で日単位のセクションにグルーピングされる。
- 並び順（`FileSortOrder`）はユーザーが「古い順（デフォルト）」「新しい順」から選択でき、セクション・セクション内アイテムの両方に適用される。
- 評価機能が有効な場合、星評価（`RatingFilter`）とカラーラベル（`Set<PhotoColorLabel>`）でリストを絞り込める。
- 表示形式（`ViewMode`）は「リスト」「グリッド（2〜5列）」から選択できる。

詳細な UI・ViewModel 仕様は [ファイルブラウザ画面の仕様](spec-file-browser.md) を参照。

---

## 写真保存機能

- フォトビューア画面から、現在表示中の写真を iOS の写真ライブラリに保存できる。
- 保存時は元のファイルデータをそのまま使用し、元のファイル名を保持する（再エンコードなし）。
- 保存フォーマット設定（`SaveFormat`）が `.jpegAndRaw` の場合、同名の RAW ファイル（dng/arw/cr2/cr3/nef/orf/raf/rw2/pef/srw/3fr、大文字小文字を問わない）が同じフォルダに存在すれば併せて保存する。
- 保存には写真ライブラリへの追加権限（`addOnly`）が必要。未許可の場合は権限リクエストが表示される。
- 権限が拒否された場合、保存は失敗する。
- 保存成功後、2 秒後にボタン状態を初期状態（idle）に戻す。
- 保存成功・失敗は触覚フィードバック（`HapticsServiceProtocol`）でも通知する。
- 保存日時は `SavedDateStore` に記録され、次回以降その写真を表示した際に「最終保存日時」として表示される。

---

## 評価・カラーラベル機能

- 設定メニューから評価機能（星評価・フィルタ UI）の表示/非表示を切り替えられる（`isRatingEnabled`）。
- フォトビューア画面で写真ごとに星評価（0〜5）とカラーラベル（緑・黄・青・ピンク・赤・白から1つ）を設定できる。同じ値を再度選択すると解除（0 / nil）される。
- 評価・カラーラベルは URL 単位で SwiftData（`PhotoRatingStore`/`ColorLabelStore`）に永続化され、アプリ再起動後も保持される。
- フォトビューア内で評価・カラーラベルを変更し、現在の写真がファイルブラウザ側のフィルタ条件に一致しなくなった場合、自動的に次に一致する写真へ遷移する。一致する写真が他に無い場合はフォトビューアを閉じる。

---

## PiP表示機能

- フォトビューア画面下部にあるPiP開始ボタンから、現在表示中の写真をシステムの Picture in Picture ウィンドウに表示できる（動画は使わず、`ImagePiPKit` が静止画をシステムPiPへ表示する）。このPiPボタンは画面回転ボタンと1つの座布団（`PiPOrientationBarView`）にまとめられている。縦持ちでは評価・カラーラベルバー（座布団）の上・画面右端、横持ちでは保存ボタンの右側に配置される。
- PiPウィンドウの標準の±10秒スキップボタンで前後の写真に切り替えられる（先頭/末尾では無反応）。
- PiPウィンドウの標準の再生/一時停止ボタンをスライドショーのON/OFFとして使う。再生中は一定間隔（`pipAutoAdvanceIntervalSeconds`、デフォルト5秒）で次の写真へ自動的に進み、最後の写真まで到達すると先頭へ固定でループする。一時停止すると自動送りは止まる。
- 自動送りの間隔（秒）は設定メニューから変更でき、`UserDefaultsSettings.pipAutoAdvanceIntervalSeconds` として永続化される。
- 詳細は [フォトビューア画面の仕様](spec-photo-viewer.md) の「PiP表示」を参照。

---

## 直近に見た写真の記憶

- フォルダごとに「最後に表示した写真のファイル名」を `UserDefaultsSettingsStore` に記憶する（`UserDefaultsSettings.lastViewedEntries: [DirectoryLastViewedEntry]`）。
- 記憶するフォルダ数は最大 `UserDefaultsSettings.maxLastViewedDirectoryCount`（10）件。上限を超えると最も古いフォルダのエントリから削除される（LRU）。
- ファイルブラウザのセルおよびセクションヘッダーのジャンプメニューから、直近に見た写真へスクロールできる。

---

## データモデル

### FileItem

```swift
struct FileItem: Identifiable {
    let id: UUID           // DiffableDataSource 用の一意識別子
    let url: URL           // ファイルの URL
    let name: String       // url.lastPathComponent
    let captureDate: Date? // Exif 由来の撮影日時（取得できない場合 nil）
}
```

### PhotoViewerInput

```swift
struct PhotoViewerInput {
    let initialURL: URL                     // 最初に表示する写真の URL
    let allURLs: [URL]                      // フォルダ内全 JPEG の URL リスト
    let isRatingEnabled: Bool               // 評価・フィルタ UI を表示するか
    let ratingFilter: RatingFilter?         // ファイルブラウザ側の星評価フィルタ
    let colorLabelFilter: Set<PhotoColorLabel> // ファイルブラウザ側のカラーラベルフィルタ
}
```

### ExifInfo

```swift
struct ExifInfo {
    let iso: String?           // 例: "ISO 400"
    let focalLength: String?   // 例: "50mm"
    let exposureValue: String? // 例: "+1.0EV"、ゼロの場合は "±0EV"
    let fNumber: String?       // 例: "f/2.8"
    let shutterSpeed: String?  // 例: "1/125s"、1秒以上は "2s"
    let flashFired: Bool       // フラッシュが発光したか
}
```

### SaveStatus

```swift
enum SaveStatus {
    case idle     // 「↓ 保存」、ボタン有効
    case saving   // 「⏳ 保存中...」、ボタン無効
    case success  // 「✓ 保存完了」、ボタン無効（2秒後に idle へ）
    case failure  // 「✕ 失敗」、ボタン有効（再試行可能）
}
```

### ImageOrientation

```swift
enum ImageOrientation {
    case portrait   // 縦長（width < height）
    case landscape  // 横長（width >= height）
}
```

`UIImage.photoOrientation` として拡張プロパティを提供する。

### PhotoColorLabel

```swift
enum PhotoColorLabel: String, CaseIterable, Codable {
    case green, yellow, blue, pink, red, white
}
```

写真に1つ設定できるカラーラベル。`uiColor` 拡張プロパティで表示色（`.systemGreen` 等、pink はカスタム色、white は `.white`）を取得する。`Set<PhotoColorLabel>` はカンマ区切り文字列との相互変換ヘルパー（`colorLabelFilterRawValue`）を持ち、フィルタ設定の永続化に使う。

### RatingFilter

```swift
struct RatingFilter: Codable {
    enum Comparison: CaseIterable, Codable {
        case atLeast  // 以上
        case atMost   // 以下
        case exactly  // 同値
    }

    static let starsRange = 0...5

    var stars: Int
    var comparison: Comparison

    func matches(_ rating: Int) -> Bool
}
```

### UserDefaultsSettings

```swift
enum ViewMode: String, Codable { case list, grid }
enum FileSortOrder: String, Codable { case dateDescending, dateAscending }
enum SaveFormat: String, Codable { case jpeg, jpegAndRaw }
enum PhotoViewerOrientationLock: String, Codable { case followSystem, portrait, landscape }

struct DirectoryLastViewedEntry: Codable, Equatable {
    let directoryPath: String
    let fileName: String
}

struct UserDefaultsSettings: Codable, UserDefaultsStorableSettings {
    static let maxLastViewedDirectoryCount = 10

    var viewMode: ViewMode                  // デフォルト .grid
    var saveFormat: SaveFormat               // デフォルト .jpeg
    var sortOrder: FileSortOrder             // デフォルト .dateAscending
    var gridColumnCount: Int                 // デフォルト 3（範囲 2...5）
    var isRatingEnabled: Bool                // デフォルト true
    var ratingFilter: RatingFilter?          // デフォルト nil
    var colorLabelFilter: Set<PhotoColorLabel> // デフォルト []
    var lastViewedEntries: [DirectoryLastViewedEntry] // デフォルト []
    var orientationLock: PhotoViewerOrientationLock // デフォルト .followSystem。フォトビューア画面のみに適用
    var pipAutoAdvanceIntervalSeconds: Int   // デフォルト 5（範囲 1...30）。PiP再生中に自動的に次の写真へ進める間隔
}
```

各プロパティは `UserDefaultsSettingsStore` の `@dynamicMemberLookup` サブスクリプト経由で個別に `UserDefaults` へ JSON エンコードして保存される。保存キーは `UserDefaultsSettings.storageKeys`（`[PartialKeyPath<Self>: String]`）で明示的に管理し、Swift 側のプロパティ名変更が保存キーに影響しないようにしている。

---

## フォトビューア権限

| 権限                          | 用途     | リクエストタイミング   |
|-------------------------------|----------|------------------------|
| PHPhotoLibrary `.addOnly`     | 写真保存 | 保存ボタンタップ時      |

---

## 関連仕様書

- [ファイルブラウザ画面の仕様](spec-file-browser.md)
- [フォトビューア画面の仕様](spec-photo-viewer.md)
