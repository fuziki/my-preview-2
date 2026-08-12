import Testing
import Foundation
@testable import Core

struct FileSystemServiceTests {

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFile(named name: String, in directory: URL, creationDate: Date? = nil) {
        let url = directory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        if let creationDate {
            try? FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: url.path)
        }
    }

    @Test
    func scanForJPEGs_emptyDirectory_returnsEmpty() async {
        let service = FileSystemService(tracker: FileLoadingTracker())
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let items = await service.scanForJPEGs(in: directory)

        #expect(items.isEmpty)
    }

    @Test
    func scanForJPEGs_filtersToJpgAndJpegExtensions_caseInsensitive() async {
        let service = FileSystemService(tracker: FileLoadingTracker())
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        writeFile(named: "a.jpg", in: directory)
        writeFile(named: "b.JPEG", in: directory)
        writeFile(named: "c.jpeg", in: directory)
        writeFile(named: "note.txt", in: directory)
        writeFile(named: "d.png", in: directory)

        let items = await service.scanForJPEGs(in: directory)

        #expect(Set(items.map(\.name)) == ["a.jpg", "b.JPEG", "c.jpeg"])
    }

    @Test
    func scanForJPEGs_excludesHiddenFiles() async {
        let service = FileSystemService(tracker: FileLoadingTracker())
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        writeFile(named: "visible.jpg", in: directory)
        writeFile(named: ".hidden.jpg", in: directory)

        let items = await service.scanForJPEGs(in: directory)

        #expect(items.map(\.name) == ["visible.jpg"])
    }

    @Test
    func scanForJPEGs_sortsByCreationDateAscending() async {
        let service = FileSystemService(tracker: FileLoadingTracker())
        let directory = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        writeFile(named: "newest.jpg", in: directory, creationDate: base.addingTimeInterval(200))
        writeFile(named: "oldest.jpg", in: directory, creationDate: base)
        writeFile(named: "middle.jpg", in: directory, creationDate: base.addingTimeInterval(100))

        let items = await service.scanForJPEGs(in: directory)

        #expect(items.map(\.name) == ["oldest.jpg", "middle.jpg", "newest.jpg"])
    }
}
