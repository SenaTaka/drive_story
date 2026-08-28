import SwiftUI
import UIKit

/// 標準の共有シート。Instagram / TikTok / X へはここから渡る。
///
/// 自前の共有先一覧を作らない。ユーザーが普段使うアプリは OS が知っている。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
