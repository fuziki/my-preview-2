import ImageIO
import Foundation

protocol ExifServiceProtocol: AnyObject {
    func extractExif(from url: URL) async -> ExifInfo?
}

final class ExifService: ExifServiceProtocol {
    func extractExif(from url: URL) async -> ExifInfo? {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return Self.parse(data: data)
        }.value
    }

    private static nonisolated func parse(data: Data) -> ExifInfo? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
            return nil
        }

        let iso: String? = {
            guard let array = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
                  let value = array.first else { return nil }
            return "ISO \(value)"
        }()

        let focalLength: String? = {
            guard let fl = exif[kCGImagePropertyExifFocalLength as String] as? Double else { return nil }
            return String(format: "%.0fmm", fl)
        }()

        let exposureValue: String? = {
            guard let ev = exif[kCGImagePropertyExifExposureBiasValue as String] as? Double else { return nil }
            return ev == 0 ? "±0EV" : String(format: "%+.1fEV", ev)
        }()

        let fNumber: String? = {
            guard let fn = exif[kCGImagePropertyExifFNumber as String] as? Double else { return nil }
            return String(format: "f/%.1f", fn)
        }()

        let shutterSpeed: String? = {
            guard let et = exif[kCGImagePropertyExifExposureTime as String] as? Double, et > 0 else { return nil }
            return et >= 1.0 ? String(format: "%.0fs", et) : "1/\(Int(round(1.0 / et)))s"
        }()

        let flashFired: Bool = {
            guard let flashValue = exif[kCGImagePropertyExifFlash as String] as? Int else { return false }
            return (flashValue & 0x1) != 0
        }()

        return ExifInfo(
            iso: iso,
            focalLength: focalLength,
            exposureValue: exposureValue,
            fNumber: fNumber,
            shutterSpeed: shutterSpeed,
            flashFired: flashFired
        )
    }
}
