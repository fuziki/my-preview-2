import UIKit
import AVKit
import AVFoundation
import CoreMedia
import CoreVideo
import os

/// 静止画をシステムのPicture in Pictureウィンドウに表示するコントローラ。
/// AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer:playbackDelegate:)を使い、
/// UIImageをCMSampleBufferへ変換して流し込むことで、動画を使わずにPiP表示を実現する。
public final class ImagePiPController: NSObject {

    /// 実行環境がPiPに対応しているか
    public static var isSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    /// PiPが開始した時に呼ばれる
    public var onDidStart: (() -> Void)?
    /// PiPが終了した時に呼ばれる（開始失敗時も含む）
    public var onDidStop: (() -> Void)?
    /// PiP標準の「進む」スキップボタンがタップされた時に呼ばれる
    public var onSkipForward: (() -> Void)?
    /// PiP標準の「戻る」スキップボタンがタップされた時に呼ばれる
    public var onSkipBackward: (() -> Void)?

    public var isActive: Bool { pipController?.isPictureInPictureActive ?? false }

    private static let logger = Logger(subsystem: "ImagePiPKit", category: "ImagePiPController")
    /// PiPウィンドウは小さく表示されるため、フルサイズの写真をそのまま渡すとプロセス間転送のペイロードが
    /// 過大になりFigSampleBufferSerializationエラーの原因になる。長辺をこのサイズまで縮小する
    private static let maxPixelDimension: CGFloat = 1280
    /// システムに「ライブ配信ではなく、十分に長い通常コンテンツ」と伝えるための仮想的な尺（24時間分）。
    /// pictureInPictureControllerTimeRangeForPlaybackにdurationとして.positiveInfinityを返すと
    /// 「ライブ配信」の合図になり一時停止・スキップの操作系が丸ごと無効化されるため、有限値にする必要がある
    private static let virtualDuration = CMTime(seconds: 24 * 60 * 60, preferredTimescale: 600)

    private let containerView: UIView
    private let displayView = SampleBufferDisplayView()
    private var pipController: AVPictureInPictureController?
    private var primingTask: Task<Void, Never>?
    /// レイヤーに「再生中」であることを認識させるためのタイムベース。
    /// これが無い（またはrateが0の）ままだとPiPが停止中とみなされ、スキップボタンが機能しない
    private var controlTimebase: CMTimebase?
    /// PiP標準の一時停止ボタンで操作された状態。isPlaybackPausedで返し、システム側の表示と一致させる
    private var isPaused = false

    public init(containerView: UIView) {
        self.containerView = containerView
        super.init()
    }

