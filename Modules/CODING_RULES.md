# コーディングルール

## モジュール構成

```
Modules/
├── Sources/
│   ├── Core/           # 共有サービス・モデル層
│   ├── FileBrowser/    # ファイルブラウザー機能モジュール
│   ├── PhotoViewer/    # フォトビューアー機能モジュール
│   └── AppMain/        # アプリエントリーポイント
```

## 依存関係ルール

```
AppMain → Core, FileBrowser, PhotoViewer
FileBrowser → Core
PhotoViewer → Core
Core → （依存なし）
```

- **機能モジュール間の直接依存は禁止する**（FileBrowser ↔ PhotoViewer）
- 機能モジュールは Core にのみ依存する
- AppMain は全モジュールに依存してよい

## アーキテクチャ

### MVVM

- **ViewModel** はビジネスロジックを担当し、UIKitへの依存を最小化する
- **ViewController** はViewModelを観察（`Observation`）してUIを更新する
- **View** はレイアウトのみを担当し、ロジックを持たない

### アプリ状態管理（AppState / AppContainer）

- `AppState` は `AppMain` モジュール内のシングルトンで、`AppContainer` を保持する
- `AppContainer` は `AppState.shared` を通じてアプリのライフタイム全体で生存する
- 機能モジュール間の依存を解決するため、ファクトリクロージャを使って注入する

```swift
// 良い例: ファクトリクロージャで注入する
let vc = FileBrowserViewController(
    viewModel: viewModel,
    photoViewerFactory: { input in /* PhotoViewerVCを生成 */ }
)

// 悪い例: FileBrowserがPhotoViewerを直接import・生成する
import PhotoViewer // ← 機能モジュール間の直接依存
```

### モジュール間通信プロトコル（Core/ViewControllerBridges.swift）

機能モジュール間でViewControllerを扱う必要がある場合は、Coreにプロトコルを定義して間接的に通信する。

- `CurrentURLProvider`: 現在表示中のURLを外部に公開する
- `DismissNotifiable`: 閉じる時のコールバックを受け取る

## コーディング規約

### アクセス修飾子

- モジュール外から使用する型・関数・プロパティには `public` を付ける
- モジュール内部でのみ使用するものは `internal`（省略可）または `private` にする
- AppMain内部クラス（`AppState`, `AppContainer`）は `internal` にする

### 命名規則

- 型名: `UpperCamelCase`（例: `FileBrowserViewModel`）
- 変数・関数名: `lowerCamelCase`（例: `scanForJPEGs`）
- プロトコル名: 役割を示す名詞または `-able/-Protocol` サフィックス（例: `FileSystemServiceProtocol`）

### 非同期処理

- `async/await` を使用する（コールバックは使わない）
- UIに関わる処理は `@MainActor` で実行する
- バックグラウンド処理は `Task.detached(priority: .userInitiated)` を使用する

### 依存性の注入

- サービスはプロトコルとして定義し、コンストラクタインジェクションで注入する
- `UserDefaultsStorage.shared` のようなシングルトンはデフォルト引数として提供する（テスト時に置き換え可能にする）

### Observable

- `@Observable` マクロを使用してViewModelの状態変更を通知する
- ViewControllerでは `withObservationTracking` で変化を観察する
- `setNeedsUpdateProperties` / `updateProperties` でUIを更新する

### メモリ管理

- クロージャ内では `[weak self]` を使用して循環参照を防ぐ

## ディレクトリ構造（各モジュール）

```
Sources/<ModuleName>/
├── ViewModels/     # @Observable ViewModel
└── Views/          # ViewController + UIView サブクラス
```

Coreモジュール:

```
Sources/Core/
├── Models/         # データ構造体・enum
└── Services/       # プロトコル定義 + 実装クラス
```

## コメント規約

- 全コメントは**日本語**で記述する
- クラス・関数のドキュメントコメントは `///` 形式を使用する
- 複雑なロジックには理由を説明するインラインコメントを付ける
- `// MARK: -` でセクションを区切る
