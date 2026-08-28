import SwiftUI
import UIKit

/// Story を 1080×1920 の PNG に焼く。Canvas が実寸で組まれているので scale は 1。
@MainActor
enum StoryExporter {
    static func image(for story: DriveStory, template: StoryTemplate) -> UIImage? {
        let renderer = ImageRenderer(content: StoryCanvas(story: story, template: template))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(StoryCanvasSize.size)
        return renderer.uiImage
    }

    /// 検証用。全テンプレを Documents に書き出してパスを返す。
    @discardableResult
    static func dumpAll(_ stories: [DriveStory]) -> [URL] {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var written: [URL] = []
        for story in stories {
            for template in StoryTemplate.allCases {
                guard let image = image(for: story, template: template),
                      let data = image.pngData() else { continue }
                let slug = story.title
                    .replacingOccurrences(of: "\n", with: "-")
                    .replacingOccurrences(of: " ", with: "-")
                    .lowercased()
                let url = directory.appendingPathComponent("\(slug)_\(template.rawValue).png")
                try? data.write(to: url)
                written.append(url)
            }
        }
        return written
    }
}
