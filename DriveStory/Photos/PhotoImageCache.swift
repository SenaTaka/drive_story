import Combine
import Foundation
import UIKit

/// `PhotoRef` の識別子から実画像を引く層。
///
/// `StoryExporter` の `ImageRenderer` は同期描画なので、非同期ロードのままだと
/// 写真枠が空白の PNG が焼ける。**焼く前に全部揃えておく**のがこの層の役目。
@MainActor
final class PhotoImageCache: ObservableObject {
    @Published private(set) var images: [String: UIImage] = [:]

    /// Story の写真枠は最大でも 1080 幅。それ以上の解像度を持っても意味がない。
    private let targetSize = CGSize(width: 1080, height: 1080)

    func preload(_ refs: [PhotoRef]) async {
        let missing = refs.map(\.assetLocalIdentifier).filter { images[$0] == nil }
        guard !missing.isEmpty else { return }

        for asset in PhotoLibraryService.assets(withIdentifiers: missing) {
            if let image = await PhotoLibraryService.image(for: asset, targetSize: targetSize) {
                images[asset.localIdentifier] = image
            }
        }
    }

    func image(for identifier: String) -> UIImage? { images[identifier] }

    func clear() { images = [:] }
}
