import Foundation
import SwiftData

/// 写真URLごとのレーティング（星0〜5）を保持する。星0はデフォルトでありレコードなしで表現する。
public protocol PhotoRatingStoreProtocol {
    func rating(for url: URL) -> Int
    func setRating(_ rating: Int, for url: URL)
    func allRatings() -> [URL: Int]
    func removeAll()
}

/// レーティングの永続化レコード。SwiftDataで管理する
@Model
public final class PhotoRatingRecord {
    public var urlString: String
    public var rating: Int

    public init(urlString: String, rating: Int) {
        self.urlString = urlString
        self.rating = rating
    }
}

public final class PhotoRatingStore: PhotoRatingStoreProtocol {
    private let modelContext: ModelContext

    public init() {
        let schema = Schema([PhotoRatingRecord.self])
        let container: ModelContainer
        do {
            // SavedDateStoreの既定ストアファイルと衝突しないよう名前付きストアに保存する
            container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration("PhotoRating", schema: schema)]
            )
        } catch {
            // 永続化ストアの初期化に失敗した場合はインメモリで動作を継続する
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
        modelContext = ModelContext(container)
    }

    public func rating(for url: URL) -> Int {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<PhotoRatingRecord>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        return (try? modelContext.fetch(descriptor).first?.rating) ?? 0
    }

    public func setRating(_ rating: Int, for url: URL) {
        let urlString = url.absoluteString
        let descriptor = FetchDescriptor<PhotoRatingRecord>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        let existing = try? modelContext.fetch(descriptor).first
        if rating <= 0 {
            // 星0はデフォルトなのでレコード自体を削除する
            if let existing { modelContext.delete(existing) }
        } else if let existing {
            existing.rating = rating
        } else {
            modelContext.insert(PhotoRatingRecord(urlString: urlString, rating: rating))
        }
        try? modelContext.save()
    }

    public func allRatings() -> [URL: Int] {
        let records = (try? modelContext.fetch(FetchDescriptor<PhotoRatingRecord>())) ?? []
        var result: [URL: Int] = [:]
        for record in records {
            if let url = URL(string: record.urlString) {
                result[url] = record.rating
            }
        }
        return result
    }

    public func removeAll() {
        try? modelContext.delete(model: PhotoRatingRecord.self)
        try? modelContext.save()
    }
}
