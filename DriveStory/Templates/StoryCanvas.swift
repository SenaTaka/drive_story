import SwiftUI

/// 1080×1920 の実寸で 1 枚を組む。テンプレの差は配色とルート図の見せ方だけ。
struct StoryCanvas: View {
    let story: DriveStory
    let template: StoryTemplate

    var body: some View {
        let theme = template.theme
        ZStack {
            theme.background
            switch template {
            case .scenic: ScenicLayout(story: story, theme: theme)
            case .route: RouteLayout(story: story, theme: theme)
            case .editorial: EditorialLayout(story: story, theme: theme)
            case .night: NightLayout(story: story, theme: theme)
            }
        }
        .frame(width: StoryCanvasSize.width, height: StoryCanvasSize.height)
        .clipped()
    }
}

// MARK: - Scenic: 実写が主役

private struct ScenicLayout: View {
    let story: DriveStory
    let theme: StoryTheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                PhotoPlaceholderView(placeholder: story.photos.first?.placeholder ?? .dawn)
                    .frame(height: 900)
                LinearGradient(
                    colors: [.clear, theme.background.opacity(0.95)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 900)

                VStack(alignment: .leading, spacing: 28) {
                    Text(story.title.uppercased())
                        .font(.system(size: 92, weight: .heavy))
                        .lineSpacing(-8)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                    Rectangle()
                        .fill(theme.accent)
                        .frame(width: 120, height: 8)
                }
                .padding(.horizontal, 72)
                .padding(.bottom, 56)

                VStack {
                    HStack {
                        StoryBrandMark(theme: theme)
                        Spacer()
                    }
                    .padding(.horizontal, 72)
                    .padding(.top, 72)
                    Spacer()
                }
                .frame(height: 900)
            }

            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 72) {
                    StoryStat(theme: theme, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                              value: story.distanceText, unit: "km", caption: "DISTANCE")
                    Rectangle().fill(theme.secondaryText.opacity(0.3)).frame(width: 2, height: 96)
                    StoryStat(theme: theme, symbol: "clock",
                              value: "\(story.durationHours)h \(String(format: "%02d", story.durationMinutes))",
                              unit: "m", caption: "DURATION")
                }

                RouteCanvas(
                    outline: story.route,
                    photos: story.photos,
                    lineColor: theme.routeLine,
                    lineWidth: 12,
                    glow: theme.routeGlow,
                    pinSize: 22
                )
                .frame(height: 330)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 40).fill(theme.panel))

                VStack(alignment: .leading, spacing: 20) {
                    if let scenic = story.scenic {
                        StoryStarRow(theme: theme, label: "SCENIC", symbol: "mountain.2", score: scenic)
                    }
                    if let curves = story.curves {
                        StoryStarRow(theme: theme, label: "CURVES", symbol: "road.lanes.curved.right", score: curves)
                    }
                }

                if !story.stops.isEmpty {
                    Text(story.stopsText)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }

                HStack {
                    Spacer()
                    StoryCTA(theme: theme, label: "DRIVE THIS ROUTE")
                    Spacer()
                }
            }
            .padding(.horizontal, 72)
            .padding(.top, 48)
            .padding(.bottom, 56)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Route: 地図が主役

private struct RouteLayout: View {
    let story: DriveStory
    let theme: StoryTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StoryBrandMark(theme: theme)
                Spacer()
                Text(story.dateText.uppercased())
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 72)
            .padding(.top, 72)

            RouteCanvas(
                outline: story.route,
                photos: story.photos,
                lineColor: theme.routeLine,
                lineWidth: 14,
                glow: theme.routeGlow,
                pinSize: 30,
                inset: 0.12
            )
            .frame(height: 900)

            VStack(alignment: .leading, spacing: 40) {
                HStack(alignment: .center, spacing: 40) {
                    Text(story.title.uppercased())
                        .font(.system(size: 88, weight: .black))
                        .lineSpacing(-10)
                        .foregroundStyle(theme.primaryText)
                    Spacer(minLength: 0)
                    Rectangle().fill(theme.secondaryText.opacity(0.3)).frame(width: 2, height: 160)
                    VStack(alignment: .leading, spacing: 24) {
                        StoryStat(theme: theme, symbol: "arrow.triangle.swap",
                                  value: story.distanceText, unit: "km", caption: "DISTANCE", valueSize: 56)
                        StoryStat(theme: theme, symbol: "clock",
                                  value: "\(story.durationHours)h \(String(format: "%02d", story.durationMinutes))",
                                  unit: "m", caption: "DURATION", valueSize: 56)
                    }
                }

                HStack(spacing: 18) {
                    ForEach(story.tags.prefix(3)) { tag in
                        StoryTagChip(theme: theme, tag: tag)
                    }
                }

                if let bestTime = story.bestTime {
                    HStack(spacing: 20) {
                        Image(systemName: "sun.horizon.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(theme.accent)
                        Text("BEST AT")
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(4)
                            .foregroundStyle(theme.secondaryText)
                        Text(bestTime)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(theme.accent)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 28).fill(theme.panel))
                }

                HStack {
                    Spacer()
                    StoryCTA(theme: theme, label: "SAVE & DRIVE", filled: false)
                    Spacer()
                }
            }
            .padding(.horizontal, 72)
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Editorial: 雑誌組版。写真 0 枚でも成立する

