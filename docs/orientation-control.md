# 画面単位で画面回転を動的に制御する実装知見

特定の `UIViewController`（本アプリでは `PhotoViewerViewController`）だけ画面回転の許可範囲をユーザー操作で動的に切り替え、他の画面（`FileBrowserViewController`）は常に端末の設定に従わせたい、という要件を実装したときの知見をまとめる。iOS 26（Xcode 26 SDK）時点の挙動に基づく。

対象の実装：`PhotoViewerViewController`（`Modules/Sources/PhotoViewer/Views/PhotoViewerViewController.swift`）。仕様としての詳細は [フォトビューア画面の仕様](spec-photo-viewer.md) の「画面回転ボタン」節を参照。

---

## 3層構造で考える

「回転できない／反映されない」系の不具合は、必要な仕組みが3層あることを理解していないと沼りやすい。

| 層 | 役割 | 単体で持つ効果 |
|---|---|---|
| ① `supportedInterfaceOrientations`（VCのcomputed property） | 現在許可する向きのマスクを返す | **許可範囲の宣言のみ**。これだけでは画面は回転しない |
| ② `setNeedsUpdateOfSupportedInterfaceOrientations()` | 「①を再照会して」とシステムに伝える | 再照会の予約のみ。単体では画面は回転しない |
| ③ `windowScene.requestGeometryUpdate(.iOS(interfaceOrientations:))` | 実際にその向きへ**能動的に**回転させる命令 | ③を呼んで初めて画面が回転する |

ユーザー操作で即座に向きを変えたい場合は②だけでなく③が必須。①②③は必ずセットで呼ぶ。

```swift
// PhotoViewerViewController.swift
override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    switch viewModel.orientationLock {
    case .followSystem: super.supportedInterfaceOrientations
    case .portrait: .portrait
    case .landscape: .landscape
    }
}

private func applyOrientationLock() {
    guard let windowScene = view.window?.windowScene else { return }
    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: supportedInterfaceOrientations)) { _ in }
    setNeedsUpdateOfSupportedInterfaceOrientations()
}
```

`applyOrientationLock()` はボタンタップ時と `viewDidAppear`（`view.window` が確実に取得できるタイミング。`viewWillAppear`ではまだ`nil`のことがある）の両方で呼ぶ。前者はユーザー操作への即時反映、後者は「前回ロックした向きのまま再表示する」ケースの初期反映のため。

---

## 実機ログで確定した落とし穴

推測でパッチを重ねるのではなく、`os.Logger` で実際にログを取り実機で再現・特定したもの。原因を特定せずに次の修正を当てると、同じ間違った仮定の上に積み重ねることになるので注意。

### `presentingViewController` / `view.window` は `viewDidDisappear` 時点で `nil` になる

dismiss完了後はこれらの参照自体が失われる。閉じた後にpresenter側へ何か伝えたい処理は、**まだ有効な `viewWillDisappear` で参照を捕捉**しておく必要がある。

### dismissアニメーション進行中に `requestGeometryUpdate` を発行すると表示が崩れる

進行中のトランジションのビュー階層（閉じようとしているVCと、現れようとしているpresenter側の両方）と衝突し、`Unable to simultaneously satisfy constraints` の連発とともにレイアウトが「90度回転したような」崩れ方をする。

**対処（両方をまとめて解決する）**：参照は `viewWillDisappear` で `weak` プロパティに捕捉しておき、実際の要求は `viewDidDisappear`（トランジション完了後にしか呼ばれないため、進行中との衝突が起きない）で行う。`transitionCoordinator.animate(alongsideTransition:)` の完了コールバックを使う案も検討したが、`viewDidDisappear` を使えば同じタイミングをより単純な構造（追加のプロパティ2つのみ、分岐無し）で実現できるためこちらを採用した。プロパティは `weak` にしてVC間の不要な強参照を避け、使用後は `nil` に戻す。

```swift
/// dismiss完了後に向きを戻すための参照。`presentingViewController`/`view.window`は
/// `viewDidDisappear`の時点では既に`nil`になっているため、まだ有効な`viewWillDisappear`で捕捉しておく。
private weak var orientationRevertPresenter: UIViewController?
private weak var orientationRevertScene: UIWindowScene?

override public func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if isBeingDismissed, viewModel.orientationLock != .followSystem {
        orientationRevertPresenter = presentingViewController
        orientationRevertScene = view.window?.windowScene
    }
}

override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard let presenter = orientationRevertPresenter, let scene = orientationRevertScene else { return }
    orientationRevertPresenter = nil
    orientationRevertScene = nil
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: presenter.supportedInterfaceOrientations)) { _ in }
}
```

---

## 今後の拡張に向けた追加の落とし穴（コミュニティ知見・本アプリでは未確定）

