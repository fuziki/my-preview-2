import Foundation

// MARK: - ViewMode

public enum ViewMode: String {
    case list, grid
}

// MARK: - SaveFormat

public enum SaveFormat: String {
    case jpeg
    case jpegAndRaw

    public var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .jpegAndRaw: return "JPEG + RAW"
        }
    }
}
