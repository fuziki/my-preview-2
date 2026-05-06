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

// MARK: - AppSettingsServiceProtocol

protocol AppSettingsServiceProtocol: AnyObject {
    var viewMode: ViewMode { get set }
    var saveFormat: SaveFormat { get set }
}

// MARK: - AppSettingsService

final class AppSettingsService: AppSettingsServiceProtocol {
    static let shared = AppSettingsService()

    private static let viewModeKey = "AppSettings.viewMode"
    private static let saveFormatKey = "AppSettings.saveFormat"

    private init() {}

    var viewMode: ViewMode {
        get { ViewMode(rawValue: UserDefaults.standard.string(forKey: Self.viewModeKey) ?? "") ?? .list }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.viewModeKey) }
    }

    var saveFormat: SaveFormat {
        get { SaveFormat(rawValue: UserDefaults.standard.string(forKey: Self.saveFormatKey) ?? "") ?? .jpegAndRaw }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.saveFormatKey) }
    }
}
