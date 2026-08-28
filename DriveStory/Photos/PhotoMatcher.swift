import CoreLocation
import Foundation
import Photos

/// 突き合わせに必要な情報だけを取り出したもの。
///
/// `PHAsset` を直接受けると、写真権限が無い環境ではアルゴリズムを一切検証できない。
/// シミュレータでは `simctl privacy grant photos` が効かず notDetermined のままだった
/// （iOS 26.0 / 18.6 の両方で実測。TCC を直接書いても変わらず）。
/// PhotoKit を境界の向こうに置けば、判定そのものはどこでも確かめられる。
struct PhotoCandidate {
    var id: String
    var creationDate: Date
    var coordinate: CLLocationCoordinate2D?
}

extension PHAsset {
    var candidate: PhotoCandidate? {
        guard let creationDate else { return nil }
        return PhotoCandidate(
            id: localIdentifier,
            creationDate: creationDate,
            coordinate: location?.coordinate
        )
    }
}

/// 走行ログと写真を突き合わせる。純関数で、副作用は持たない。
///
/// このアプリの一番の売りは「40 枚から選ぶ作業が消える」こと。
/// つまりここの精度がそのままアプリの価値になる。
enum PhotoMatcher {
    /// 走行時刻の前後にこれだけ余裕を持たせる（走り出す直前・停めた直後の 1 枚を拾う）。
    static let timeMargin: TimeInterval = 120
    /// ルートからこれ以上離れた写真は走行と無関係とみなす。
    static let maxDistanceFromRoute: CLLocationDistance = 300

    /// 本番の入口。PHAsset を候補に写してから同じ判定に通す。
    static func match(record: DriveRecord, assets: [PHAsset]) -> [PhotoRef] {
        match(record: record, candidates: assets.compactMap(\.candidate))
    }

    static func match(record: DriveRecord, candidates: [PhotoCandidate]) -> [PhotoRef] {
        let masked = RouteMask.masked(record.points, radius: record.maskedRadius)
        guard masked.count >= 2 else { return [] }
        let fractions = masked.cumulativeFractions
        let window = DateInterval(
            start: record.startedAt.addingTimeInterval(-timeMargin),
            end: record.endedAt.addingTimeInterval(timeMargin)
        )

        return candidates.compactMap { candidate -> PhotoRef? in
            let shotAt = candidate.creationDate

            guard window.contains(shotAt) else {
                return PhotoRef(
                    assetLocalIdentifier: candidate.id,
                    creationDate: shotAt,
                    coordinate: candidate.coordinate,
                    position: 0,
                    isIncluded: false,
                    rejectReason: "走行時刻レンジ外"
                )
            }

            if let coordinate = candidate.coordinate {
                // 自宅で撮った写真が出るのが一番まずい。マスク圏内は無条件で外す。
                if RouteMask.isInsideMask(
                    coordinate, points: record.points, radius: record.maskedRadius
                ) {
                    return PhotoRef(
                        assetLocalIdentifier: candidate.id,
                        creationDate: shotAt,
                        coordinate: coordinate,
                        position: 0,
                        isIncluded: false,
                        rejectReason: "出発・到着のマスク圏内"
                    )
                }

                let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                var bestIndex = 0
                var bestDistance = Double.greatestFiniteMagnitude
                for (index, point) in masked.enumerated() {
                    let distance = target.distance(from: CLLocation(from: point))
                    if distance < bestDistance {
                        bestDistance = distance
                        bestIndex = index
                    }
                }

                guard bestDistance <= maxDistanceFromRoute else {
                    return PhotoRef(
                        assetLocalIdentifier: candidate.id,
                        creationDate: shotAt,
                        coordinate: coordinate,
                        position: 0,
                        isIncluded: false,
                        rejectReason: String(format: "ルートから %.0fm 離れている", bestDistance)
                    )
                }

                return PhotoRef(
                    assetLocalIdentifier: candidate.id,
                    creationDate: shotAt,
                    coordinate: coordinate,
                    position: fractions[bestIndex],
                    isIncluded: true,
                    rejectReason: nil
                )
            }

            // 位置がない写真（スクショ・位置サービス off）は撮影時刻で救う。
            // 時刻は必ずあるので、ここで捨てると惜しい 1 枚を落とす。
            return PhotoRef(
                assetLocalIdentifier: candidate.id,
                creationDate: shotAt,
                coordinate: nil,
                position: positionByTime(shotAt, points: masked, fractions: fractions),
                isIncluded: true,
                rejectReason: nil
            )
        }
    }

    /// 撮影時刻から経路上の位置を線形補間する。
    static func positionByTime(
        _ date: Date,
        points: [RoutePoint],
        fractions: [Double]
    ) -> Double {
        guard points.count >= 2 else { return 0 }
        if date <= points[0].time { return 0 }
        if date >= points[points.count - 1].time { return 1 }

        var low = 0
        var high = points.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if points[mid].time <= date { low = mid } else { high = mid }
        }
        let span = points[high].time.timeIntervalSince(points[low].time)
        guard span > 0 else { return fractions[low] }
        let t = date.timeIntervalSince(points[low].time) / span
        return fractions[low] + (fractions[high] - fractions[low]) * t
    }

    /// ピンが団子にならないよう、表示のときだけ位置を押し広げる。
    /// データ側の `position` は動かさない（実際に撮った場所が真）。
    static func spread(_ photos: [StoryPhoto], minimumGap: Double = 0.03) -> [StoryPhoto] {
        guard photos.count > 1 else { return photos }
        var sorted = photos.sorted { $0.position < $1.position }
        for i in 1..<sorted.count {
            let gap = sorted[i].position - sorted[i - 1].position
            if gap < minimumGap {
                sorted[i].position = min(1, sorted[i - 1].position + minimumGap)
            }
        }
        return sorted
    }
}
