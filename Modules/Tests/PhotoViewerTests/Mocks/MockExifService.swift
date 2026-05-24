import Core
import Foundation

/// ExifServiceProtocolのテスト用モック
final class MockExifService: ExifServiceProtocol, @unchecked Sendable {
    var stubbedExif: ExifInfo? = ExifInfo(
        iso: "ISO 100",
        focalLength: "50mm",
        exposureValue: "±0EV",
        fNumber: "f/1.8",
        shutterSpeed: "1/250s",
        flashFired: false
    )
    var extractCallCount = 0

    func extractExif(from url: URL) async -> ExifInfo? {
        extractCallCount += 1
        return stubbedExif
    }
}
