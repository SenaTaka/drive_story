import CoreLocation
import Foundation

/// Story に描くための「ルートの形」。地図タイルは一切使わない。
///
/// タイル画像を焼いて SNS に配ると帰属表示・再配布の規約に触れるうえ、
/// 生活道路や店名まで写ってしまう。形だけを自前で描けば両方消える。
struct RouteOutline {
    /// 平面に落として単位正方形へ収めた点列(縦横比は保つ)。原点は左上、y は下向き。
    let points: [CGPoint]

    /// 経路長で正規化した累積位置。points と同じ個数。
    private let cumulative: [Double]

    init(coordinates: [CLLocationCoordinate2D], tolerance: Double? = nil) {
        let projected = RouteOutline.project(coordinates)
        let simplified = RouteOutline.simplify(
            projected,
            tolerance: tolerance ?? RouteOutline.adaptiveTolerance(projected)
        )
        let fitted = RouteOutline.fitToUnitBox(simplified)
        points = fitted
        cumulative = RouteOutline.cumulativeLengths(fitted)
    }

    init(unitPoints: [CGPoint]) {
        points = unitPoints
        cumulative = RouteOutline.cumulativeLengths(unitPoints)
    }

    /// 経路の 0.0〜1.0 の位置にあたる点(写真ピンの座標に使う)。
    func point(atFraction fraction: Double) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        let target = min(max(fraction, 0), 1)
        guard let index = cumulative.firstIndex(where: { $0 >= target }), index > 0 else {
            return points[0]
        }
        let span = cumulative[index] - cumulative[index - 1]
        let t = span > 0 ? (target - cumulative[index - 1]) / span : 0
        let a = points[index - 1]
        let b = points[index]
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    var start: CGPoint { points.first ?? .zero }
    var goal: CGPoint { points.last ?? .zero }

    /// 簡略化の許容誤差。絶対値で固定すると短いドライブが棒になる。
    ///
    /// 4.7km の街乗りを 0.0015 度(約 165m)で間引いたら 3 点まで潰れて、
    /// ルートが「く」の字にしかならなかった(2026-08-29 実測)。
    /// 経路の広がりに対する比で決めつつ、長距離では従来値を上限にする
    /// (上限を外すと `SampleDrives` の決定稿ビジュアルが変わってしまう)。
    static func adaptiveTolerance(_ projected: [CGPoint]) -> Double {
        guard projected.count > 1 else { return 0 }
        let xs = projected.map(\.x), ys = projected.map(\.y)
        let spanX = (xs.max() ?? 0) - (xs.min() ?? 0)
        let spanY = (ys.max() ?? 0) - (ys.min() ?? 0)
        return min(max(spanX, spanY) * 0.0125, 0.0015)
    }

    // MARK: - 変換

    /// 緯度経度を等距離に近い平面へ。経度は緯度で縮むので cos を掛ける。
    private static func project(_ coordinates: [CLLocationCoordinate2D]) -> [CGPoint] {
        guard !coordinates.isEmpty else { return [] }
        let meanLat = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let k = cos(meanLat * .pi / 180)
        return coordinates.map { CGPoint(x: $0.longitude * k, y: -$0.latitude) }
    }

    /// 縦横比を保ったまま単位正方形の中央へ収める。
    private static func fitToUnitBox(_ raw: [CGPoint]) -> [CGPoint] {
        guard raw.count > 1 else { return raw.isEmpty ? [] : [CGPoint(x: 0.5, y: 0.5)] }
        let xs = raw.map(\.x), ys = raw.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let width = maxX - minX, height = maxY - minY
        let span = max(width, height)
        guard span > 0 else { return raw.map { _ in CGPoint(x: 0.5, y: 0.5) } }
        let offsetX = (span - width) / 2
        let offsetY = (span - height) / 2
        return raw.map {
            CGPoint(x: ($0.x - minX + offsetX) / span, y: ($0.y - minY + offsetY) / span)
        }
    }

    private static func cumulativeLengths(_ points: [CGPoint]) -> [Double] {
        guard points.count > 1 else { return points.map { _ in 0 } }
        var lengths: [Double] = [0]
        var total: Double = 0
        for i in 1..<points.count {
            total += hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)
            lengths.append(total)
        }
        guard total > 0 else { return lengths }
        return lengths.map { $0 / total }
    }

    // MARK: - Douglas-Peucker

    /// 走行ログをそのまま描くと点が多すぎるので間引く。形は保つ。
    static func simplify(_ points: [CGPoint], tolerance: Double) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack: [(Int, Int)] = [(0, points.count - 1)]

        while let (first, last) = stack.popLast() {
            guard last > first + 1 else { continue }
            var maxDistance = 0.0
            var maxIndex = first
            for i in (first + 1)..<last {
                let d = perpendicularDistance(points[i], from: points[first], to: points[last])
                if d > maxDistance {
                    maxDistance = d
                    maxIndex = i
                }
            }
            if maxDistance > tolerance {
                keep[maxIndex] = true
                stack.append((first, maxIndex))
                stack.append((maxIndex, last))
            }
        }
        return zip(points, keep).compactMap { $1 ? $0 : nil }
    }

    private static func perpendicularDistance(_ p: CGPoint, from a: CGPoint, to b: CGPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        if dx == 0 && dy == 0 { return hypot(p.x - a.x, p.y - a.y) }
        let t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)
        let clamped = min(max(t, 0), 1)
        return hypot(p.x - (a.x + clamped * dx), p.y - (a.y + clamped * dy))
    }
}
