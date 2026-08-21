import SwiftUI

enum Theme {
    static let navyDeep = Color(red: 0.043, green: 0.086, blue: 0.173)
    static let navyMid = Color(red: 0.047, green: 0.180, blue: 0.424)
    static let accent = Color(red: 0.031, green: 0.435, blue: 0.953)
    static let accentSoft = Color(red: 0.53, green: 0.74, blue: 0.99)
    static let card = Color(nsColor: .controlBackgroundColor)

    static let dashboardColor = Color(hex: 0x0A84FF)
    static let junkColor = Color(hex: 0x8E8E93)
    static let largeColor = Color(hex: 0x30B0C7)
    static let duplicateColor = Color(hex: 0xAF52DE)
    static let trashColor = Color(hex: 0xFF9500)
    static let uninstallColor = Color(hex: 0xFF2D55)
    static let memoryColor = Color(hex: 0x34C759)

    static let backgroundGradient = LinearGradient(
        colors: [Color.white, Color(red: 0.92, green: 0.95, blue: 1.0)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let heroGradient = LinearGradient(
        colors: [navyMid, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func moduleGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.85), color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.backgroundGradient
            Circle()
                .fill(Theme.accent.opacity(0.10))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: 380, y: -280)
            Circle()
                .fill(Color(red: 0.5, green: 0.7, blue: 1.0).opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -340, y: 320)
        }
        .ignoresSafeArea()
    }
}

struct HeroHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = Theme.accent
    var actionTitle: String? = nil
    var actionIcon: String = "magnifyingglass"
    var actionEnabled: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.moduleGradient(tint))
                    .frame(width: 60, height: 60)
                    .shadow(color: tint.opacity(0.4), radius: 10, y: 4)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.navyDeep)
                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if let actionTitle, let action {
                Button(action: action) {
                    VStack(spacing: 3) {
                        Image(systemName: actionIcon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(actionTitle)
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(
                        Circle()
                            .fill(Theme.heroGradient)
                            .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!actionEnabled)
                .opacity(actionEnabled ? 1 : 0.45)
                .help(actionTitle)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: Theme.navyDeep.opacity(0.10), radius: 14, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 1)
        )
    }
}

extension View {
    func controlBar() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.75))
                    .shadow(color: Theme.navyDeep.opacity(0.06), radius: 6, y: 2)
            )
    }
}

struct ModernTitle: View {
    let text: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.navyDeep, Theme.navyMid],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func card(_ padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}