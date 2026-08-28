import SwiftUI

/// ルートが伸びて写真が撮影時刻順に出るところを再生する。
///
/// 時間源はこの画面が持ち、描画（`RouteRevealCanvas`）には
/// 計算済みのコマだけを渡す。この分離を崩さない限り、
/// 同じ描画をフレーム単位で焼いて mp4 にできる。
struct StoryPlaybackScreen: View {
    let story: DriveStory

    @State private var startedAt = Date()
    @State private var isPlaying = true

    private var timeline: StoryPlaybackTimeline { StoryPlaybackTimeline(story: story) }
    private var theme: StoryTheme { StoryTemplate.night.theme }

    var body: some View {
        VStack(spacing: 16) {
            TimelineView(.animation(paused: !isPlaying)) { context in
                let elapsed = context.date.timeIntervalSince(startedAt)
                let looped = timeline.duration > 0
                    ? elapsed.truncatingRemainder(dividingBy: timeline.duration + 1.2)
                    : 0
                RouteRevealCanvas(
                    outline: story.route,
                    photos: story.photos,
                    frame: timeline.frame(at: looped),
                    lineColor: theme.routeLine,
                    glow: theme.routeGlow
                )
            }
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 24))

            HStack(spacing: 12) {
                Button {
                    startedAt = Date()
                    isPlaying = true
                } label: {
                    Label("最初から", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? "一時停止" : "再生", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Text("写真は撮影した順に出ます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(white: 0.08))
        .navigationTitle("再生")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startedAt = Date() }
    }
}

#Preview {
    NavigationStack { StoryPlaybackScreen(story: SampleDrives.hakone) }
        .preferredColorScheme(.dark)
}
