import Photos

public enum PhotoLibraryError: Error {
    case unauthorized
}

public protocol PhotoLibraryServiceProtocol {
    func save(fileURL: URL) async throws
}

public final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    private let settings: any UserDefaultsSettingsStoreProtocol

    public init(settings: any UserDefaultsSettingsStoreProtocol) {
        self.settings = settings
    }

    public func save(fileURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.unauthorized
        }

        let rawURL = settings.saveFormat == .jpegAndRaw ? findRawFile(for: fileURL) : nil

        try await performSave(jpegURL: fileURL, rawURL: rawURL)
    }

    // defaultIsolation(MainActor.self) により @MainActor 隔離されたクロージャを
    // Photos フレームワークのスレッドから呼び出すと actor 隔離違反でクラッシュするため nonisolated にする
    private nonisolated func performSave(jpegURL: URL, rawURL: URL?) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = jpegURL.lastPathComponent
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: jpegURL, options: options)

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
