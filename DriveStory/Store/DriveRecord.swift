import CoreLocation
import Foundation

/// 走行 1 回の事実。永続する唯一の単位。
///
/// 絵の材料である `DriveStory` とは役割が別。あちらは `StoryBuilder` が
/// これから毎回組み立て直す使い捨ての構造体で、保存しない。
struct DriveRecord: Identifiable, Codable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date
    /// 記録した生の軌跡。マスク前の全量を持つ。
    var points: [RoutePoint]
    /// 積算距離（m）。マスク前の値で、走った事実そのもの。
    var distanceMeters: Double
    /// 出発・到着を伏せる半径（m）。生成時ではなく**記録時**に決める。
    /// あとから公開範囲を変えても一貫させるため。
    var maskedRadius: Double
    var title: String
    var stops: [String]
    /// 自動抽出した写真の全候補。採否は `isIncluded` で表す。
    var selectedPhotos: [PhotoRef]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        points: [RoutePoint],
        distanceMeters: Double,
        maskedRadius: Double = 500,
        title: String = "",
        stops: [String] = [],
        selectedPhotos: [PhotoRef] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.points = points
        self.distanceMeters = distanceMeters
        self.maskedRadius = maskedRadius
        self.title = title
        self.stops = stops
        self.selectedPhotos = selectedPhotos
    }

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    /// Story に載せる写真だけ。撮影時刻順。
    ///
    /// 経路上の位置ではなく撮影時刻で並べる。周回ルートでは位置が前後するので、
    /// 「どの順に撮ったか」の方が実際の体験に合う。
    var includedPhotos: [PhotoRef] {
        selectedPhotos.filter(\.isIncluded).sorted { $0.creationDate < $1.creationDate }
    }
}
