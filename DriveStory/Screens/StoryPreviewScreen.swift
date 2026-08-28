import SwiftUI
import UIKit

/// このアプリの最重要画面。走り終わったあと最初に見るのがここ。
///
/// 遷移の終着ではなくハブ。編集・地図・再生・共有はここから生える。
struct StoryPreviewScreen: View {
    let story: DriveStory
    /// 実走行なら記録の ID。サンプルでは nil で、編集や地図の導線を出さない。
    var recordID: UUID? = nil

    @State private var template: StoryTemplate = .scenic
    @State private var shareImage: UIImage?
    @State private var note: String?
    @State private var isWorking = false

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

            if let recordID {
                HStack(spacing: 12) {
                    NavigationLink(value: Route.photos(recordID)) {
                        Label("写真", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    NavigationLink(value: Route.map(recordID)) {
                        Label("地図", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    NavigationLink(value: Route.playback(recordID)) {
                        Label("再生", systemImage: "play.circle")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .font(.footnote)
            }

            HStack(spacing: 12) {
                Button {
                    share()
                } label: {
                    Label("共有", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    saveToLibrary()
                } label: {
                    Label("写真に保存", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .disabled(isWorking)

            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(white: 0.08))
        .navigationTitle(story.title.replacingOccurrences(of: "\n", with: " "))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareImage) { image in
            ShareSheet(items: [image])
        }
    }

    private func share() {
        guard let image = StoryExporter.image(for: story, template: template) else {
            note = "画像を作れませんでした"
            return
        }
        shareImage = image
    }

    private func saveToLibrary() {
        guard let image = StoryExporter.image(for: story, template: template) else {
            note = "画像を作れませんでした"
            return
        }
        isWorking = true
        Task {
            do {
                try await PhotoSaver.save(image)
                note = "写真に保存しました"
            } catch {
                note = "保存できませんでした（写真への追加を許可してください）"
            }
            isWorking = false
        }
    }
}

/// `sheet(item:)` に渡すため。共有する画像は一度に 1 枚だけ。
extension UIImage: @retroactive Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

#Preview {
    NavigationStack { StoryPreviewScreen(story: SampleDrives.hakone) }
        .preferredColorScheme(.dark)
}
