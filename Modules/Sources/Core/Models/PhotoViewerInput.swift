import Foundation

public struct PhotoViewerInput: Sendable {
    public let initialURL: URL
    public let allURLs: [URL]

    public init(initialURL: URL, allURLs: [URL]) {
        self.initialURL = initialURL
        self.allURLs = allURLs
    }
}
