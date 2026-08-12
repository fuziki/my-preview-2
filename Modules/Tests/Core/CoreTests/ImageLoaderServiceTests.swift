import Testing
import Foundation
@testable import Core

struct ImageLoaderServiceTests {

    @Test
    func loadImage_returnsNil_whenFileDoesNotExist() async {
        let service = ImageLoaderService(tracker: FileLoadingTracker())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")

        let image = await service.loadImage(from: url)

        #expect(image == nil)
    }

    @Test
    func loadImage_returnsDecodedImage_forExistingJPEG() async throws {
        let service = ImageLoaderService(tracker: FileLoadingTracker())
        let url = try JPEGFixture.write(size: CGSize(width: 4, height: 4))
        defer { try? FileManager.default.removeItem(at: url) }

        let image = await service.loadImage(from: url)

        #expect(image != nil)
    }

    /// キャッシュされていればファイル削除後も読み込めることを確認し、
    /// 2回目以降がディスクを再読込していないことを検証する
    @Test
    func loadImage_returnsCachedImage_afterUnderlyingFileDeleted() async throws {
        let service = ImageLoaderService(tracker: FileLoadingTracker())
        let url = try JPEGFixture.write(size: CGSize(width: 4, height: 4))

        let first = await service.loadImage(from: url)
        #expect(first != nil)

        try FileManager.default.removeItem(at: url)

        let second = await service.loadImage(from: url)
        #expect(second != nil)
    }
}
