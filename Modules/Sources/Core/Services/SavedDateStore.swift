import Foundation
import SwiftData

/// 写真URLごとの最終保存日時を保持する。フォトビューアーセッション間で共有される。
public protocol SavedDateStoreProtocol {
    func date(for url: URL) -> Date?
    func setDate(_ date: Date, for url: URL)
    func removeAll()
}

/// 保存日時の永続化レコード。SwiftDataで管理する
@Model
public final class SavedDateRecord {
    public var urlString: String
    public var date: Date

    public init(urlString: String, date: Date) {
        self.urlString = urlString
        self.date = date
    }
}

public final class SavedDateStore: SavedDateStoreProtocol {
    private let modelContext: ModelContext

    public init() {
        let schema = Schema([SavedDateRecord.self])
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)])
        } catch {
            // 永続化ストアの初期化に失敗した場合はインメモリで動作を継続する
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
        modelContext = ModelContext(container)
    }

    public func date(for url: URL) -> Date? {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<SavedDateRecord>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        return try? modelContext.fetch(descriptor).first?.date
    }

    public func setDate(_ date: Date, for url: URL) {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<SavedDateRecord>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.date = date
        } else {
            modelContext.insert(SavedDateRecord(urlString: urlString, date: date))
        }
        try? modelContext.save()
    }

    public func removeAll() {
        try? modelContext.delete(model: SavedDateRecord.self)
        try? modelContext.save()
    }
}
