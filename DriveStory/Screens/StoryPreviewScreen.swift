import SwiftUI

/// このアプリの最重要画面。走り終わったあと最初に見るのがここ。
struct StoryPreviewScreen: View {
    @State private var storyIndex = 0
    @State private var template: StoryTemplate = .scenic
    @State private var exportNote: String?

    private var story: DriveStory { SampleDrives.all[storyIndex] }

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                let scale = min(
                    geometry.size.width / StoryCanvasSize.width,
                    geometry.size.height / StoryCanvasSize.height
                )
                StoryCanvas(story: story, template: template)
                    .scaleEffect(scale, anchor: .center)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            Picker("Template", selection: $template) {
                ForEach(StoryTemplate.allCases) { candidate in
                    Text(candidate.displayName).tag(candidate)
                }
            }
            .pickerStyle(.segmented)

            Picker("Drive", selection: $storyIndex) {
                ForEach(SampleDrives.all.indices, id: \.self) { index in
                    Text(SampleDrives.all[index].title.replacingOccurrences(of: "\n", with: " "))
                        .tag(index)
                }
            }
            .pickerStyle(.menu)

            Button("PNG を書き出す(検証用)") {
                let urls = StoryExporter.dumpAll(SampleDrives.all)
                exportNote = "\(urls.count) 枚"
            }
            .buttonStyle(.borderedProminent)

            if let exportNote {
                Text(exportNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(white: 0.08))
        .preferredColorScheme(.dark)
        .task {
            // 検証用: STORY_DUMP=1 で起動すると全テンプレを Documents へ書き出す。
            // 「ビルド成功」だけを完了根拠にしないための目視確認経路。
            guard ProcessInfo.processInfo.environment["STORY_DUMP"] == "1" else { return }
            StoryExporter.dumpAll(SampleDrives.all)
        }
    }
}

#Preview {
    StoryPreviewScreen()
}
