import UIKit
import AVFoundation

/// AVSampleBufferDisplayLayerをlayerとして持つUIView。
/// Auto Layoutでサイズを指定すると、レイヤーのframeも自動的に追従する。
final class SampleBufferDisplayView: UIView {
    override static var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }
}
