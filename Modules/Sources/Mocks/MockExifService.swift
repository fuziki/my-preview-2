import Foundation
import Core

#if targetEnvironment(simulator)
/// シミュレータビルド用のExifServiceモック。固定のExif情報を返す。
public final class MockExifService: ExifServiceProtocol {
    public init() {}

    public func extractExif(from url: URL) async -> ExifInfo? {
        ExifInfo(
            iso: "ISO 400",
            focalLength: "35mm",
            exposureValue: "±0EV",
            fNumber: "f/2.8",
            shutterSpeed: "1/250s",
            flashFired: false
        )
    }
}
#endif
