# 静止画をPicture in Pictureで表示する実装知見

`AVSampleBufferDisplayLayer` + `AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer:playbackDelegate:)` は本来カメラプレビューや通話映像など「継続的にフレームが流れてくる」コンテンツ向けのAPIだが、これを静止画（写真）のスライドショー表示に転用したときの知見をまとめる。iOS 26（Xcode 26 SDK）時点の実機検証に基づく。

対象の実装：`ImagePiPController`（`Modules/Sources/Kits/ImagePiPKit/ImagePiPController.swift`、依存なしの独立モジュール）。`PhotoViewerViewController`（`Modules/Sources/Features/PhotoViewer/PhotoViewer/Views/PhotoViewerViewController.swift`）から利用する。仕様としての詳細は [フォトビューア画面の仕様](spec-photo-viewer.md) の「PiP表示」節を参照。

---

## 全体の仕組み

`layerClass` に `AVSampleBufferDisplayLayer` を持つ `UIView`（`SampleBufferDisplayView`）を用意し、`UIImage` を `CVPixelBuffer` → `CMSampleBuffer` に変換して `enqueue` する。`AVPictureInPictureController` はこのレイヤーを `ContentSource` として受け取り、PiPウィンドウにその内容を表示する。

写真を切り替えるたびに新しい `CMSampleBuffer` を1枚 `enqueue` するだけで、動画のように連続してフレームを供給する必要は無い（`AVSampleBufferDisplayLayer` は次の `enqueue` まで直前のフレームを表示し続ける）。

---

## 実機ログで確定した落とし穴

推測でパッチを重ねるのではなく、実機での再現とAppleの公式説明（WWDCセッション等）で原因を特定したもの。原因を特定せずに次の修正を当てると、同じ間違った仮定の上に積み重ねることになるので注意。

### `CVPixelBuffer` がIOSurfaceで裏付けされていないとPiPに何も表示されない

PiPウィンドウはアプリと別プロセス（システムのコンポジタ）でレンダリングされるため、フレームはプロセス間で転送される。`CVPixelBufferCreate` の属性に `kCVPixelBufferIOSurfacePropertiesKey` を含めないと、この転送に失敗し `<<<< FigSampleBufferSerialization >>>> signalled err=-19642` という警告とともに映像が表示されない。

```swift
let attributes: [CFString: Any] = [
    kCVPixelBufferCGImageCompatibilityKey: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    kCVPixelBufferIOSurfacePropertiesKey: [:],  // これが無いとFigSampleBufferSerializationエラーになる
]
```

### フル解像度の写真をそのまま渡すと同じエラーになる

上記のIOSurface対応をしても、写真アプリの元データ（数千万画素になり得る）をそのまま `CVPixelBuffer` 化すると1フレームあたりのペイロードが過大になり、同じくプロセス間転送に失敗する。PiPウィンドウ自体は小さく表示されるため、長辺を `maxPixelDimension`（1280px）まで縮小してから変換する。

### `isPictureInPicturePossible` は1回の `enqueue` だけでは `true` にならない

`enqueue` 直後に `startPictureInPicture()` を呼んでも `isPictureInPicturePossible` が `false` のままで、PiPボタンを押しても無反応に見える。システムが「継続的にフレームが供給されている」ことを確認してから `true` にするためと考えられる。`true` になるまで同じ画像を短い間隔（0.2秒）で再 `enqueue` し続けてから `startPictureInPicture()` を呼ぶ「ウォームアップ」処理（`startPriming`、最大25回・約5秒でタイムアウト）で解決した。

```swift
private func startPriming(image: UIImage, controller: AVPictureInPictureController) {
    primingTask = Task { [weak self] in
        guard let self else { return }
        for attempt in 0..<25 {
            guard !Task.isCancelled else { return }
            self.update(image: image)
            if controller.isPictureInPicturePossible {
                controller.startPictureInPicture()
                return
            }
            try? await Task.sleep(for: .seconds(0.2))
        }
    }
}
```

