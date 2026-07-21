import Foundation
import Core

#if targetEnvironment(simulator)
/// シミュレータビルド用のFileSystemServiceモック。
/// 実フォルダを読まず、番号付きのモックFileItemを返す。
public final class MockFileSystemService: FileSystemServiceProtocol {
    public init() {}

    public func scanForJPEGs(in folderURL: URL) async -> [FileItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (1...24).map { index in
            // 6枚ごとに日付を1日ずつ過去にずらし、日付セクション分けを再現する
            let dayOffset = -((index - 1) / 6)
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)?
                .addingTimeInterval(TimeInterval(9 * 3600 + index * 60))
            return FileItem(
                url: URL(fileURLWithPath: "/mock/mock-\(index).jpg"),
                captureDate: date
            )
        }
    }
}
#endif