private struct EditorialLayout: View {
    let story: DriveStory
    let theme: StoryTheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let cover = story.photos.first {
                    PhotoPlaceholderView(placeholder: cover.placeholder)
                } else {
                    theme.panel
                }
                VStack {
                    HStack {
                        Spacer()
                        StoryBrandMark(theme: StoryTemplate.night.theme)
                        Spacer()
                    }
                    .padding(.top, 72)
                    Spacer()
                }
            }
            .frame(height: 840)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 56) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(story.title.uppercased())
                            .font(.system(size: 104, weight: theme.titleWeight, design: theme.titleDesign))
                            .lineSpacing(-16)
                            .lineLimit(2)
                            .minimumScaleFactor(0.55)
                            .foregroundStyle(theme.primaryText)
                        if let subtitle = story.subtitle {
                            Text(subtitle.uppercased())
                                .font(.system(size: 68, weight: .light, design: theme.titleDesign))
                                .foregroundStyle(theme.accent)
                        }
                    }
                    Spacer(minLength: 0)
                    RouteCanvas(
                        outline: story.route,
                        photos: [],
                        lineColor: theme.routeLine,
                        lineWidth: 10,
                        glow: nil,
                        pinSize: 18
                    )
                    .frame(width: 360, height: 360)
                    .background(RoundedRectangle(cornerRadius: 12).fill(theme.panel))
                }

                Rectangle().fill(theme.accent.opacity(0.4))
                    .frame(height: 2)
                    .padding(.vertical, 44)

                HStack(spacing: 64) {
                    StoryStat(theme: theme, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                              value: story.distanceText, unit: "km", valueSize: 82)
                    StoryStat(theme: theme, symbol: "clock",
                              value: "\(story.durationHours)h \(String(format: "%02d", story.durationMinutes))",
                              unit: "m", valueSize: 82)
                }

                Rectangle().fill(theme.accent.opacity(0.4))
                    .frame(height: 2)
                    .padding(.vertical, 44)

                HStack(spacing: 18) {
                    ForEach(story.tags.prefix(3)) { tag in
                        StoryTagChip(theme: theme, tag: tag)
                    }
                }

                if !story.stops.isEmpty {
                    HStack(spacing: 20) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STOPS")
                                .font(.system(size: 24, weight: .semibold))
                                .tracking(4)
                                .foregroundStyle(theme.secondaryText)
                            Text(story.stopsText)
                                .font(.system(size: 36, weight: .regular, design: theme.titleDesign))
                                .foregroundStyle(theme.primaryText)
                        }
                    }
                    .padding(.top, 40)
                }

                Spacer(minLength: 0)

                HStack {
                    Text(story.dateText)
                        .font(.system(size: 28, weight: .regular, design: theme.titleDesign))
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    StoryCTA(theme: theme, label: "OPEN ROUTE")
                }
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 64)
        }
    }
}

// MARK: - Night: ルートの形だけで成立する

private struct NightLayout: View {
    let story: DriveStory
    let theme: StoryTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StoryBrandMark(theme: theme)
                .padding(.top, 72)

            Spacer().frame(height: 72)

            Text(story.title.uppercased())
                .font(.system(size: 124, weight: .black))
                .lineSpacing(-26)
                .minimumScaleFactor(0.6)
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: 700, alignment: .leading)

            Spacer().frame(height: 40)

            HStack(alignment: .firstTextBaseline, spacing: 24) {
                Text(story.distanceText)
                    .font(.system(size: 82, weight: .black))
                    .foregroundStyle(theme.accent)
                Text("km")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                Rectangle().fill(theme.secondaryText.opacity(0.4)).frame(width: 2, height: 70)
                Text("\(story.durationHours)h \(String(format: "%02d", story.durationMinutes))")
                    .font(.system(size: 82, weight: .black))
                    .foregroundStyle(theme.accent)
                Text("m")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(theme.primaryText)
            }

            Rectangle().fill(theme.accent).frame(width: 160, height: 8)
                .padding(.vertical, 32)

            if !story.stops.isEmpty {
                Text(story.stopsText)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(theme.primaryText)
            }

            HStack(spacing: 18) {
                ForEach(story.tags.prefix(2)) { tag in
                    StoryTagChip(theme: theme, tag: tag)
                }
            }
            .padding(.top, 32)

            // 写真 0 枚でも成立させる要。空いた面をルートの形そのもので埋める。
            RouteCanvas(
                outline: story.route,
                photos: [],
                lineColor: theme.routeLine,
                lineWidth: 16,
                glow: theme.routeGlow,
                showsEndpoints: false,
                inset: 0.04
            )
            .frame(height: 600)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            Spacer(minLength: 0)

            if let bestTime = story.bestTime {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BEST ENJOYED AFTER")
                        .font(.system(size: 26, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(theme.accent)
                    Text(bestTime)
                        .font(.system(size: 68, weight: .black))
                        .foregroundStyle(theme.primaryText)
                }
                .padding(.leading, 32)
                .overlay(alignment: .leading) {
                    Rectangle().fill(theme.accent).frame(width: 6)
                }
            }

            HStack {
                Text("Shared from Drive Story")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                StoryCTA(theme: theme, label: "TRY THIS DRIVE", filled: false)
            }
            .padding(.top, 40)
            .padding(.bottom, 72)
        }
        .padding(.horizontal, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    StoryCanvas(story: SampleDrives.hakone, template: .scenic)
        .scaleEffect(0.2)
}
