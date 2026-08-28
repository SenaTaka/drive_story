import SwiftUI

/// アプリの入口。画面遷移とデバッグ経路をここに集める。
///
/// `StoryPreviewScreen` は遷移の終着ではなくハブなので、
/// 「どこから来てどこへ行けるか」の知識はこの View だけが持つ。
struct RootView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            RecordScreen()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .sampleStory(let index):
                        StoryPreviewScreen(story: SampleDrives.all[index])
                    }
                }
        }
        .preferredColorScheme(.dark)
        .task {
            // 検証用: STORY_DUMP=1 で起動すると全テンプレを Documents へ書き出す。
            // 「ビルド成功」だけを完了根拠にしないための目視確認経路。画面操作は要らない。
            guard ProcessInfo.processInfo.environment["STORY_DUMP"] == "1" else { return }
            StoryExporter.dumpAll(SampleDrives.all)
        }
    }
}

/// 遷移先。`DriveRecord` を扱う画面が増えたらここに case を足す。
enum Route: Hashable {
    /// レンダラ検証用のサンプル。記録層ができたあとも退行確認に残す。
    case sampleStory(Int)
}

#Preview {
    RootView()
}
