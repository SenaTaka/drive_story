import CoreLocation
import Foundation

/// レンダラ検証用のダミー。GPS 記録の実装前に絵を確定させるために置く。
enum SampleDrives {
    static let hakone = DriveStory(
        title: "Hakone\nMorning Drive",
        distanceMeters: 86_400,
        duration: 2 * 3600 + 8 * 60,
        date: date(2026, 8, 28),
        stops: ["Hakone", "Ashinoko", "Turnpike"],
        tags: [.scenic, .curves, .earlyMorning],
        route: RouteOutline(coordinates: loop(around: .init(latitude: 35.232, longitude: 139.026), radius: 0.06, wobble: 0.10)),
        photos: [
            StoryPhoto(position: 0.18, caption: "Turnpike", placeholder: .dawn),
            StoryPhoto(position: 0.52, caption: "Lake Ashinoko", placeholder: .day),
            StoryPhoto(position: 0.81, caption: "Togenda", placeholder: .day)
        ],
        scenic: 5,
        curves: 4
    )

    static let chirihama = DriveStory(
        title: "Chirihama\nCoastal Drive",
        distanceMeters: 98_100,
        duration: 1 * 3600 + 45 * 60,
        date: date(2026, 8, 24),
        stops: ["Wakura Onsen", "Hakui Cliff", "Chirihama"],
        tags: [.oceanView, .scenic, .sunset],
        route: RouteOutline(coordinates: coastline()),
        photos: [
            StoryPhoto(position: 0.16, caption: "Wakura Bay", placeholder: .day),
            StoryPhoto(position: 0.48, caption: "Hakui Cliff", placeholder: .day),
            StoryPhoto(position: 0.86, caption: "Chirihama", placeholder: .dusk)
        ],
        scenic: 5,
        bestTime: "17:30"
    )

    static let venusLine = DriveStory(
        title: "Venus Line",
        subtitle: "Sky Drive",
        distanceMeters: 124_700,
        duration: 3 * 3600 + 12 * 60,
        date: date(2026, 8, 17),
        stops: ["Kurumayama", "Utsukushigahara", "Shirakaba"],
        tags: [.highland, .scenic, .curves],
        route: RouteOutline(coordinates: loop(around: .init(latitude: 36.106, longitude: 138.187), radius: 0.09, wobble: 0.16)),
        photos: [StoryPhoto(position: 0.4, caption: "Kurumayama", placeholder: .dawn)],
        scenic: 5,
        curves: 5
    )

    static let tokyoNight = DriveStory(
        title: "Tokyo\nNight Loop",
        distanceMeters: 57_300,
        duration: 1 * 3600 + 26 * 60,
        date: date(2026, 8, 26),
        stops: ["Shuto Expressway", "Odaiba", "Rainbow Bridge"],
        tags: [.nightView, .cityDrive],
        route: RouteOutline(coordinates: loop(around: .init(latitude: 35.660, longitude: 139.760), radius: 0.05, wobble: 0.06)),
        photos: [],
        bestTime: "22:00"
    )

    static let all: [DriveStory] = [hakone, chirihama, venusLine, tokyoNight]

    // MARK: - 形の生成

    private static func loop(
        around center: CLLocationCoordinate2D,
        radius: Double,
        wobble: Double
    ) -> [CLLocationCoordinate2D] {
        // 峠道らしい形にするため、低い周波数だけを重ねる。
        // 高周波のジッタを足すと GPS ノイズのような棘になり、道に見えない。
        (0...240).map { step in
            let t = Double(step) / 240 * 2 * .pi
            let r = radius * (1 + 0.26 * sin(t * 2 + 0.6) + 0.13 * cos(t * 3) + wobble * sin(t * 5))
            return CLLocationCoordinate2D(
                latitude: center.latitude + r * sin(t),
                longitude: center.longitude + r * cos(t) * 1.2
            )
        }
    }

    private static func coastline() -> [CLLocationCoordinate2D] {
        (0...180).map { step in
            let t = Double(step) / 180
            let lat = 37.10 - t * 0.42
            let lon = 136.94 - t * 0.13 + 0.020 * sin(t * 5.5) + 0.008 * sin(t * 2.2)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: year, month: month, day: day, hour: 9)) ?? Date()
    }
}
