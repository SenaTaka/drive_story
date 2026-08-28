import CoreLocation
import Photos
import UIKit

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

        return await withCheckedContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
            ) { image, info in
                // 低品質の速報が先に来ることがある。完成版だけを受け取る。
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded, !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
