import CoreLocation
import Foundation

/// Story に載せる候補の写真 1 枚。永続するのはこちらで、実画像は持たない。
///
/// `UIImage` を JSON に入れるわけにはいかないので、識別子だけを保存して
/// 表示直前に `PhotoImageCache` が解決する。
struct PhotoRef: Identifiable, Codable, Hashable {
    /// `PHAsset.localIdentifier`。
    var assetLocalIdentifier: String
    var creationDate: Date
    /// 写真自身が持つ位置。スクショや位置サービス off の写真では nil。
    var coordinate: CLLocationCoordinate2D?
    /// 経路上の位置 0.0（START）〜1.0（GOAL）。
    var position: Double
    /// Story に載せるか。自動抽出の結果をユーザーがトグルで覆せる。
    var isIncluded: Bool
    /// 自動抽出で外したときの理由。空なら採用。
    var rejectReason: String?

    var id: String { assetLocalIdentifier }
    var hasLocation: Bool { coordinate != nil }
}

extension PhotoRef {
    private enum CodingKeys: String, CodingKey {
        case assetLocalIdentifier, creationDate, lat, lon, position, isIncluded, rejectReason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        assetLocalIdentifier = try c.decode(String.self, forKey: .assetLocalIdentifier)
        creationDate = try c.decode(Date.self, forKey: .creationDate)
        if let lat = try c.decodeIfPresent(Double.self, forKey: .lat),
           let lon = try c.decodeIfPresent(Double.self, forKey: .lon) {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            coordinate = nil
        }
        position = try c.decode(Double.self, forKey: .position)
        isIncluded = try c.decode(Bool.self, forKey: .isIncluded)
        rejectReason = try c.decodeIfPresent(String.self, forKey: .rejectReason)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(assetLocalIdentifier, forKey: .assetLocalIdentifier)
        try c.encode(creationDate, forKey: .creationDate)
        try c.encodeIfPresent(coordinate?.latitude, forKey: .lat)
        try c.encodeIfPresent(coordinate?.longitude, forKey: .lon)
        try c.encode(position, forKey: .position)
        try c.encode(isIncluded, forKey: .isIncluded)
        try c.encodeIfPresent(rejectReason, forKey: .rejectReason)
    }

    static func == (lhs: PhotoRef, rhs: PhotoRef) -> Bool {
        lhs.assetLocalIdentifier == rhs.assetLocalIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(assetLocalIdentifier)
    }
}
