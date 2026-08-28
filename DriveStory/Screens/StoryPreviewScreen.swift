import SwiftUI

/// このアプリの最重要画面。走り終わったあと最初に見るのがここ。
///
/// 遷移の終着ではなくハブ。編集・地図・再生・共有はここから生える。
struct StoryPreviewScreen: View {
    let story: DriveStory

    @State private var template: StoryTemplate = .scenic

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
        }
        .padding()
        .background(Color(white: 0.08))
        .navigationTitle(story.title.replacingOccurrences(of: "\n", with: " "))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { StoryPreviewScreen(story: SampleDrives.hakone) }
        .preferredColorScheme(.dark)
}
