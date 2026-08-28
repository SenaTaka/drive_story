import CoreLocation
import Foundation

/// 出発・到着の周辺を伏せる。線の端から自宅を推定させないため。
///
/// 削るのは `RoutePoint` の配列で、`RouteOutline` を作る**前**。
/// 描画側に「ここは隠す」という知識を持たせないで済む。
enum RouteMask {
    /// 先頭と末尾の `radius` 以内を落とす。
    ///
    /// 往路で半径を出たあとは再度削らない（周回で自宅前を通っても線は切らない）。
    /// 両端が食い合って 2 点未満になったら元の配列を返す。
    /// 近所を 1km 走っただけのときに線が丸ごと消える方が困る。
    static func masked(_ points: [RoutePoint], radius: CLLocationDistance) -> [RoutePoint] {
        guard points.count > 2, radius > 0 else { return points }

        let start = CLLocation(from: points[0])
        var head = 0
        while head < points.count, start.distance(from: CLLocation(from: points[head])) < radius {
            head += 1
        }

        let goal = CLLocation(from: points[points.count - 1])
        var tail = points.count - 1
        while tail >= 0, goal.distance(from: CLLocation(from: points[tail])) < radius {
            tail -= 1
        }

        guard head <= tail, tail - head + 1 >= 2 else { return points }
        return Array(points[head...tail])
    }

    /// ある地点がマスク圏内か。写真をルートに載せてよいかの判定に使う。
    static func isInsideMask(
        _ coordinate: CLLocationCoordinate2D,
        points: [RoutePoint],
        radius: CLLocationDistance
    ) -> Bool {
        guard let first = points.first, let last = points.last, radius > 0 else { return false }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return target.distance(from: CLLocation(from: first)) < radius
            || target.distance(from: CLLocation(from: last)) < radius
    }
}
