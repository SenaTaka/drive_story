import SwiftUI

/// 再生の 1 コマ。時間から計算した「今どこまで描くか」だけを持つ。
struct PlaybackFrame {
    /// ルートをどこまで伸ばしたか 0.0〜1.0。
    var routeProgress: Double
    /// すでに出した写真。
    var revealedPhotoIDs: Set<UUID>
}

/// 時間 → コマ。純関数で View に依存しない。
///
/// **`TimelineView` をこの層や `RouteRevealCanvas` の内側に置かないこと。**
/// 時間源を外から注入する形を保っておけば、同じ描画をフレーム単位で焼いて
/// mp4 に流せる。中に時計を持った瞬間その道が閉じる。
struct StoryPlaybackTimeline {
    /// 写真が出る時刻。撮影時刻を 0.0〜1.0 に正規化したもの。
    let photoTimes: [(id: UUID, t: Double)]
    var duration: TimeInterval = 6

    init(story: DriveStory, duration: TimeInterval = 6) {
        self.duration = duration
        // 経路上の位置ではなく並び順で出す。`DriveStory.photos` は撮影時刻順に来ている。
        let count = story.photos.count
        photoTimes = story.photos.enumerated().map { index, photo in
            let t = count > 1 ? Double(index) / Double(count - 1) : 0.5
            // ルートが伸びきる少し前に出し終える。
            return (id: photo.id, t: min(0.92, 0.12 + t * 0.78))
        }
    }

    func frame(at time: TimeInterval) -> PlaybackFrame {
        let t = duration > 0 ? min(max(time / duration, 0), 1) : 1
        // 出だしと締めを緩める（等速だと機械が描いているように見える）。
        let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        let revealed = photoTimes.filter { $0.t <= t }.map(\.id)
        return PlaybackFrame(routeProgress: eased, revealedPhotoIDs: Set(revealed))
    }
}

/// ルートが伸びて写真が順に出る層。コマを受け取るだけで、時間を知らない。
struct RouteRevealCanvas: View {
    let outline: RouteOutline
    let photos: [StoryPhoto]
    let frame: PlaybackFrame
    var lineColor: Color
    var glow: Color?
    var lineWidth: CGFloat = 14
    var pinSize: CGFloat = 44
    var inset: CGFloat = 0.12

    var body: some View {
        GeometryReader { geometry in
            let box = RouteShape.fittedBox(
                in: CGRect(origin: .zero, size: geometry.size), inset: inset
            )
            ZStack {
                if let glow {
                    RouteShape(outline: outline, inset: inset)
                        .trim(from: 0, to: frame.routeProgress)
                        .stroke(glow, style: .init(lineWidth: lineWidth * 3, lineCap: .round, lineJoin: .round))
                        .blur(radius: lineWidth * 2)
                }
                // RouteShape は Shape なので trim がそのまま効く。描画側の改造は要らない。
                RouteShape(outline: outline, inset: inset)
                    .trim(from: 0, to: frame.routeProgress)
                    .stroke(lineColor, style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                ForEach(photos) { photo in
                    let shown = frame.revealedPhotoIDs.contains(photo.id)
                    PhotoPin(photo: photo, size: pinSize, lineColor: lineColor)
                        .position(RouteShape.place(outline.point(atFraction: photo.position), in: box))
                        .scaleEffect(shown ? 1 : 0.2)
                        .opacity(shown ? 1 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: shown)
                }

                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(lineColor, lineWidth: pinSize * 0.12))
                    .frame(width: pinSize * 0.5, height: pinSize * 0.5)
                    .position(RouteShape.place(outline.start, in: box))
            }
        }
    }
}

private struct PhotoPin: View {
    let photo: StoryPhoto
    let size: CGFloat
    let lineColor: Color

    var body: some View {
        Group {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                PhotoPlaceholderView(placeholder: photo.placeholder)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28)
                .stroke(.white, lineWidth: size * 0.06)
        )
    }
}
