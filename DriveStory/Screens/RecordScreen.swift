import SwiftUI

/// ホーム。走行の開始と終了をここで行う。
///
/// 記録層はこれから（README の「実装計画（MVP）」ステップ 2）。
/// それまではレンダラの退行確認用にサンプルへの入口だけ置く。
struct RecordScreen: View {
    var body: some View {
        List {
            Section {
                Text("走行の記録はこれから実装する。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("記録")
            }

            Section {
                ForEach(SampleDrives.all.indices, id: \.self) { index in
                    NavigationLink(value: Route.sampleStory(index)) {
                        SampleRow(story: SampleDrives.all[index])
                    }
                }
            } header: {
                Text("サンプル")
            } footer: {
                Text("レンダラの検証用ダミー。実走行が入るまでの確認用。")
            }
        }
        .navigationTitle("Drive Story")
    }
}

private struct SampleRow: View {
    let story: DriveStory

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(story.title.replacingOccurrences(of: "\n", with: " "))
            Text("\(story.distanceText) km ・ \(story.durationHours)h \(story.durationMinutes)m")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { RecordScreen() }
        .preferredColorScheme(.dark)
}