別の画面や要件変更でハマりやすいとされる罠。本アプリで実際に踏んだものではないため、鵜呑みにせず個別に確度を確認した。

### コンテナ（`UINavigationController` 等）に包むと ① が呼ばれなくなる、という主張について

「コンテナの子VCとして配置すると、システムは常にコンテナ側にしか `supportedInterfaceOrientations` を問い合わせないため、コンテナ側で `topViewController` に委譲するoverrideが必要」という情報がある。

ただし本アプリの `FileBrowserViewController` は `UINavigationController` に包まれた状態（`AppMain.makeWindow(windowScene:)` 参照）のまま、この委譲overrideを一切書かずに向きの制御が正しく機能している。`UINavigationController`/`UITabBarController` は標準で表示中の子VCへ問い合わせを委譲する実装を持つため、**標準コンテナである限りこの対処は不要**というのが本アプリでの実態。独自のカスタムコンテナVCを実装する場合にのみ、当てはまる可能性がある知見として留めておく。

### iPadのマルチタスク（Split View等）で `requestGeometryUpdate` が無視される

iPadでマルチタスク（Split View / Slide Over / Stage Manager）が有効な状態では、アプリ側からの `requestGeometryUpdate` による強制的なジオメトリ変更がOS仕様で無視されるという情報がある。対処は `Info.plist` の `UIRequiresFullScreen` を `YES` にしてマルチタスクをオプトアウトすること。

**本アプリでの位置付け（未検証・要判断）**：`TARGETED_DEVICE_FAMILY = "1,2"`（iPhone + iPad対応）かつ `UIRequiresFullScreen` は未設定のため、iPad実機でマルチタスクを有効にした状態だと画面回転ボタンが効かない可能性がある。ただし `UIRequiresFullScreen = YES` はアプリ全体でSplit View/Slide Over/Stage Managerを無効化する、画面回転機能の範囲を超えた製品判断になるため、確認なしに設定変更はしていない。iPad実機での検証、および対応する場合の方針（マルチタスクを諦めてでもフォトビューアの向き固定を優先するか等）はユーザー側の判断を仰ぎたい。

### コントロールセンターの「画面向きロック」との力関係

`requestGeometryUpdate` は、ユーザーがOSのコントロールセンターで設定している向きロックを無視して強制回転させられる。これは前項のdismiss時revert処理が必要になる直接の理由でもある：revert処理を忘れると、ユーザーが縦ロックしているのにアプリ全体が横向きのまま固定されるバグになる。

---

## 検討したが不採用にしたもの

| 案 | 不採用の理由 |
|---|---|
| `AppDelegate.application(_:supportedInterfaceOrientationsFor:)` を実装し、最前面のpresented VCまで手動で辿る | `PhotoViewerViewController` は `UINavigationController` 等のコンテナに包まれず直接 `present` されるため、UIKit標準の問い合わせで最前面のVCまで正しく届く。実装しても効果が無く、単なる複雑化だった |
| `prefersInterfaceOrientationLocked` / `setNeedsUpdateOfPrefersInterfaceOrientationLocked()`（iOS 26新API。「現在の向きに固定する」ことをVCが希望として表明する仕組み） | `supportedInterfaceOrientations` でマスクを`.portrait`/`.landscape`単一に絞るだけで、端末を傾けても対象外の向きには回転しないため、十分ロックとして機能した。追加の必要が無かった |
| `FileBrowserViewController` 側を `.portrait` 固定にし、`PhotoViewerViewController` 側の能動的な「戻す」処理を無くす | 実際に試して検証したが、期待したような簡略化にはならなかった。`FileBrowser` は仕様上「常に端末の設定に従う」ため、この案自体が要件と矛盾する |
| `SceneDelegate.windowScene(_:didUpdateEffectiveGeometry:)` で `window.frame`/`screen.bounds` を明示的に補正する（`AppMain.correctWindowGeometry(_:)` → 後にWWDC26推奨の `setNeedsLayout()` のみの版 `handleWindowSceneGeometryChange(_:)` に置き換え） | `requestGeometryUpdate` 成功後に `window.bounds`/`frame` が古い向きのまま追従しない症状への対処として一時実装したが、最終的に `AppMain`/`SceneDelegate` から削除した。同種の症状が再発した場合はこの案を再検討する |
| revert処理内で `presenter.setNeedsUpdateOfSupportedInterfaceOrientations()` も呼ぶ | 当初はセットで呼んでいたが、最終的なコードでは `requestGeometryUpdate` の呼び出しのみになっている |

## 参照

- [フォトビューア画面の仕様](spec-photo-viewer.md) の「画面回転ボタン」節（ユーザー向け仕様としての詳細）
- `Modules/Sources/PhotoViewer/Views/PhotoViewerViewController.swift`
