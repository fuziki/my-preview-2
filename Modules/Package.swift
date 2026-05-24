// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Modules",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "FileBrowser", targets: ["FileBrowser"]),
        .library(name: "PhotoViewer", targets: ["PhotoViewer"]),
        .library(name: "AppMain", targets: ["AppMain"]),
    ],
    targets: [
        // 共有サービス・モデル層
        .target(
            name: "Core",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // ファイルブラウザー機能モジュール（Coreに依存）
        .target(
            name: "FileBrowser",
            dependencies: ["Core"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // フォトビューアー機能モジュール（Coreに依存）
        .target(
            name: "PhotoViewer",
            dependencies: ["Core"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // アプリエントリーポイント（全モジュールに依存）
        .target(
            name: "AppMain",
            dependencies: ["Core", "FileBrowser", "PhotoViewer"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
