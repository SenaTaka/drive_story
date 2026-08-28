import CoreLocation
import Foundation
import UIKit

/// 走行の事実（`DriveRecord`）から、絵の材料（`DriveStory`）を組み立てる。
///
/// ここが記録層と描画層の唯一の接点。描画側は「どこを隠すか」も
/// 「写真をどう選んだか」も知らないでいい。
@MainActor
enum StoryBuilder {
    /// `images` は `PhotoRef.assetLocalIdentifier` → 実画像。
    /// `ImageRenderer` は同期描画なので、焼く前に解決済みのものを渡す。
    static func story(from record: DriveRecord, images: [String: UIImage] = [:]) -> DriveStory {
        let masked = RouteMask.masked(record.points, radius: record.maskedRadius)
        let outline = RouteOutline(coordinates: masked.map(\.coordinate))
        // 並び順は撮影時刻（`includedPhotos` が保証）。
        // ピンが団子になるのは見た目の問題なので、表示位置だけ押し広げる。
        let photos = PhotoMatcher.spread(record.includedPhotos.map { ref in
            StoryPhoto(
                position: ref.position,
                caption: nil,
                placeholder: placeholder(for: ref.creationDate),
                assetLocalIdentifier: ref.assetLocalIdentifier,
                image: images[ref.assetLocalIdentifier]
            )
        })

        return DriveStory(
            id: record.id,
            title: record.title.isEmpty ? "DRIVE" : record.title,
            distanceMeters: record.distanceMeters,
            duration: record.duration,
            date: record.startedAt,
            stops: record.stops,
            tags: tags(for: record),
            route: outline,
            photos: photos
        )
    }

    /// 走った時間帯と距離からタグを推す。手で選ばせるほどの価値はない。
    static func tags(for record: DriveRecord) -> [DriveTag] {
        var result: [DriveTag] = []
        let hour = Calendar.current.component(.hour, from: record.startedAt)
        switch hour {
        case 4..<8: result.append(.earlyMorning)
        case 16..<19: result.append(.sunset)
        case 19..<24, 0..<4: result.append(.nightView)
        default: break
        }
        if record.distanceMeters >= 50_000 {
            result.append(.scenic)
        } else {
            result.append(.cityDrive)
        }
        if isCurvy(record.points) { result.append(.curves) }
        return result
    }

    /// 進行方向の変化量で「曲がりの多さ」を測る。
    /// 1km あたりの累積方位変化が 90 度を超えたら峠道とみなす。
    static func isCurvy(_ points: [RoutePoint]) -> Bool {
        guard points.count > 3 else { return false }
        var totalTurn: Double = 0
        var previousBearing: Double?
        for i in 1..<points.count {
            let bearing = self.bearing(from: points[i - 1].coordinate, to: points[i].coordinate)
            if let previousBearing {
                var delta = abs(bearing - previousBearing)
                if delta > 180 { delta = 360 - delta }
                totalTurn += delta
            }
            previousBearing = bearing
        }
        let km = points.pathLengthMeters / 1000
        guard km > 0.5 else { return false }
        return totalTurn / km > 90
    }

    private static func bearing(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    /// 実写が入る前の代替色。撮影時刻帯だけは分かっている。
    static func placeholder(for date: Date) -> PhotoPlaceholder {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<8: return .dawn
        case 8..<16: return .day
        case 16..<19: return .dusk
        default: return .night
        }
    }
}
