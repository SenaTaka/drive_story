import Photos
import UIKit

/// 完成した 1 枚を写真ライブラリへ保存する。
///
/// 共有シートは相手アプリ任せだが、保存はこちらの責任で完結する。
/// 「保存した」と言い切るために、書き込んだ asset の識別子を返す。
enum PhotoSaver {
    enum SaveError: Error {
        case notAuthorized
        case failed(String)
    }

    @discardableResult
    static func save(_ image: UIImage) async throws -> String {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { continuation.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else { throw SaveError.notAuthorized }

        var identifier: String?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                identifier = request.placeholderForCreatedAsset?.localIdentifier
            }
        } catch {
            throw SaveError.failed(error.localizedDescription)
        }
        guard let identifier else { throw SaveError.failed("識別子が返らなかった") }
        return identifier
    }
}
