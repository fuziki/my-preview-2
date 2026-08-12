import Foundation
import SwiftData

/// 写真URLごとのカラーラベルを保持する。ラベルなしはデフォルトでありレコードなしで表現する。
public protocol ColorLabelStoreProtocol {
    func label(for url: URL) -> PhotoColorLabel?
    func setLabel(_ label: PhotoColorLabel?, for url: URL)
    func allLabels() -> [URL: PhotoColorLabel]
    func removeAll()
}

/// カラーラベルの永続化レコード。SwiftDataで管理する
@Model
public final class ColorLabelRecord {
    public var urlString: String
    public var labelRawValue: String

    public init(urlString: String, labelRawValue: String) {
        self.urlString = urlString
        self.labelRawValue = labelRawValue
    }
}

public final class ColorLabelStore: ColorLabelStoreProtocol {
    private let modelContext: ModelContext

    public init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
    }

    /// 本番用のModelContainerを生成する。永続化ストアの初期化に失敗した場合はインメモリで動作を継続する
    public static func makeDefaultModelContainer() -> ModelContainer {
        let schema = Schema([ColorLabelRecord.self])
        do {
            // 他ストアの既定ストアファイルと衝突しないよう名前付きストアに保存する
            return try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration("ColorLabel", schema: schema)]
            )
        } catch {
            return try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
    }

    public func label(for url: URL) -> PhotoColorLabel? {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<ColorLabelRecord>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        guard let rawValue = try? modelContext.fetch(descriptor).first?.labelRawValue else { return nil }
        return PhotoColorLabel(rawValue: rawValue)
    }

    public func setLabel(_ label: PhotoColorLabel?, for url: URL) {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<ColorLabelRecord>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        let existing = try? modelContext.fetch(descriptor).first
        if let label {
            if let existing {
                existing.labelRawValue = label.rawValue
            } else {
                modelContext.insert(ColorLabelRecord(urlString: urlString, labelRawValue: label.rawValue))
            }
        } else {
            // ラベルなしはデフォルトなのでレコード自体を削除する
            if let existing { modelContext.delete(existing) }
        }
        try? modelContext.save()
    }

    public func allLabels() -> [URL: PhotoColorLabel] {
        let records = (try? modelContext.fetch(FetchDescriptor<ColorLabelRecord>())) ?? []
        var result: [URL: PhotoColorLabel] = [:]
        for record in records {
            if let url = URL(string: record.urlString),
               let label = PhotoColorLabel(rawValue: record.labelRawValue) {
                result[url] = label
            }
        }
        return result
    }

    public func removeAll() {
        try? modelContext.delete(model: ColorLabelRecord.self)
        try? modelContext.save()
    }
}
