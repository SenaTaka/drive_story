import CoreLocation
import Photos
import UIKit

/// `requestImage` は複数回コールバックする。どれを返したかを覚えておく箱。
private final class ImageRequestState: @unchecked Sendable {
    var resumed = false
    var latest: UIImage?
}

/// 写真ライブラリへの唯一の窓口。PhotoKit をここより外に漏らさない。
enum PhotoLibraryService {
    @discardableResult
    static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// 診断用。denied なのか notDetermined なのかで対処が変わる。
    static var authorizationLabel: String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .limited: return "limited"
        @unknown default: return "unknown"
        }
    }

    static var isAuthorized: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// 走った日に撮った写真。
    ///
    /// 走行時刻ちょうどで絞らず 1 日ぶん取るのは、「なぜ外れたか」を
    /// 出せるようにするため。時刻で外れた写真が候補一覧に出てこないと、
    /// 抽出が動いていないのか写真が無いのかが区別できない。
    static func assets(onDayOf record: DriveRecord) -> [PHAsset] {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: record.startedAt)
        let to = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: record.endedAt))
            ?? record.endedAt

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
            PHAssetMediaType.image.rawValue, from as NSDate, to as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        var found: [PHAsset] = []
        PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in found.append(asset) }
        return found
    }

    static func assets(withIdentifiers identifiers: [String]) -> [PHAsset] {
        guard !identifiers.isEmpty else { return [] }
        var found: [PHAsset] = []
        PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            .enumerateObjects { asset, _, _ in found.append(asset) }
        return found
    }

    /// 実画像を 1 枚取る。`ImageRenderer` は同期描画なので、焼く前に済ませておく。
    static func image(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        // 低品質の速報が先に来ることがあるので完成版を待つが、
        // 完成版が来ないケースもある。速報を握って最後に必ず返す。
        return await withCheckedContinuation { continuation in
            let state = ImageRequestState()
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isFinished = !isDegraded
                    || (info?[PHImageCancelledKey] as? Bool) == true
                    || info?[PHImageErrorKey] != nil
                state.latest = image ?? state.latest
                guard isFinished, !state.resumed else { return }
                state.resumed = true
                continuation.resume(returning: state.latest)
            }
        }
    }
}
