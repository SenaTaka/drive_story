import SwiftUI

/// RouteOutline の単位座標を、与えられた矩形へ縦横比を保ったまま描く。
struct RouteShape: Shape {
    let outline: RouteOutline
    /// 端が切れないよう内側に取る余白(矩形の短辺に対する比)。
    var inset: CGFloat = 0.08

    func path(in rect: CGRect) -> Path {
        let box = RouteShape.fittedBox(in: rect, inset: inset)
        var path = Path()
        guard let first = outline.points.first else { return path }
        path.move(to: RouteShape.place(first, in: box))
        for point in outline.points.dropFirst() {
            path.addLine(to: RouteShape.place(point, in: box))
        }
        return path
    }

    /// 単位正方形をそのまま入れられる最大の正方形。潰さないための要。
    static func fittedBox(in rect: CGRect, inset: CGFloat) -> CGRect {
        let side = min(rect.width, rect.height) * (1 - inset * 2)
        return CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        )
    }

    static func place(_ unit: CGPoint, in box: CGRect) -> CGPoint {
        CGPoint(x: box.minX + unit.x * box.width, y: box.minY + unit.y * box.height)
    }
}

/// ルート図 + START/GOAL + 写真ピンをまとめて置く層。
struct RouteCanvas: View {
    let outline: RouteOutline
    let photos: [StoryPhoto]
    var lineColor: Color
    var lineWidth: CGFloat
    var glow: Color?
    var showsEndpoints: Bool = true
    var pinSize: CGFloat = 18
    var inset: CGFloat = 0.08

    var body: some View {
        GeometryReader { geometry in
            let box = RouteShape.fittedBox(in: CGRect(origin: .zero, size: geometry.size), inset: inset)
            ZStack {
                if let glow {
                    RouteShape(outline: outline, inset: inset)
                        .stroke(glow, style: .init(lineWidth: lineWidth * 3, lineCap: .round, lineJoin: .round))
                        .blur(radius: lineWidth * 2)
                }
                RouteShape(outline: outline, inset: inset)
                    .stroke(lineColor, style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                ForEach(photos) { photo in
                    Circle()
                        .fill(lineColor)
                        .overlay(Circle().stroke(.white, lineWidth: pinSize * 0.22))
                        .frame(width: pinSize, height: pinSize)
                        .position(RouteShape.place(outline.point(atFraction: photo.position), in: box))
                }

                if showsEndpoints {
                    endpoint(filled: false)
                        .position(RouteShape.place(outline.start, in: box))
                    endpoint(filled: true)
                        .position(RouteShape.place(outline.goal, in: box))
                }
            }
        }
    }

    private func endpoint(filled: Bool) -> some View {
        Circle()
            .fill(filled ? lineColor : Color.white)
            .overlay(Circle().stroke(filled ? Color.white : lineColor, lineWidth: pinSize * 0.28))
            .frame(width: pinSize * 1.45, height: pinSize * 1.45)
    }
}
