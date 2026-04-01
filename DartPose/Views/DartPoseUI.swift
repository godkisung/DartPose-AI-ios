// DartPoseUI.swift
// Shared design system — colors, components, animations for DartPose

import SwiftUI

// MARK: - Color Palette

extension Color {
    /// Deep dark navy — primary background
    static let dpBackground    = Color(red: 0.04, green: 0.04, blue: 0.12)
    /// Frosted surface (cards, rows)
    static let dpSurface       = Color(white: 1, opacity: 0.05)
    /// Slightly brighter surface (hover / highlighted)
    static let dpSurfaceHigh   = Color(white: 1, opacity: 0.085)
    /// Hairline borders
    static let dpBorder        = Color(white: 1, opacity: 0.09)
    /// Electric cyan primary accent
    static let dpAccent        = Color.cyan
    /// Deep blue secondary accent
    static let dpBlue          = Color(red: 0.15, green: 0.50, blue: 1.00)
    /// Purple tertiary accent
    static let dpPurple        = Color(red: 0.65, green: 0.38, blue: 1.00)
    /// Teal success/positive
    static let dpTeal          = Color(red: 0.18, green: 0.78, blue: 0.60)

    static let dpTextPrimary   = Color.white
    static let dpTextSecondary = Color(white: 0.60)
    static let dpTextMuted     = Color(white: 0.38)
}

// MARK: - Animated Aurora Background

/// Full-screen animated aurora — use as ZStack bottom layer.
struct DPAnimatedBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.dpBackground

            // Orb 1 — cyan top-left drift
            Circle()
                .fill(Color.cyan.opacity(0.055))
                .blur(radius: 80)
                .frame(width: 380, height: 380)
                .offset(x: animate ? -80 : 60, y: animate ? -180 : -240)
                .animation(
                    .easeInOut(duration: 9).repeatForever(autoreverses: true),
                    value: animate
                )

            // Orb 2 — blue bottom-right drift
            Circle()
                .fill(Color.dpBlue.opacity(0.065))
                .blur(radius: 90)
                .frame(width: 420, height: 420)
                .offset(x: animate ? 120 : -40, y: animate ? 220 : 120)
                .animation(
                    .easeInOut(duration: 12).repeatForever(autoreverses: true).delay(2.5),
                    value: animate
                )

            // Orb 3 — indigo center drift
            Circle()
                .fill(Color.indigo.opacity(0.045))
                .blur(radius: 70)
                .frame(width: 300, height: 300)
                .offset(x: animate ? 55 : -110, y: animate ? 30 : -90)
                .animation(
                    .easeInOut(duration: 10).repeatForever(autoreverses: true).delay(5),
                    value: animate
                )
        }
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}

// MARK: - Glass Card View Modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var borderOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.dpSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.dpBorder.opacity(borderOpacity), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16, borderOpacity: Double = 1) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, borderOpacity: borderOpacity))
    }
}

// MARK: - Accent Gradient Foreground Modifier

struct AccentGradientModifier: ViewModifier {
    var colors: [Color]
    var start: UnitPoint
    var end: UnitPoint

    func body(content: Content) -> some View {
        content.foregroundStyle(
            LinearGradient(colors: colors, startPoint: start, endPoint: end)
        )
    }
}

extension View {
    func accentGradient(
        colors: [Color] = [.cyan, .dpBlue],
        start: UnitPoint = .leading,
        end: UnitPoint = .trailing
    ) -> some View {
        modifier(AccentGradientModifier(colors: colors, start: start, end: end))
    }
}

// MARK: - Section Header Component

struct DPSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var accentColor: Color = .cyan

    var body: some View {
        HStack(spacing: 10) {
            if let img = systemImage {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 30, height: 30)
                    Image(systemName: img)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.dpTextPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.dpTextMuted)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Issue Tag

/// Compact colored pill for displaying a detected issue.
struct DPIssueTag: View {
    let label: String
    var color: Color = .orange

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.11))
                    .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 0.75))
            )
            .lineLimit(1)
    }
}

// MARK: - Stat Cell Component

/// Single numeric stat with label — used in summary bars.
struct DPStatCell: View {
    let value: String
    let label: String
    var icon: String? = nil
    var color: Color = .cyan

    var body: some View {
        VStack(spacing: 5) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color.opacity(0.7))
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.dpTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Issue Label Helper

/// Maps internal issue key strings to display labels (Korean).
func dpIssueLabel(_ key: String) -> String {
    switch key {
    case "elbow_unstable_y":          return "팔꿈치 불안정"
    case "takeback_too_deep":         return "테이크백 과도"
    case "takeback_too_shallow":      return "테이크백 부족"
    case "slow_elbow_extension":      return "팔꿈치 속도↓"
    case "body_sway_detected":        return "몸통 흔들림"
    case "shoulder_unstable":         return "어깨 불안정"
    case "inconsistent_takeback":     return "테이크백 비일관"
    case "inconsistent_elbow_speed":  return "속도 비일관"
    default:                          return key
    }
}

// MARK: - Score Ring Component

/// Circular progress ring for a 0–100 score.
struct DPScoreRing: View {
    let score: Double
    let size: CGFloat
    let lineWidth: CGFloat

    private var color: Color {
        if score >= 80 { return .dpTeal }
        if score >= 60 { return .yellow }
        return .orange
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(score / 100))
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(String(format: "%.0f", score))
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("/ 100")
                    .font(.system(size: size * 0.09))
                    .foregroundColor(.dpTextMuted)
            }
        }
        .frame(width: size, height: size)
    }
}
