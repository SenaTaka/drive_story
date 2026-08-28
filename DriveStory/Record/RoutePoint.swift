import CoreLocation
import Foundation

/// 走行軌跡の 1 点。記録用の生データで、描画用に畳んだ `RouteOutline` とは別物。
///
/// `../car_ui` の `TrackPoint` からの移植。あちらは OBD 回転数を持つが、
/// このアプリには車両データが無いので `rpm` を落としてある。
struct RoutePoint: Identifiable, Hashable {
    let id: Int
    let time: Date
    let coordinate: CLLocationCoordinate2D
    /// GPS 由来の速度。取れないことがあるので optional。
    let speedKPH: Double?
}

// CLLocationCoordinate2D が Codable ではないので緯度経度に分解して符号化する。
extension RoutePoint: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, time, lat, lon, speedKPH
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        time = try c.decode(Date.self, forKey: .time)
        coordinate = CLLocationCoordinate2D(
            latitude: try c.decode(Double.self, forKey: .lat),
            longitude: try c.decode(Double.self, forKey: .lon)
        )
        speedKPH = try c.decodeIfPresent(Double.self, forKey: .speedKPH)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(time, forKey: .time)
        try c.encode(coordinate.latitude, forKey: .lat)
        try c.encode(coordinate.longitude, forKey: .lon)
        try c.encodeIfPresent(speedKPH, forKey: .speedKPH)
    }
}

extension RoutePoint {
    static func == (lhs: RoutePoint, rhs: RoutePoint) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Array where Element == RoutePoint {
    /// 隣り合う点の距離を足した経路長（m）。
    var pathLengthMeters: Double {
        guard count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<count {
            total += CLLocation(from: self[i - 1]).distance(from: CLLocation(from: self[i]))
        }
        return total
    }

    /// 先頭からの累積距離を経路長で割った 0.0〜1.0。写真の位置算出に使う。
    ///
    /// `RouteOutline.point(atFraction:)` が経路長パラメータなので、
    /// 点数比ではなくこちらで揃えないと写真ピンがずれる。
    var cumulativeFractions: [Double] {
        guard count > 1 else { return map { _ in 0 } }
        var acc: [Double] = [0]
        var total: Double = 0
        for i in 1..<count {
            total += CLLocation(from: self[i - 1]).distance(from: CLLocation(from: self[i]))
            acc.append(total)
        }
        guard total > 0 else { return acc }
        return acc.map { $0 / total }
    }
}

extension CLLocation {
    convenience init(from point: RoutePoint) {
        self.init(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
    }
}