初回タップで反応が無く2回目のタップで開始する、という中途半端な症状（1回目のenqueueだけでは`true`にならないが、2回目のenqueueで確定する）から突き止めた。

### `AVPictureInPictureController.requiresLinearPlayback` の既定値のままだとスキップボタンが常に無効

`true`（既定）だと、PiP標準の±10秒スキップボタンが表示はされるが常にグレーアウトして押せない。明示的に `false` にする必要がある。

```swift
controller.requiresLinearPlayback = false
```

### `AVSampleBufferDisplayLayer.controlTimebase` を設定しないとレイヤーが「停止中」とみなされる

`controlTimebase` が無い（または `rate` が0の）状態だと、レイヤーが停止中とみなされ、スキップボタン等の操作系が機能しない。ホストクロック起点・`rate = 1.0` の `CMTimebase` を作成してレイヤーに設定する必要がある。

```swift
var timebase: CMTimebase?
CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
CMTimebaseSetTime(timebase!, time: .zero)
CMTimebaseSetRate(timebase!, rate: 1.0)
displayLayer.controlTimebase = timebase
```

`enqueue` する各サンプルバッファの `presentationTimeStamp` も、このタイムベースから取得した時刻（`CMTimebaseGetTime`）を使う。レイヤーの時間軸と無関係な時刻（例えば単純にホストクロックを毎回読むだけ）だと整合しない。

### `pictureInPictureControllerTimeRangeForPlayback` の `duration` に `.positiveInfinity` を返してはいけない

「時間の概念が無い静止画コンテンツだから無限長でいいだろう」という直感的な実装は誤り。Apple公式の説明の通り、無限長の `duration` は「これはライブ配信である」というシステムへの合図になる。

> Use a time range with an infinite duration to indicate live content.

その結果、ライブ配信の仕様通り一時停止・スキップの操作系が丸ごと無効化される（見た目はLIVE表示になり操作不能になる）。有限（ただし十分に長い）`duration` を返すことで「ライブではない通常コンテンツ」として扱わせる必要がある。`start` は `.zero` にする（`.negativeInfinity` にするとスキップボタンの状態計算が壊れて常に無効化される）。

```swift
private static let virtualDuration = CMTime(seconds: 24 * 60 * 60, preferredTimescale: 600)  // 24時間分

func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
    CMTimeRange(start: .zero, duration: Self.virtualDuration)
}
```

24時間という値は「実用上ユーザーがそこまで長く使い続けない」ことを前提にした簡易的な対処。長時間PiPを開きっぱなしにする使い方も想定するなら、時間経過に応じて動的に延長する仕組みが必要になる。

### `isPlaybackPaused` を常に `false` で返すと一時停止ボタンの操作が反映されない

`setPlaying(_:)` で受け取った再生状態を保持せず `isPlaybackPaused` が常に同じ値を返していると、システム側のボタン操作とアプリの内部状態が食い違い、ボタンが反応していないように見える。`setPlaying(_:)` で状態を保持し、`isPlaybackPaused` から返すとともに、`controlTimebase` の `rate` も実際に0/1へ切り替える。

```swift
func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
    isPaused = !playing
    if let controlTimebase {
        CMTimebaseSetRate(controlTimebase, rate: playing ? 1.0 : 0.0)
    }
}

func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
    isPaused
}
```

### completionハンドラ版とasync版の `skipByInterval` は同一のObjective-Cセレクタに衝突する

`AVPictureInPictureSampleBufferPlaybackDelegate` にはcompletionハンドラ版（iOS 15〜）とasync版（iOS 16〜）の `skipByInterval` があり、「両方実装しておけばOSバージョン差異を吸収できる」という情報があるが、実際には両方を同一クラスに実装すると

```
method 'pictureInPictureController(_:skipByInterval:completion:)' with Objective-C selector
'pictureInPictureController:skipByInterval:completionHandler:' conflicts with method
'pictureInPictureController(_:skipByInterval:)' with the same Objective-C selector
```

