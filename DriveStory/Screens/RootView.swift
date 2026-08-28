import SwiftUI

/// アプリの入口。画面遷移とデバッグ経路をここに集める。
///
/// `StoryPreviewScreen` は遷移の終着ではなくハブなので、
/// 「どこから来てどこへ行けるか」の知識はこの View だけが持つ。
struct RootView: View {
    @StateObject private var recorder = DriveRecorder()
    @StateObject private var store = DriveRecordStore()
    @StateObject private var cache = PhotoImageCache()
    @State private var path: [Route] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            RecordScreen(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .sampleStory(let index):
                        StoryPreviewScreen(story: SampleDrives.all[index])
                    case .record(let id):
                        if let record = store.record(id: id) {
                            StoryPreviewScreen(
                                story: StoryBuilder.story(from: record, images: cache.images),
                                recordID: id
                            )
                        } else {
                            Text("この記録は見つかりません")
                        }
                    case .photos(let id):
                        PhotoSelectScreen(recordID: id)
                    case .map(let id):
                        if let record = store.record(id: id) {
                            DriveMapScreen(record: record)
                        } else {
                            Text("この記録は見つかりません")
                        }
                    case .playback(let id):
                        if let record = store.record(id: id) {
                            StoryPlaybackScreen(
                                story: StoryBuilder.story(from: record, images: cache.images)
                            )
                        } else {
                            Text("この記録は見つかりません")
                        }
                    }
                }
        }
        .environmentObject(recorder)
        .environmentObject(store)
        .environmentObject(cache)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            // 走行中に落ちるとそこまでの軌跡が丸ごと消える。背面へ回る時点で退避する。
            if phase != .active { recorder.persistInflight() }
        }
        .task {
            // 検証用: STORY_DUMP=1 で全テンプレを Documents へ書き出す。
            // 「ビルド成功」だけを完了根拠にしないための目視確認経路。画面操作は要らない。
            if ProcessInfo.processInfo.environment["STORY_DUMP"] == "1" {
                StoryExporter.dumpAll(SampleDrives.all)
            }
            // 検証用: DRIVE_VERIFY=1 で走行〜Story 生成までを画面操作なしで通す。
            if VerifyHarness.isEnabled {
                await VerifyHarness.run(recorder: recorder, store: store, cache: cache)
            }
        }
    }
}

/// 遷移先。
enum Route: Hashable {
    /// レンダラ検証用のサンプル。記録層ができたあとも退行確認に残す。
    case sampleStory(Int)
    /// 実走行の記録。
    case record(UUID)
    case photos(UUID)
    case map(UUID)
    case playback(UUID)
}

#Preview {
    RootView()
}
