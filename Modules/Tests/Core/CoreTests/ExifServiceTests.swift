import Testing
import Foundation
import ImageIO
@testable import Core

struct ExifServiceTests {

    @Test
    func extractExif_returnsNil_whenFileDoesNotExist() async {
        let service = ExifService(tracker: FileLoadingTracker())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")

        let info = await service.extractExif(from: url)

        #expect(info == nil)
    }

    @Test
    func extractExif_parsesAllFields_fromRealJPEGExif() async throws {
        let exif: [CFString: Any] = [
            kCGImagePropertyExifISOSpeedRatings: [400],
            kCGImagePropertyExifFocalLength: 50.0,
            kCGImagePropertyExifExposureBiasValue: 0.0,
            kCGImagePropertyExifFNumber: 2.8,
            kCGImagePropertyExifExposureTime: 1.0 / 125.0,
            kCGImagePropertyExifFlash: 1,
        ]
        let url = try JPEGFixture.write(exif: exif)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExifService(tracker: FileLoadingTracker())
        let info = try #require(await service.extractExif(from: url))

        #expect(info.iso == "ISO 400")
        #expect(info.focalLength == "50mm")
        #expect(info.exposureValue == "±0EV")
        #expect(info.fNumber == "f/2.8")
        #expect(info.shutterSpeed == "1/125s")
        #expect(info.flashFired == true)
    }

    @Test
    func extractExif_positiveExposureBias_formatsWithPlusSign() async throws {
        let exif: [CFString: Any] = [kCGImagePropertyExifExposureBiasValue: 1.5]
        let url = try JPEGFixture.write(exif: exif)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExifService(tracker: FileLoadingTracker())
        let info = try #require(await service.extractExif(from: url))

        #expect(info.exposureValue == "+1.5EV")
    }

    @Test
    func extractExif_negativeExposureBias_formatsWithMinusSign() async throws {
        let exif: [CFString: Any] = [kCGImagePropertyExifExposureBiasValue: -0.7]
        let url = try JPEGFixture.write(exif: exif)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExifService(tracker: FileLoadingTracker())
        let info = try #require(await service.extractExif(from: url))

        #expect(info.exposureValue == "-0.7EV")
    }

    @Test
    func extractExif_flashNotFired_whenBitNotSet() async throws {
        let exif: [CFString: Any] = [kCGImagePropertyExifFlash: 0]
        let url = try JPEGFixture.write(exif: exif)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExifService(tracker: FileLoadingTracker())
        let info = try #require(await service.extractExif(from: url))

        #expect(info.flashFired == false)
    }

    @Test
    func extractExif_longExposureTime_formatsInWholeSeconds() async throws {
        let exif: [CFString: Any] = [kCGImagePropertyExifExposureTime: 2.0]
        let url = try JPEGFixture.write(exif: exif)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = ExifService(tracker: FileLoadingTracker())
        let info = try #require(await service.extractExif(from: url))

        #expect(info.shutterSpeed == "2s")
    }
}