というビルドエラーになる。デプロイ対象がiOS 26であれば、async版のみを実装すればよい。

### バックグラウンドでは `updateProperties()` に頼るとPiP表示の更新が反映されない

`PhotoViewerViewController` は `viewModel.currentImage` の変化を `UIViewController.updateProperties()`（Observation駆動、UIKitの通常の描画更新サイクルに連動して呼ばれる）で検知し、PiP側にも `pipController.update(image:)` で反映していた。ViewModel自体はバックグラウンドでも正しく更新される（`currentIndex`・`currentImage` は変わる）が、`updateProperties()` の呼び出しスケジューリングはUIKitの描画更新サイクルに乗るため、アプリがバックグラウンドの間はスケジュールされにくい。

症状としては「PiPのスキップボタン・自動送りで内部的には次の写真に進んでいるが、PiPの表示は変わらない。アプリをフォアグラウンドに戻すと反映される」という形で現れる。

対処は、スキップ・自動送りのハンドラ内でナビゲーション完了後に `pipController.update(image:)` を直接呼び出すこと。`updateProperties()` 経由の描画更新サイクル待ちを回避し、フォアグラウンド/バックグラウンドどちらでも即座に反映される。

```swift
pipController.onSkipForward = { [weak self] in
    Task {
        await self?.viewModel.navigateNext()
        self?.pushCurrentImageToPiPIfNeeded()  // updateProperties()を待たず直接反映
    }
}
```

---

## 再生/一時停止で自動送りを制御する設計

PiP標準の再生/一時停止ボタンをスライドショーのON/OFFとして使う。`setPlaying(_:)` で受け取った状態に応じて `ImagePiPController` 内部の `Task` ベースの自動送りタイマーを開始/停止し、発火するたびに `onAutoAdvanceTick` を呼ぶ。ロジック（何秒間隔か、末尾でどう遷移するか）は `ImagePiPController` に持たせず、呼び出し側（`PhotoViewerViewModel`）に委ねている。

- PiP開始直後は「再生中」として扱うため、`pictureInPictureControllerDidStartPictureInPicture` でもタイマーを開始する。
- スキップボタン（`onSkipForward`/`onSkipBackward`）は末尾/先頭で停止する（`viewModel.navigateNext()`/`navigatePrevious()`、無反応でよい仕様）。自動送り（`onAutoAdvanceTick`）は末尾で先頭へ固定でループする（`viewModel.advanceForPictureInPictureAutoPlay()`）。同じ「写真を1つ進める」操作でも、ユーザーの能動的な操作か自動送りかで境界の挙動を分けている。

---

## 検討したが不採用にしたもの

| 案 | 不採用の理由 |
|---|---|
| PiP自動送りのON/OFFを設定Menuの専用トグルで持つ | 当初はこの設計で実装したが、後にPiP標準の再生/一時停止ボタンをON/OFFとして使う設計に統合した。設定Menuには間隔（秒）のみが残っている |
| `pictureInPictureControllerTimeRangeForPlayback` に `CMTimeRange(start: .negativeInfinity, end: .positiveInfinity)` を返す | 「時間の概念が無いので無限長でよい」という直感的な実装だったが、`start` が `.negativeInfinity` だとスキップボタンの状態計算が壊れて常に無効化される。さらに `duration` 側の無限長は「ライブ配信」の合図になるため、二重に誤りだった |
| `AVPictureInPictureSampleBufferPlaybackDelegate` のcompletionハンドラ版とasync版の両方を実装 | Objective-Cセレクタの衝突でビルドエラーになるため、デプロイ対象のOSバージョンに応じてどちらか一方のみを実装する必要がある |

## 参照

- [フォトビューア画面の仕様](spec-photo-viewer.md) の「PiP表示」節（ユーザー向け仕様としての詳細）
- `Modules/Sources/Kits/ImagePiPKit/ImagePiPController.swift`
- `Modules/Sources/Features/PhotoViewer/PhotoViewer/Views/PhotoViewerViewController.swift`（PiP関連の配線）
