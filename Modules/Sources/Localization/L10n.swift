import Foundation

// MARK: - L10n

/// タイプセーフなローカライズ文言アクセサ（swiftgen生成コードの代替としてAIが手書きしたもの）
public enum L10n {

    // MARK: - Common

    public enum Common {
        public static var cancel: String { tr("common.cancel") }
        public static var clear: String { tr("common.clear") }
        public static var copiedToClipboard: String { tr("common.copied_to_clipboard") }
    }

    // MARK: - FileBrowser

    public enum FileBrowser {
        public static var openFolder: String { tr("file_browser.open_folder") }
        public static var viewMode: String { tr("file_browser.view_mode") }
        public static var viewModeList: String { tr("file_browser.view_mode_list") }
        public static var viewModeGrid: String { tr("file_browser.view_mode_grid") }
        public static var saveFormat: String { tr("file_browser.save_format") }
        public static var sortOrder: String { tr("file_browser.sort_order") }
        public static var sortOrderNewestFirst: String { tr("file_browser.sort_order_newest_first") }
        public static var sortOrderOldestFirst: String { tr("file_browser.sort_order_oldest_first") }
        public static var clearCache: String { tr("file_browser.clear_cache") }
        public static var clearCacheAlertMessage: String { tr("file_browser.clear_cache_alert_message") }
        public static var columnCount: String { tr("file_browser.column_count") }
        public static var columnCountDecrement: String { tr("file_browser.column_count_decrement") }
        public static var columnCountIncrement: String { tr("file_browser.column_count_increment") }
        public static var jumpToLastViewed: String { tr("file_browser.jump_to_last_viewed") }
        public static var ratingFeature: String { tr("file_browser.rating_feature") }
        public static var ratingFilterOff: String { tr("file_browser.rating_filter_off") }
        public static var ratingFilterStars: String { tr("file_browser.rating_filter_stars") }
        public static var ratingFilterComparison: String { tr("file_browser.rating_filter_comparison") }
        public static var ratingFilterAtLeast: String { tr("file_browser.rating_filter_at_least") }
        public static var ratingFilterAtMost: String { tr("file_browser.rating_filter_at_most") }
        public static var ratingFilterExactly: String { tr("file_browser.rating_filter_exactly") }

        public static func ratingFilterStarValue(_ stars: Int) -> String {
            tr("file_browser.rating_filter_star_value", stars)
        }

        public static func columnCountValue(_ count: Int) -> String {
            tr("file_browser.column_count_value", count)
        }

        public static func sectionTitleWithCount(_ title: String, _ count: Int) -> String {
            tr("file_browser.section_title_with_count", title, count)
        }

        public enum EmptyState {
            public static var noFolder: String { tr("file_browser.empty_state.no_folder") }
            public static var loading: String { tr("file_browser.empty_state.loading") }
            public static var noPhotos: String { tr("file_browser.empty_state.no_photos") }
        }
    }

    // MARK: - PhotoViewer

    public enum PhotoViewer {
        public static var saveIdle: String { tr("photo_viewer.save_idle") }
        public static var saveSaving: String { tr("photo_viewer.save_saving") }
        public static var saveCompleted: String { tr("photo_viewer.save_completed") }
        public static var saveFailed: String { tr("photo_viewer.save_failed") }
        public static var exifFNumberLabel: String { tr("photo_viewer.exif_f_number_label") }
        public static var exifFocalLengthLabel: String { tr("photo_viewer.exif_focal_length_label") }
        public static var exifFlashFiredLabel: String { tr("photo_viewer.exif_flash_fired_label") }
    }

    // MARK: - 現在の言語

    /// アプリが対応する言語（英語・日本語のみ）から解決される現在のLocale。
    /// 端末の言語設定に対応言語がなければ英語にフォールバックする。
    public static var currentLocale: Locale {
        Locale(identifier: Bundle.module.preferredLocalizations.first ?? "en")
    }

    // MARK: - Private

    private static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, tableName: "Localizable", bundle: .module, comment: "")
        return args.isEmpty ? format : String(format: format, locale: currentLocale, arguments: args)
    }
}
