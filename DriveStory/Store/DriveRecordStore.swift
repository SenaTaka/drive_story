import Combine
import Foundation

/// 履歴の保存先。SwiftData に差し替えたくなったときに呼び出し側を変えずに済むよう
/// 境界を切っておく。
@MainActor
protocol DriveRecordStoring: AnyObject {
    var records: [DriveRecord] { get }
    func save(_ record: DriveRecord)
    func delete(id: UUID)
    func record(id: UUID) -> DriveRecord?
}

/// 走行履歴を Application Support の JSON に持つ。
///
/// PRD は SwiftData と書いていたが JSON を採った（理由は `doc/PRD_MVP.md` §4）。
/// atomic write と復元は `../car_ui` の `TrackStore` で動いている形をそのまま使う。
@MainActor
final class DriveRecordStore: ObservableObject, DriveRecordStoring {
    @Published private(set) var records: [DriveRecord] = []

    /// 保存する上限。古いものから捨てる。
    private let maxRecords = 100

    init() {
        load()
    }

    nonisolated static var directory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DriveStory", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static var recordsURL: URL { directory.appendingPathComponent("records.json") }

    nonisolated static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }

    nonisolated static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }

    func save(_ record: DriveRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.insert(record, at: 0)
        }
        if records.count > maxRecords {
            records.removeLast(records.count - maxRecords)
        }
        persist()
    }

    func delete(id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    func record(id: UUID) -> DriveRecord? {
        records.first { $0.id == id }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.recordsURL),
              let restored = try? Self.decoder.decode([DriveRecord].self, from: data)
        else { return }
        records = restored
    }

    /// 書き込みはバックグラウンドで。軌跡は数千点あるので UI を待たせない。
    private func persist() {
        let snapshot = records
        Task.detached(priority: .utility) {
            guard let data = try? Self.encoder.encode(snapshot) else { return }
            try? data.write(to: Self.recordsURL, options: .atomic)
        }
    }
}
