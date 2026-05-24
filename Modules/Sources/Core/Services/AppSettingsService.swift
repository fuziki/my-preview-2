import Foundation

// MARK: - ViewMode

public enum ViewMode: String {
    case list, grid
}

// MARK: - FileSortOrder

public enum FileSortOrder: String {
    case dateDescending  // 新しい順（デフォルト）
    case dateAscending   // 古い順
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
