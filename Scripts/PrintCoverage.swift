// `xcrun xccov view --report --json`の出力を標準入力から受け取り、
// ViewModels/Servicesディレクトリ配下のファイルだけに絞ってカバレッジを表示する。
//
// 同一ソースファイルは本体ターゲットとテストターゲットの両方に重複して
// レポートされる（値は同一）ため、パスで重複排除してから集計する。
//
// 実行: xcrun xccov view --report --json result.xcresult | swift Scripts/PrintCoverage.swift

import Foundation

struct CoverageReport: Decodable {
    let targets: [Target]
}

struct Target: Decodable {
    let files: [CoverageFile]?
}

struct CoverageFile: Decodable {
    let path: String
    let name: String
    let coveredLines: Int
    let executableLines: Int
}

let pathMarkers = ["/ViewModels/", "/Services/"]

let inputData = FileHandle.standardInput.readDataToEndOfFile()

let report: CoverageReport
do {
    report = try JSONDecoder().decode(CoverageReport.self, from: inputData)
} catch {
    FileHandle.standardError.write("xccovのJSONデコードに失敗しました: \(error)\n".data(using: .utf8)!)
    exit(1)
}

var uniqueFilesByPath: [String: CoverageFile] = [:]
for target in report.targets {
    for file in target.files ?? [] where pathMarkers.contains(where: { file.path.contains($0) }) {
        uniqueFilesByPath[file.path] = file
    }
}

guard !uniqueFilesByPath.isEmpty else {
    print("対象ファイルが見つかりませんでした（ViewModels/Servicesディレクトリ配下）")
    exit(0)
}

let files = uniqueFilesByPath.values.sorted { $0.path < $1.path }
let nameWidth = files.map(\.name.count).max() ?? 0

func printRow(name: String, covered: Int, executable: Int) {
    let percent = executable > 0 ? Double(covered) / Double(executable) * 100 : 0
    let paddedName = name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
    print(String(format: "%@  %6.1f%%  (%d/%d lines)", paddedName, percent, covered, executable))
}

var totalCovered = 0
var totalExecutable = 0
for file in files {
    totalCovered += file.coveredLines
    totalExecutable += file.executableLines
    printRow(name: file.name, covered: file.coveredLines, executable: file.executableLines)
}

print(String(repeating: "-", count: nameWidth + 26))
printRow(name: "Overall", covered: totalCovered, executable: totalExecutable)
