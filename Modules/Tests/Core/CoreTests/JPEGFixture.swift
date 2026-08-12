import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// テストから実際にデコード可能なJPEGファイルを一時ディレクトリへ書き出すためのフィクスチャ生成器。
/// ExifService/ImageLoaderService/ThumbnailServiceのテストで共有する。
enum JPEGFixture {
    enum FixtureError: Error {
        case cgImageUnavailable
        case destinationCreationFailed
        case finalizeFailed
    }

    /// - Parameters:
    ///   - size: 生成する画像のピクセルサイズ
    ///   - exif: JPEGへ埋め込むEXIF辞書（kCGImagePropertyExif*キー）。nilならEXIFなし
    @discardableResult
    static func write(
        size: CGSize = CGSize(width: 8, height: 8),
        exif: [CFString: Any]? = nil,
        to directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let url = directory.appendingPathComponent(UUID().uuidString + ".jpg")

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let cgImage = image.cgImage else {
            throw FixtureError.cgImageUnavailable
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw FixtureError.destinationCreationFailed
        }
        var properties: [CFString: Any] = [:]
        if let exif {
            properties[kCGImagePropertyExifDictionary] = exif
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw FixtureError.finalizeFailed
        }

        try (data as Data).write(to: url)
        return url
    }
}
