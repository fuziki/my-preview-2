import Testing
import Foundation
@testable import Core

struct ThumbnailServiceTests {

    @Test
    func cachedThumbnail_returnsNil_beforeLoading() {
        let service = ThumbnailService(tracker: FileLoadingTracker())
        let url = URL(string: "file:///not-loaded.jpg")!

        #expect(service.cachedThumbnail(for: url) == nil)
    }

    @Test
    func loadThumbnail_returnsNil_whenFileDoesNotExist() async {
        let service = ThumbnailService(tracker: FileLoadingTracker())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")

        let thumbnail = await service.loadThumbnail(url: url, maxPixelSize: 8)

        #expect(thumbnail == nil)
    }

    @Test
    func loadThumbnail_constrainsLargestDimension_toMaxPixelSize() async throws {
        let service = ThumbnailService(tracker: FileLoadingTracker())
        let url = try JPEGFixture.write(size: CGSize(width: 64, height: 32))
        defer { try? FileManager.default.removeItem(at: url) }

        let thumbnail = try #require(await service.loadThumbnail(url: url, maxPixelSize: 8))

        #expect(max(thumbnail.size.width, thumbnail.size.height) <= 8)
    }

    @Test
    func cachedThumbnail_returnsCachedImage_afterLoadThumbnail() async throws {
        let service = ThumbnailService(tracker: FileLoadingTracker())
        let url = try JPEGFixture.write(size: CGSize(width: 8, height: 8))
        defer { try? FileManager.default.removeItem(at: url) }

        _ = await service.loadThumbnail(url: url, maxPixelSize: 8)

        #expect(service.cachedThumbnail(for: url) != nil)
    }
}
