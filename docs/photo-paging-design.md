# フォトビューアのページング設計の変遷と実装知見

写真を左右にめくる「ページング」を、スワイプの触り心地・ズーム維持・端の扱い・暗転回避のすべてを満たす形にたどり着くまでに、いくつかの設計を試して退けた。その過程で得た「うまくいったパターン」と「退けた設計と理由」をまとめる。仕様としての正はこの文書ではなく [フォトビューア画面の仕様](spec-photo-viewer.md) を参照すること（この文書は設計判断の背景・理由を残すためのもの）。

対象の実装：
- `PhotoPageItemViewController`（`Modules/Sources/Features/PhotoViewer/PhotoViewer/Views/PhotoPageItemViewController.swift`）… 写真ページング本体（子VC）
- `PhotoPageItemCell`（同 `Views/PhotoPageItemCell.swift`）… 1ページ分の写真セル
- `PhotoZoomScrollView`（同 `Views/PhotoZoomScrollView.swift`）… ズーム・パン
- `PhotoViewerViewController` / `PhotoViewerViewModel`（親VCとViewModel）

---

## きっかけになったバグ

「最後の写真を表示しているのに、まれに次の写真へスワイプできてしまう（PiP再生を挟むと再現しやすい）」。

**根本原因は SSOT（Single Source of Truth）違反だった。** 「今どの写真か」の真実が2つあった：

- `viewModel.currentIndex`（論理・本来の真実）
- `collectionView.contentOffset` ＋ `layoutPageOffset`（物理スクロール位置）

この2つを脆い式で後追い同期していたため、PiPの自動送り（バックグラウンドで `currentIndex` だけが進む）や複数コマ移動でズレると、コレクションビュー側に「幽霊ページ」が残り、`cellForItem` のクランプ処理でスワイプが通ってしまっていた。表面的なパッチ（種別判定の精緻化など）を重ねても、二重管理そのものが残る限り再発した。

---

## 最終設計（結論）

**全写真ぶんのアイテムを持つ `UICollectionViewDiffableDataSource` フルリスト + 写真に紐づかない UUID identity。**

- `currentIndex`（ViewModel）を唯一の真実とし、ビューはその投影に徹する。
- データソースは全 N 件のアイテム（UUID）を常に保持し、「**位置 p のセルは写真 p を表示する**」という不変条件を保つ（`cellProvider` は `indexPath.item` を写真インデックスとして構成）。
- **スワイプ**：素の `UICollectionView` ページングでスクロールするだけ（スナップショット変更なし）。全件確保しているのでセルは常に用意済みで、ウィンドウのスライドが不要。着地時にそのセルのズームをリセットし、`onPageChanged` で親へ通知する。
- **ボタン/PiP（プログラム遷移）**：`moveToIndex(_:)`。**表示中セルの UUID を維持したまま**目的位置へ移し（`orderedIDs` から抜いて挿し込む）、そのセルは `swapImageKeepingZoom` で画像だけ差し替える。間に挟まれて位置がずれたセルだけ `reconfigure` する。表示セルは作り直さないので暗転しない。
- **ズームリセット条件**：スワイプで移動した時、および新旧画像の**縦横比が変わった時**（横長→縦長など。`scaleToFill` で潰れるため）。

---

## うまくいったパターン（再利用したい勘所）

### 1. SSOT を1つに絞り、ビューは投影に徹する
`currentIndex` だけを真実とし、物理スクロール位置と論理インデックスの「差分」を別途保持しない。差分（`layoutPageOffset`）を持った瞬間に二重管理になり、非同期のズレで破綻する。

### 2. diffable + 安定した identity（UUID）＝「生き残ったセルは reload されない」
アイテム識別子を写真に紐づかない UUID にすると、リストを組み替えても identity が同じセルは `reloadData` されず、**画像もズーム状態も保持されたまま**になる（＝暗転しない）。これが `reloadData` 方式（後述）との決定的な違い。FileBrowser も同じ `UICollectionViewDiffableDataSource` の流儀。

### 3. 全件確保でスワイプのセル準備待ちを無くす
データソースに全 N 件を入れておくと、スワイプは既存セルをスクロールするだけになり、「ウィンドウをスライドして次のセルを用意する」処理がスワイプの臨界パスから消える。**高速スワイプでも引っかからない**のはこの効果が大きい。

### 4. 表示中セルの「実体」を移してズームを維持する
ボタン/PiP遷移でズームを保つには、**表示中のセル実体（UUID）を目的位置へ移し、画像だけ差し替える**。別セルへスクロールして「ズーム比を転送」する方式は、うまく機能せず筋も悪かった（下記）。

