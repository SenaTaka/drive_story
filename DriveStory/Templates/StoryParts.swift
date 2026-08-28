import SwiftUI

/// 全テンプレで使い回す部品。1080×1920 の実寸で描くので数値はポイントそのまま。

struct StoryBrandMark: View {
    let theme: StoryTheme
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 34, weight: .bold))
            Text("DRIVE STORY")
                .font(.system(size: 30, weight: .semibold))
                .tracking(8)
        }
        .foregroundStyle(theme.primaryText)
    }
}

struct StoryStat: View {
    let theme: StoryTheme
    let symbol: String
    let value: String
    let unit: String
    var caption: String?
    var valueSize: CGFloat = 76

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: valueSize * 0.5, weight: .regular))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                if let caption {
                    Text(caption)
                        .font(.system(size: 24, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(theme.secondaryText)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: valueSize, weight: .bold, design: theme.titleDesign))
                    Text(unit)
                        .font(.system(size: valueSize * 0.4, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .foregroundStyle(theme.primaryText)
    }
}

struct StoryTagChip: View {
    let theme: StoryTheme
    let tag: DriveTag
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tag.symbol)
                .font(.system(size: 26, weight: .medium))
            Text(tag.label)
                .font(.system(size: 26, weight: .semibold))
                .tracking(2)
        }
        .foregroundStyle(filled ? theme.background : theme.primaryText)
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background {
            Capsule()
                .fill(filled ? theme.accent : Color.clear)
                .overlay(Capsule().stroke(theme.primaryText.opacity(filled ? 0 : 0.28), lineWidth: 2))
        }
    }
}

struct StoryStarRow: View {
    let theme: StoryTheme
    let label: String
    let symbol: String
    let score: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 30))
                .foregroundStyle(theme.accent)
            Text(label)
                .font(.system(size: 26, weight: .semibold))
                .tracking(3)
                .foregroundStyle(theme.secondaryText)
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < score ? "star.fill" : "star")
                        .font(.system(size: 24))
                        .foregroundStyle(index < score ? theme.accent : theme.secondaryText.opacity(0.4))
                }
            }
        }
    }
}

struct StoryCTA: View {
    let theme: StoryTheme
    let label: String
    var filled: Bool = true

    var body: some View {
        HStack(spacing: 20) {
            Text(label)
                .font(.system(size: 34, weight: .bold))
                .tracking(4)
            Image(systemName: "arrow.right")
                .font(.system(size: 30, weight: .bold))
        }
        .foregroundStyle(filled ? theme.background : theme.primaryText)
        .padding(.horizontal, 56)
        .padding(.vertical, 34)
        .background {
            Capsule()
                .fill(filled ? theme.accent : Color.clear)
                .overlay(Capsule().stroke(theme.accent, lineWidth: filled ? 0 : 3))
        }
    }
}

/// 実写が入る前の代替。撮影時刻帯の空の色を敷いておく。
struct PhotoPlaceholderView: View {
    let placeholder: PhotoPlaceholder

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var colors: [Color] {
        switch placeholder {
        case .dawn:
            [Color(red: 0.98, green: 0.75, blue: 0.45), Color(red: 0.42, green: 0.44, blue: 0.55)]
        case .day:
            [Color(red: 0.52, green: 0.72, blue: 0.92), Color(red: 0.30, green: 0.42, blue: 0.38)]
        case .dusk:
            [Color(red: 0.99, green: 0.58, blue: 0.26), Color(red: 0.24, green: 0.20, blue: 0.35)]
        case .night:
            [Color(red: 0.10, green: 0.13, blue: 0.24), Color(red: 0.02, green: 0.03, blue: 0.06)]
        }
    }
}

extension DriveStory {
    var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var stopsText: String { stops.joined(separator: "  /  ") }
}
