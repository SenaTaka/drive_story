import CoreLocation
import MapKit
import SwiftUI

/// 実地図の上に軌跡と写真を並べる。**アプリの中で見るためだけの画面。**
///
/// SNS へ書き出す画像には地図タイルを焼かない（帰属表示・再配布の規約と、
/// 生活道路・店名が写るプライバシーの両方に触れる）。見るだけならその制約はない。
struct DriveMapScreen: View {
    let record: DriveRecord
    @EnvironmentObject private var cache: PhotoImageCache

    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: PhotoRef?

    /// 表示するのはマスク後の点。アプリ内でもスクショ流出があるので自宅は出さない。
    private var masked: [RoutePoint] {
        RouteMask.masked(record.points, radius: record.maskedRadius)
    }

    private var photos: [PhotoRef] { record.includedPhotos }

    var body: some View {
        Map(position: $camera) {
            ForEach(Array(RouteSegments.split(masked).enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.map(\.coordinate))
                    .stroke(
                        Color(red: 0.95, green: 0.30, blue: 0.34),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }

            ForEach(photos) { photo in
                if let coordinate = coordinate(for: photo) {
                    Annotation("", coordinate: coordinate) {
                        Button {
                            selected = photo
                        } label: {
                            PhotoThumb(image: cache.image(for: photo.assetLocalIdentifier))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .navigationTitle("地図")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fitCamera() }
        .sheet(item: $selected) { photo in
            PhotoDetail(photo: photo, image: cache.image(for: photo.assetLocalIdentifier))
        }
    }

    /// 写真自身の位置があればそれ。無ければ経路上の位置から引き当てる。
    private func coordinate(for photo: PhotoRef) -> CLLocationCoordinate2D? {
        if let coordinate = photo.coordinate { return coordinate }
        let points = masked
        guard !points.isEmpty else { return nil }
        let fractions = points.cumulativeFractions
        let index = fractions.firstIndex { $0 >= photo.position } ?? points.count - 1
        return points[index].coordinate
    }

    /// `.automatic` に任せると全国が映ることがある。点群の外接矩形に合わせる。
    private func fitCamera() {
        let coordinates = masked.map(\.coordinate)
        guard let first = coordinates.first else { return }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for c in coordinates {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        camera = .region(MKCoordinateRegion(center: center, span: span))
    }
}

/// 時間が飛んでいるところで線を切る。
///
/// トンネルや駐車で位置が途切れたとき、繋いでしまうと通っていない直線が引かれる。
/// `../car_ui` の軌跡描画で同じ問題に当たって入れた処理。
enum RouteSegments {
    static let gapSeconds: TimeInterval = 60

    static func split(_ points: [RoutePoint]) -> [[RoutePoint]] {
        guard !points.isEmpty else { return [] }
        var segments: [[RoutePoint]] = []
        var current: [RoutePoint] = [points[0]]
        for point in points.dropFirst() {
            if let last = current.last, point.time.timeIntervalSince(last.time) > gapSeconds {
                if current.count > 1 { segments.append(current) }
                current = [point]
            } else {
                current.append(point)
            }
        }
        if current.count > 1 { segments.append(current) }
        return segments
    }
}

private struct PhotoThumb: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.6)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 2.5))
        .shadow(radius: 3)
    }
}

private struct PhotoDetail: View {
    let photo: PhotoRef
    let image: UIImage?

    var body: some View {
        VStack(spacing: 12) {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color.gray.opacity(0.3)
            }
            Text(photo.creationDate.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if !photo.hasLocation {
                Text("位置情報なし（撮影時刻から推定）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .presentationDetents([.medium])
    }
}
