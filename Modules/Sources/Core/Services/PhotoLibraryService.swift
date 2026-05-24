import Photos

public enum PhotoLibraryError: Error {
    case unauthorized
}

public protocol PhotoLibraryServiceProtocol {
    func save(fileURL: URL) async throws
}

public final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    private let storage: any UserDefaultsStorageProtocol

    public init(storage: any UserDefaultsStorageProtocol = UserDefaultsStorage.shared) {
        self.storage = storage
    }

    public func save(fileURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.unauthorized
        }

        let saveFormat = SaveFormat(rawValue: storage.string(forKey: .saveFormat) ?? "") ?? .jpegAndRaw
        let rawURL = saveFormat == .jpegAndRaw ? findRawFile(for: fileURL) : nil

        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = fileURL.lastPathComponent
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: fileURL, options: options)

            if let rawURL {
                let rawOptions = PHAssetResourceCreationOptions()
                rawOptions.originalFilename = rawURL.lastPathComponent
                request.addResource(with: .alternatePhoto, fileURL: rawURL, options: rawOptions)
            }
        }
    }

    /// JPEGと同じディレクトリ内から同名のRAWファイルを探す
    private func findRawFile(for jpegURL: URL) -> URL? {
        let directory = jpegURL.deletingLastPathComponent()
        let baseName = jpegURL.deletingPathExtension().lastPathComponent
        let rawExtensions = ["dng", "arw", "cr2", "cr3", "nef", "orf", "raf", "rw2", "pef", "srw", "3fr"]

        for ext in rawExtensions {
            let rawURL = directory.appendingPathComponent(baseName).appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: rawURL.path) {
                return rawURL
            }
            // 大文字の拡張子も検索する
            let rawURLUpper = directory.appendingPathComponent(baseName).appendingPathExtension(ext.uppercased())
            if FileManager.default.fileExists(atPath: rawURLUpper.path) {
                return rawURLUpper
            }
        }
        return nil
    }
}
