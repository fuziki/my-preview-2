import Testing
import Foundation
@testable import Core

/// save(fileURL:)本体はPHPhotoLibrary依存のためテスト対象外。
/// findRawFile(for:)はファイルシステムのみに依存する純粋なロジックなので直接検証する。
struct PhotoLibraryServiceTests {

    private func makeService() -> PhotoLibraryService {
        let defaults = UserDefaults(suiteName: "PhotoLibraryServiceTests.\(UUID().uuidString)")!
        let store = UserDefaultsSettingsStore<UserDefaultsSettings>(defaultValue: .default(), defaults: defaults)
        return PhotoLibraryService(settings: store)
    }

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test
    func findRawFile_returnsNil_whenNoMatchingRawFile() {
        let service = makeService()
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let jpegURL = directory.appendingPathComponent("photo.jpg")
        FileManager.default.createFile(atPath: jpegURL.path, contents: Data())

        #expect(service.findRawFileForTest(for: jpegURL) == nil)
    }

    @Test
    func findRawFile_findsSameBaseName_withKnownRawExtension() {
        let service = makeService()
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let jpegURL = directory.appendingPathComponent("photo.jpg")
        let rawURL = directory.appendingPathComponent("photo.dng")
        FileManager.default.createFile(atPath: jpegURL.path, contents: Data())
        FileManager.default.createFile(atPath: rawURL.path, contents: Data())

        #expect(service.findRawFileForTest(for: jpegURL) == rawURL)
    }

    @Test
    func findRawFile_findsUppercaseExtension() {
        let service = makeService()
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let jpegURL = directory.appendingPathComponent("photo.jpg")
        let rawURL = directory.appendingPathComponent("photo.ARW")
        FileManager.default.createFile(atPath: jpegURL.path, contents: Data())
        FileManager.default.createFile(atPath: rawURL.path, contents: Data())

        #expect(service.findRawFileForTest(for: jpegURL) == rawURL)
    }

    @Test
    func findRawFile_ignoresFileWithDifferentBaseName() {
        let service = makeService()
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let jpegURL = directory.appendingPathComponent("photo.jpg")
        let unrelatedRawURL = directory.appendingPathComponent("other.dng")
        FileManager.default.createFile(atPath: jpegURL.path, contents: Data())
        FileManager.default.createFile(atPath: unrelatedRawURL.path, contents: Data())

        #expect(service.findRawFileForTest(for: jpegURL) == nil)
    }
}