    /// PiPソースレイヤーをcontainerViewいっぱいに配置する。viewDidLoad等で一度だけ呼ぶ。
    public func attach() {
        displayView.translatesAutoresizingMaskIntoConstraints = false
        displayView.isUserInteractionEnabled = false
        displayView.sampleBufferDisplayLayer.videoGravity = .resizeAspect
        containerView.insertSubview(displayView, at: 0)
        NSLayoutConstraint.activate([
            displayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            displayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            displayView.topAnchor.constraint(equalTo: containerView.topAnchor),
            displayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        setupControlTimebase()
    }

    private func setupControlTimebase() {
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(
            allocator: kCFAllocatorDefault,
            sourceClock: CMClockGetHostTimeClock(),
            timebaseOut: &timebase
        )
        guard let timebase else { return }
        CMTimebaseSetTime(timebase, time: .zero)
        // rateを1にして進行させることで、システムに「再生中」と認識させる
        CMTimebaseSetRate(timebase, rate: 1.0)
        displayView.sampleBufferDisplayLayer.controlTimebase = timebase
        controlTimebase = timebase
    }

    /// PiPを開始する
    public func start(image: UIImage) {
        if pipController == nil {
            // PiPのバックグラウンド継続にはaudioセッションのアクティブ化が必要（無音でも必須）
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            let contentSource = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: displayView.sampleBufferDisplayLayer,
                playbackDelegate: self
            )
            let controller = AVPictureInPictureController(contentSource: contentSource)
            controller.delegate = self
            // trueのままだとスキップボタンが常に無効化されるため、明示的にfalseにする
            controller.requiresLinearPlayback = false
            pipController = controller
        }
        guard let pipController else { return }
        Self.logger.notice("start: isPictureInPictureSupported=\(Self.isSupported)")
        startPriming(image: image, controller: pipController)
    }

    /// isPictureInPicturePossibleは1枚のenqueueだけでは真にならないことがあるため、
    /// trueになるまで同じ画像を短い間隔で再enqueueし続けてから開始する
    private func startPriming(image: UIImage, controller: AVPictureInPictureController) {
        primingTask?.cancel()
        primingTask = Task { [weak self] in
            guard let self else { return }
            for attempt in 0..<25 {
                guard !Task.isCancelled else { return }
                self.update(image: image)
                if controller.isPictureInPicturePossible {
                    Self.logger.notice("isPictureInPicturePossible=true（\(attempt + 1)回目のenqueueで確定）。startPictureInPictureを呼ぶ")
                    controller.startPictureInPicture()
                    self.primingTask = nil
                    return
                }
                try? await Task.sleep(for: .seconds(0.2))
            }
            Self.logger.error("isPictureInPicturePossibleがタイムアウトまでにtrueにならなかった")
            self.primingTask = nil
        }
    }

    public func stop() {
        primingTask?.cancel()
        primingTask = nil
        pipController?.stopPictureInPicture()
    }

    /// 表示中の画像を更新する
    public func update(image: UIImage) {
        guard let sampleBuffer = makeSampleBuffer(from: image) else {
            Self.logger.error("CMSampleBufferの作成に失敗したためenqueueをスキップした")
            return
        }
        let layer = displayView.sampleBufferDisplayLayer
        if layer.status == .failed {
            Self.logger.warning("レイヤーがfailed状態だったためflushする: \(String(describing: layer.error))")
            layer.flush()
        }
        layer.enqueue(sampleBuffer)
    }

    // MARK: - UIImage → CMSampleBuffer変換

    private func makeSampleBuffer(from image: UIImage) -> CMSampleBuffer? {
        guard let pixelBuffer = Self.makePixelBuffer(from: image) else { return nil }
        var formatDescription: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard let formatDescription else {
            Self.logger.error("CMVideoFormatDescriptionCreateForImageBufferに失敗: status=\(formatStatus)")
            return nil
        }
        // presentationTimeStampはcontrolTimebaseと同じ時間軸から取る。durationを無限大にすることで
        // 次にenqueueするまでこの画像を表示し続けさせる
        let presentationTime = controlTimebase.map { CMTimebaseGetTime($0) } ?? CMClockGetTime(CMClockGetHostTimeClock())
        var timingInfo = CMSampleTimingInfo(
            duration: .positiveInfinity,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr else {
            Self.logger.error("CMSampleBufferCreateReadyWithImageBufferに失敗: status=\(status)")
            return nil
        }
        return sampleBuffer
    }

    private static func makePixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        // PiPウィンドウは小さいため、フルサイズの写真ではなく長辺maxPixelDimensionへ縮小してから渡す
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let scale = min(1, maxPixelDimension / max(originalWidth, originalHeight))
        let width = max(1, Int((originalWidth * scale).rounded()))
        let height = max(1, Int((originalHeight * scale).rounded()))

        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            // PiPはシステムの別プロセスでレンダリングされるため、プロセス間転送にIOSurfaceの裏付けが必須。
            // 無いと enqueue 時に FigSampleBufferSerialization エラーになる
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            logger.error("CVPixelBufferCreateに失敗: status=\(status)")
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            logger.error("CGContextの作成に失敗")
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension ImagePiPController: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        primingTask?.cancel()
        primingTask = nil
        onDidStart?()
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Self.logger.error("PiP開始に失敗: \(error.localizedDescription, privacy: .public)")
        primingTask?.cancel()
        primingTask = nil
        onDidStop?()
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        onDidStop?()
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension ImagePiPController: AVPictureInPictureSampleBufferPlaybackDelegate {
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        // 実際にタイムベースのrateを止める/進めることでシステム側の状態と一致させる。
        // これをしないとisPlaybackPausedが実態と食い違い、ボタン操作が反映されない
        isPaused = !playing
        if let controlTimebase {
            CMTimebaseSetRate(controlTimebase, rate: playing ? 1.0 : 0.0)
        }
    }

    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // durationに.positiveInfinityを返すと「ライブ配信」の合図になり一時停止・スキップが
        // 丸ごと無効化されるため、有限（十分に長い）durationを返して通常コンテンツとして扱わせる
        CMTimeRange(start: .zero, duration: Self.virtualDuration)
    }

    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        isPaused
    }

    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    // completionハンドラ版とasync版は同一のObjective-Cセレクタに衝突するため両方は実装できない。
    // デプロイ対象がiOS 26のためasync版のみ実装する
    public func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime
    ) async {
        handleSkip(interval: skipInterval)
    }

    private func handleSkip(interval: CMTime) {
        switch CMTimeCompare(interval, .zero) {
        case let comparison where comparison > 0:
            onSkipForward?()
        case let comparison where comparison < 0:
            onSkipBackward?()
        default:
            break
        }
    }

    public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        true
    }
}
