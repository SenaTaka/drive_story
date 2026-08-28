import SwiftUI

/// Story のテンプレート。実装はテンプレごとの画面ではなく「1 つのレンダラ + テーマ」。
enum StoryTemplate: String, CaseIterable, Identifiable {
    case scenic, route, editorial, night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scenic: "Scenic"
        case .route: "Route"
        case .editorial: "Editorial"
        case .night: "Night"
        }
    }

    /// 写真 0 枚でも成立するか。走った日に写真がなくても Story を落とさないための保険。
    var worksWithoutPhotos: Bool {
        switch self {
        case .scenic, .route: false
        case .editorial, .night: true
        }
    }

    var theme: StoryTheme {
        switch self {
        case .scenic:
            StoryTheme(
                background: Color(red: 0.06, green: 0.07, blue: 0.09),
                primaryText: .white,
                secondaryText: .white.opacity(0.72),
                accent: Color(red: 0.98, green: 0.78, blue: 0.35),
                routeLine: Color(red: 0.98, green: 0.78, blue: 0.35),
                routeGlow: nil,
                panel: Color.white.opacity(0.08),
                titleDesign: .default,
                titleWeight: .heavy
            )
        case .route:
            StoryTheme(
                background: Color(red: 0.03, green: 0.05, blue: 0.11),
                primaryText: .white,
                secondaryText: .white.opacity(0.6),
                accent: Color(red: 1.0, green: 0.72, blue: 0.35),
                routeLine: Color(red: 1.0, green: 0.85, blue: 0.6),
                routeGlow: Color(red: 1.0, green: 0.72, blue: 0.35).opacity(0.5),
                panel: Color.white.opacity(0.06),
                titleDesign: .default,
                titleWeight: .black
            )
        case .editorial:
            StoryTheme(
                background: Color(red: 0.96, green: 0.95, blue: 0.92),
                primaryText: Color(red: 0.09, green: 0.13, blue: 0.2),
                secondaryText: Color(red: 0.09, green: 0.13, blue: 0.2).opacity(0.6),
                accent: Color(red: 0.68, green: 0.55, blue: 0.31),
                routeLine: Color(red: 0.68, green: 0.55, blue: 0.31),
                routeGlow: nil,
                panel: Color(red: 0.90, green: 0.91, blue: 0.87),
                titleDesign: .serif,
                titleWeight: .regular
            )
        case .night:
            StoryTheme(
                background: Color(red: 0.04, green: 0.05, blue: 0.07),
                primaryText: .white,
                secondaryText: .white.opacity(0.65),
                accent: Color(red: 0.90, green: 0.16, blue: 0.20),
                routeLine: Color(red: 0.95, green: 0.20, blue: 0.24),
                routeGlow: Color(red: 0.95, green: 0.20, blue: 0.24).opacity(0.8),
                panel: Color.white.opacity(0.05),
                titleDesign: .default,
                titleWeight: .black
            )
        }
    }
}

struct StoryTheme {
    let background: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let routeLine: Color
    let routeGlow: Color?
    let panel: Color
    let titleDesign: Font.Design
    let titleWeight: Font.Weight
}

/// Story の実寸。Instagram / TikTok のストーリー面。
enum StoryCanvasSize {
    static let width: CGFloat = 1080
    static let height: CGFloat = 1920
    static var size: CGSize { CGSize(width: width, height: height) }
}
