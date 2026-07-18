// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Modules",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Localization", targets: ["Localization"]),
        .library(name: "FileBrowser", targets: ["FileBrowser"]),
        .library(name: "PhotoViewer", targets: ["PhotoViewer"]),
        .library(name: "ToastKit", targets: ["ToastKit"]),
        .library(name: "Mocks", targets: ["Mocks"]),
        .library(name: "AppMain", targets: ["AppMain"]),
    ],
    targets: [
        // 共有サービス・モデル層
        .target(
            name: "Core",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // 多言語対応のタイプセーフ文言モジュール（en/jaのみ対応、デフォルトはen）
        .target(
            name: "Localization",
            resources: [.process("Resources")]
        ),
        // ファイルブラウザー機能モジュール（Core / Localizationに依存）
        .target(
            name: "FileBrowser",
            dependencies: ["Core", "Localization"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // トースト通知UI（UIKit / SwiftUI のみに依存）
        .target(
            name: "ToastKit",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // フォトビューアー機能モジュール（Core / ToastKit / Localizationに依存）
        .target(
            name: "PhotoViewer",
            dependencies: ["Core", "ToastKit", "Localization"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // シミュレータビルド用のモックサービス（Coreに依存）
        .target(
            name: "Mocks",
            dependencies: ["Core"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // アプリエントリーポイント（全モジュールに依存）
        .target(
            name: "AppMain",
            dependencies: ["Core", "FileBrowser", "PhotoViewer", "ToastKit", "Mocks"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        // MARK: - テストターゲット

        // FileBrowserViewModelのユニットテスト
        .testTarget(
            name: "FileBrowserTests",
            dependencies: ["FileBrowser"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // PhotoViewerViewModelのユニットテスト
        // SwiftUI: UIKitを経由してSwiftUI.AttributedStringのシンボルが参照されるためリンクが必要
        .testTarget(
            name: "PhotoViewerTests",
            dependencies: ["PhotoViewer"],
            swiftSettings: [.defaultIsolation(MainActor.self)],
            linkerSettings: [.linkedFramework("SwiftUI", .when(platforms: [.iOS]))]
        ),
    ]
)
