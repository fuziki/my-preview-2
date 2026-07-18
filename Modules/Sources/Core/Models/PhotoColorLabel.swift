import Foundation
import Resources
#if canImport(UIKit)
import UIKit
#endif

// MARK: - PhotoColorLabel

/// 写真に1つ設定できるカラーラベル
public enum PhotoColorLabel: String, CaseIterable, Hashable, Sendable {
    case green
    case yellow
    case blue
    case pink
    case red
    case white
}

// MARK: - フィルタ選択集合の永続化用文字列表現

public extension Set where Element == PhotoColorLabel {
    /// "green,red" 形式の文字列表現（CaseIterableの定義順で並べる）
    var colorLabelFilterRawValue: String {
        PhotoColorLabel.allCases.filter(contains).map(\.rawValue).joined(separator: ",")
    }

    /// "green,red" 形式の文字列から復元する（不正な要素は無視する）
    init(colorLabelFilterRawValue: String) {
        self = Set(
            colorLabelFilterRawValue
                .split(separator: ",")
                .compactMap { PhotoColorLabel(rawValue: String($0)) }
        )
    }
}

// MARK: - 表示色

#if canImport(UIKit)
public extension PhotoColorLabel {
    /// 表示用のUIColor
    var uiColor: UIColor {
        switch self {
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .blue: return .systemBlue
        case .pink: return .customPink
        case .red: return .systemRed
        case .white: return .white
        }
    }
}
#endif