### 5. 読み込み完了まで旧画像を維持して暗転を防ぐ（`swapImageKeepingZoom`）
画像差し替えは「新URLを非同期読み込み → 完了後に `imageView.image` だけ差し替え」にする。読み込み中は旧画像が残るため暗転しない。`PhotoZoomScrollView.swapImageKeepingZoom(_:)` は `zoomScale`・`contentOffset` 等を一切変えず画像だけ差し替える。

### 6. 縦横比ガード（同一比のみ維持、違えばリセット）
`swapImageKeepingZoom` は既存フレーム（旧画像サイズ）へ新画像を `scaleToFill` で流し込むため、**縦横比が違うと潰れる**。ボタン遷移では新旧の縦横比を比べ、同じなら維持・違えばフィットへリセットする（`PhotoPageItemCell.updateKeepingZoomIfSameAspect`）。

### 7. 非同期フィードバックループを避ける
スワイプは子ページャが**同期的に**処理して完結させ、親へは結果だけ通知する。親の `updateProperties`（Observation駆動）から `moveToIndex` を無条件に呼ぶと、スワイプで非同期更新された `currentIndex` が遅延して届き、既に先へ進んだページャと綱引きになって**高速スワイプで一瞬引っかかる**。`viewModel.lastChangeWasSwipe` を見て、スワイプ由来のときは `moveToIndex` を呼ばないようにして解消した。

---

## 試して退けた設計と、退けた理由

推測でパッチを重ねず、症状の原因を特定してから次の設計へ移った。

### A. `layoutPageOffset`（物理位置と論理インデックスの差分を保持）
ボタン遷移でセルを作り直さずズームを保つために、スクロールせずに「差分」を更新していた。→ **SSOT違反。** PiP自動送りや複数コマ移動でズレると幽霊ページが残り、最後の写真でもスワイプが通る。今回のバグの元凶。

### B. 固定3セル（中央固定）＋ 端クランプ・空白ページ ＋ `reloadData` で再センタリング
端の越えスワイプは「端では隣セルを作らない」で防げた。しかしスワイプ後の再センタリングに `reloadData` を使うと**中央セルも作り直され、画像が非同期再読み込みされる一瞬だけ暗転**した。着地画像を退避して即時セットする対処を入れたが、そもそも diffable + UUID なら「生き残ったセルは reload されない」ので暗転しない（パターン2）。

### C. `UIPageViewController`
`dataSource` が端で `nil` を返すだけで越えスワイプを防げるのは楽だった。しかし、
- ページごとに VC を生成するコストがあり、
- ボタン遷移のズーム維持のために「表示中VCの中身を差し替えて `dataSource` を差し直す」必要があり、
- 親の Observation 経由の同期（`moveToIndex`）が**高速スワイプ時に非同期遅延したインデックスでページャと綱引きになり一瞬引っかかった**（パターン7で解消したが、UICollectionViewの触り心地の方が良かった）。

### D. ±1（あるいは±n）ウィンドウ ＋ スワイプ時にスライド
保持セルを絞れるが、**高速スワイプでセルの用意（次ウィンドウのスライド）が間に合わない**。全件確保（パターン3）にしてスライド自体を無くした方が素直でスムーズだった。

### E. セル間の「ズーム比転送」（移動元の比率を移動先セルへ適用）
ボタン遷移でスクロールして別セルへ移り、移動元セルのズーム比を移動先へ渡す方式。→ うまく機能せず（タイミング・比率再計算が絡んで複雑）、筋も悪い。**表示セルの実体ごと移す（パターン4）**方が単純で確実だった。

---

## 診断の勘所（症状 → 原因）

| 症状 | 原因 |
|---|---|
| 最後の写真でも次へスワイプできる | SSOT違反（`layoutPageOffset` による二重管理）で幽霊ページが残る |
| スワイプ時に一瞬暗くなる | `reloadData` がセルを作り直し、画像を非同期で再読み込みする |
| 高速スワイプで一瞬引っかかる | 非同期更新された `currentIndex` の遅延 ＋ 無条件の `moveToIndex` がページャと綱引き |
| ボタンで縦横比の違う写真に切り替えると潰れる | 縦横比が違う画像へ `swapImageKeepingZoom`（`scaleToFill`）した |

---

## 関連

- 仕様（挙動の正）：[フォトビューア画面の仕様](spec-photo-viewer.md)
- 静止画PiP表示の実装知見：[pip-display.md](pip-display.md)
- 画面回転制御の実装知見：[orientation-control.md](orientation-control.md)
