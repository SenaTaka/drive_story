import CoreLocation
import Foundation

/// 走った場所の名前を決める。「どこを走ったか」がこのアプリの主語なので、
/// 地名が入らない Story は Strava のステッカーと同じところに落ちる。
enum PlaceNamer {
    struct Naming {
        var title: String
        var stops: [String]
    }

    /// 地名が取れなかったときの落とし先。オフラインでも Story は作れないと困る。
    static let fallbackTitle = "DRIVE"

    /// **マスク後**の点から地名を引く。生の始点を渡すと自宅の地名が出る。
    static func resolve(points: [RoutePoint], maskedRadius: Double) async -> Naming {
        let masked = RouteMask.masked(points, radius: maskedRadius)
        guard masked.count >= 2 else { return Naming(title: fallbackTitle, stops: []) }

        let samples = [masked[0], masked[masked.count / 2], masked[masked.count - 1]]
        var names: [String] = []
        for point in samples {
            if let name = await placeName(for: point.coordinate) {
                names.append(name)
            }
        }

        // 同じ地名が続くのは意味がないので畳む（周回だと 3 つとも同じになる）。
        var unique: [String] = []
        for name in names where unique.last != name {
            unique.append(name)
        }

        guard let title = unique.count >= 2 ? unique[unique.count / 2] : unique.first else {
            return Naming(title: fallbackTitle, stops: [])
        }
        return Naming(title: title, stops: unique)
    }

    private static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else { return nil }
        // locality（市区町村）を第一候補に。無い山間部では subAdministrativeArea や
        // administrativeArea（都道府県）まで落とす。
        return placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.name
    }
}
