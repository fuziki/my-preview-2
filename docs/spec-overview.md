# My Preview 2 - アプリ全体の挙動仕様（UIKit 版）

## アプリ概要

iOS 向けの JPEG 写真ブラウザアプリ。ユーザーが指定したフォルダ内の JPEG ファイルを閲覧し、iOS の写真ライブラリへ保存できる。
参考実装（SwiftUI 版）のパフォーマンス課題を解消するため、UIKit で再実装する。

---

## 画面構成

```
アプリ起動
  └── ファイルブラウザ画面（FileBrowserViewController）
        ├── フォルダ未選択状態（EmptyStateView）
        ├── JPEG リスト（UICollectionView）
        └── 写真タップ → フォトビューア画面（PhotoViewerViewController）
```

---

## ナビゲーションフロー

1. アプリ起動時は `FileBrowserViewController` が `UINavigationController` のルートとして表示される。
2. フォルダが未選択の場合、フォルダ選択を促す空状態 View が表示される。
3. 左下のフローティングボタンをタップすると `UIDocumentPickerViewController` が開く。
4. フォルダ選択後、そのフォルダ直下の JPEG 画像が `UICollectionView` でリスト表示される（サブフォルダへの遷移なし）。
5. 写真行をタップすると、`PhotoViewerViewController` がフルスクリーンでモーダル表示される（`modalPresentationStyle = .fullScreen`）。
6. フォトビューア画面を閉じると、ファイルブラウザ画面に戻る。

---

## アーキテクチャ

### MVVM パターン

各 ViewController に対応する ViewModel を 1 つ用意する。

| ViewController             | ViewModel               |
|----------------------------|-------------------------|
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

---

## 技術スタック

| 用途                   | 技術選定                                  | 理由                                                  |
|------------------------|-------------------------------------------|-------------------------------------------------------|
| ファイルリスト表示       | `UICollectionView` + `UICollectionViewListConfiguration` | スクロールパフォーマンスが高く、差分更新が容易       |
| データソース管理         | `UICollectionViewDiffableDataSource`      | 安全な差分更新・アニメーション付きリロードが可能     |
| 写真のズーム・パン       | `UIScrollView`（subview に `UIImageView`）| ズーム・バウンス・スクロールの実績ある実装            |
| ナビゲーション           | `UINavigationController`                 | ナビゲーションバーのタイトル表示に使用（プッシュ遷移なし） |
| フォルダ選択             | `UIDocumentPickerViewController`         | iOS 標準のドキュメントピッカー                        |
| フォトビューア表示       | `modalPresentationStyle = .fullScreen`   | ステータスバー制御を含む完全なフルスクリーン制御      |
| レイアウト               | Auto Layout（`NSLayoutConstraint`）       | 画面サイズ変化・回転に対して柔軟に対応               |
| 写真保存                 | `PHPhotoLibrary`                          | 元データをそのまま保存し再エンコードを避ける          |
| 非同期処理               | Swift Concurrency（`async/await`）        | 画像読み込み・保存処理をメインスレッドから分離        |
| フローティングボタン     | iOS 26 Liquid Glass（`UIGlassEffect`）    | システムと一貫したガラス調素材でボタンを視覚的に統一  |

---

## フォルダアクセス権限

- アプリはユーザーが明示的に選択したフォルダに対してセキュリティスコープドアクセス権限を取得する。
- 取得した権限はアプリのセッション中（別のフォルダを選択するまで）保持される。
- 新しいフォルダを選択した際は、前のフォルダへの権限を解放した後に新しい権限を取得する。
- 権限は `FileBrowserViewController` が一元管理する（サブフォルダ遷移がないため、権限の引き渡し不要）。

---

## 表示対象ファイル

- ファイルリストには **JPEG 画像のみ** を表示する（フォルダ・その他のファイルは非表示）。
- 選択したフォルダの直下のみを対象とし、サブフォルダの再帰探索は行わない。
- フィルタートグルは存在しない（固定）。

---

## ファイル判定

- 拡張子が `.jpg` または `.jpeg`（大文字小文字を問わない）であるファイルのみリストに表示する。
- それ以外（フォルダ・他の拡張子）は一切表示しない。

---

## リストの並び順

- JPEG 画像をファイル名のロケール対応昇順（`localizedStandardCompare`）で並べる。
- 隠しファイル（`.` で始まるファイル）は表示されない。

---

## 写真保存機能

- フォトビューア画面から、現在表示中の写真を iOS の写真ライブラリに保存できる。
- 保存時は元のファイルデータをそのまま使用し、ファイル名も元のファイル名が保持される（再エンコードなし）。
- 保存には写真ライブラリへの追加権限（`addOnly`）が必要。未許可の場合は権限リクエストが表示される。
- 権限が拒否された場合、保存は失敗する。

---

## データモデル

### FileItem

```swift
struct FileItem: Hashable
    - id: UUID
    - url: URL
    - name: String
```

JPEG 画像のみを扱うため `type` フィールドは不要。

### PhotoViewerInput

```swift
struct PhotoViewerInput
    - initialURL: URL       // 最初に表示する写真の URL
    - allURLs: [URL]        // フォルダ内全 JPEG の URL リスト
```

---

## 関連仕様書

- [ファイルブラウザ画面の仕様](spec-file-browser.md)
- [フォトビューア画面の仕様](spec-photo-viewer.md)
