// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Modules",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Resources", targets: ["Resources"]),
        .library(name: "Localization", targets: ["Localization"]),
        .library(name: "FileBrowser", targets: ["FileBrowser"]),
        .library(name: "PhotoViewer", targets: ["PhotoViewer"]),
        .library(name: "ToastKit", targets: ["ToastKit"]),
        .library(name: "ImagePiPKit", targets: ["ImagePiPKit"]),
        .library(name: "CornerDotKit", targets: ["CornerDotKit"]),
        .library(name: "Mocks", targets: ["Mocks"]),
        .library(name: "AppMain", targets: ["AppMain"]),
    ],
    targets: [
        // アセット（カラー等）のタイプセーフアクセサモジュール
        .target(
            name: "Resources",
            path: "Sources/Core/Resources",
            resources: [.process("Resources")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // 共有サービス・モデル層
        .target(
            name: "Core",
            dependencies: ["Resources"],
            path: "Sources/Core/Core",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // 多言語対応のタイプセーフ文言モジュール（en/jaのみ対応、デフォルトはen）
        .target(
            name: "Localization",
            path: "Sources/Core/Localization",
            resources: [.process("Resources")]
        ),
        // ファイルブラウザー機能モジュール（Core / Localizationに依存）
        .target(
            name: "FileBrowser",
            dependencies: ["Core", "Localization"],
            path: "Sources/Features/FileBrowser",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // トースト通知UI（UIKit / SwiftUI のみに依存）
        .target(
            name: "ToastKit",
            path: "Sources/Kits/ToastKit",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // 静止画のPicture in Picture表示を扱う汎用エンジン（依存なし、UIKit/AVKitのみ使用）
        .target(
            name: "ImagePiPKit",
            path: "Sources/Kits/ImagePiPKit",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // 右上に青い点を表示しON/OFFをフェードで示す汎用オーバーレイ（依存なし、UIKitのみ使用）
        .target(
            name: "CornerDotKit",
            path: "Sources/Kits/CornerDotKit",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // フォトビューアー機能モジュール（Core / ToastKit / Localization / ImagePiPKitに依存）
        .target(
            name: "PhotoViewer",
            dependencies: ["Core", "ToastKit", "Localization", "ImagePiPKit"],
            path: "Sources/Features/PhotoViewer",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // シミュレータビルド用のモックサービス（Coreに依存）
        .target(
            name: "Mocks",
            dependencies: ["Core"],
            path: "Sources/Core/Mocks",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // アプリエントリーポイント（全モジュールに依存）
        .target(
            name: "AppMain",
            dependencies: ["Core", "FileBrowser", "PhotoViewer", "ToastKit", "CornerDotKit", "Mocks"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),

        // MARK: - テストターゲット

        // テスト用モックサービス（Coreに依存、複数のテストターゲットで共有）
        .target(
            name: "MocksForTest",
            dependencies: ["Core"],
            path: "Tests/Core/MocksForTest",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // Coreの各サービス・ストアのユニットテスト
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/Core/CoreTests",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // FileBrowserViewModelのユニットテスト
        .testTarget(
            name: "FileBrowserTests",
            dependencies: ["FileBrowser", "MocksForTest"],
            path: "Tests/Features/FileBrowserTests",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // PhotoViewerViewModelのユニットテスト
        // SwiftUI: UIKitを経由してSwiftUI.AttributedStringのシンボルが参照されるためリンクが必要
        .testTarget(
            name: "PhotoViewerTests",
            dependencies: ["PhotoViewer", "MocksForTest"],
            path: "Tests/Features/PhotoViewerTests",
            swiftSettings: [.defaultIsolation(MainActor.self)],
            linkerSettings: [.linkedFramework("SwiftUI", .when(platforms: [.iOS]))]
        ),
    ]
)
