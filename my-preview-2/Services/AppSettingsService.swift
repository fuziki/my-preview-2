import Foundation

// MARK: - ViewMode

enum ViewMode: String {
    case list, grid
}

// MARK: - SaveFormat

enum SaveFormat: String {
    case jpeg
    case jpegAndRaw

    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .jpegAndRaw: return "JPEG + RAW"
        }
    }
}
