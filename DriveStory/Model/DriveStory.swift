import CoreLocation
import Foundation

/// Story 1 枚を描くのに必要な材料。走行ログ本体ではなく、描画用に畳んだもの。
struct DriveStory: Identifiable {
    let id: UUID
    var title: String
    var subtitle: String?
    var distanceMeters: Double
    var duration: TimeInterval
    var date: Date
    /// START / GOAL の間に置く経由地名。
    var stops: [String]
    var tags: [DriveTag]
    var route: RouteOutline
    var photos: [StoryPhoto]
    var scenic: Int?
    var curves: Int?
    /// 「走るなら何時」。nil なら Story に出さない。
    var bestTime: String?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        distanceMeters: Double,
        duration: TimeInterval,
        date: Date,
        stops: [String] = [],
        tags: [DriveTag] = [],
        route: RouteOutline,
        photos: [StoryPhoto] = [],
        scenic: Int? = nil,
        curves: Int? = nil,
        bestTime: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.distanceMeters = distanceMeters
        self.duration = duration
        self.date = date
        self.stops = stops
        self.tags = tags
        self.route = route
        self.photos = photos
        self.scenic = scenic
        self.curves = curves
        self.bestTime = bestTime
    }

    var distanceText: String {
        String(format: "%.1f", distanceMeters / 1000)
    }

    var durationHours: Int { Int(duration) / 3600 }
    var durationMinutes: Int { (Int(duration) % 3600) / 60 }
}

struct DriveTag: Identifiable, Hashable {
    let id = UUID()
    var label: String
    var symbol: String

    static let scenic = DriveTag(label: "SCENIC", symbol: "mountain.2.fill")
    static let oceanView = DriveTag(label: "OCEAN VIEW", symbol: "water.waves")
    static let nightView = DriveTag(label: "NIGHT VIEW", symbol: "moon.stars.fill")
    static let sunset = DriveTag(label: "SUNSET", symbol: "sun.horizon.fill")
    static let highland = DriveTag(label: "HIGHLAND", symbol: "mountain.2")
    static let cityDrive = DriveTag(label: "CITY DRIVE", symbol: "car.fill")
    static let earlyMorning = DriveTag(label: "EARLY MORNING", symbol: "sunrise.fill")
    static let curves = DriveTag(label: "CURVES", symbol: "road.lanes.curved.right")
}

/// ルート上に置く 1 枚。`position` は経路の 0.0(START)〜1.0(GOAL)。
struct StoryPhoto: Identifiable {
    let id = UUID()
    var position: Double
    var caption: String?
    /// MVP のこの段階ではダミー。写真マッピング実装後に PHAsset 由来の画像が入る。
    var placeholder: PhotoPlaceholder
}

/// 実写が入る前の代替。撮影時刻帯だけ分かっているのでその空の色で置く。
enum PhotoPlaceholder: CaseIterable {
    case dawn, day, dusk, night
}
