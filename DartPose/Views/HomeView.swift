// HomeView.swift
// 메인 홈 화면 — 완전 리디자인

import SwiftUI

struct HomeView: View {
    @State private var heroAppeared   = false
    @State private var cardsAppeared  = false
    @State private var shimmerOffset: CGFloat = -250

    // Feature cards data
    private let features: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("video.fill",                          "자동 감지",   "투구 동작 자동 분리",   .cyan),
        ("figure.strengthtraining.traditional", "생체역학",   "10가지 지표 분석",     Color.dpBlue),
        ("chart.line.uptrend.xyaxis",           "각도 차트",  "Phase별 시각화",      Color.dpPurple),
        ("text.bubble.fill",                    "AI 코치",    "맞춤 피드백 제공",     Color.dpTeal),
    ]

    var body: some View {
        ZStack {
            DPAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero section
                    heroSection
                        .padding(.top, 20)
                        .opacity(heroAppeared ? 1 : 0)
                        .scaleEffect(heroAppeared ? 1 : 0.88)
                        .animation(
                            .spring(response: 0.75, dampingFraction: 0.72),
                            value: heroAppeared
                        )

                    Spacer().frame(height: 28)

                    // Feature grid
                    featureGrid
                        .opacity(cardsAppeared ? 1 : 0)
                        .offset(y: cardsAppeared ? 0 : 16)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.82).delay(0.16),
                            value: cardsAppeared
                        )

                    Spacer().frame(height: 16)

                    // Version badge
                    versionBadge
                        .opacity(cardsAppeared ? 1 : 0)
                        .animation(.easeInOut(duration: 0.4).delay(0.3), value: cardsAppeared)

                    Spacer().frame(height: 16)

                    // CTA button
                    ctaButton
                        .opacity(cardsAppeared ? 1 : 0)
                        .offset(y: cardsAppeared ? 0 : 12)
                        .animation(
                            .spring(response: 0.55, dampingFraction: 0.8).delay(0.26),
                            value: cardsAppeared
                        )
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            heroAppeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                cardsAppeared = true
            }
            // Shimmer loop
            withAnimation(
                .linear(duration: 2.6).repeatForever(autoreverses: false).delay(1.0)
            ) {
                shimmerOffset = 350
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Glow + icon stack
            ZStack {
                // Blurred glow
                Image(systemName: "figure.cooldown")
                    .font(.system(size: 62))
                    .foregroundColor(.cyan)
                    .blur(radius: 20)
                    .opacity(0.48)
                    .offset(y: 5)

                // Crisp gradient icon
                Image(systemName: "figure.cooldown")
                    .font(.system(size: 62))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, Color.dpBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // App name + tagline
            VStack(spacing: 8) {
                Text("DartPose")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(white: 0.82)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.4))
                        .frame(width: 26, height: 1)

                    Text("AI 다트 코칭 시스템")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.cyan.opacity(0.82))
                        .tracking(2.8)

                    Rectangle()
                        .fill(Color.cyan.opacity(0.4))
                        .frame(width: 26, height: 1)
                }
            }
        }
    }

    // MARK: - Feature Grid

    private var featureGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                featureCard(features[0])
                featureCard(features[1])
            }
            HStack(spacing: 12) {
                featureCard(features[2])
                featureCard(features[3])
            }
        }
    }

    private func featureCard(_ f: (icon: String, title: String, subtitle: String, color: Color)) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(f.color.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: f.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(f.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(f.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.dpTextPrimary)
                Text(f.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.dpTextMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Version Badge

    private var versionBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9))
                .foregroundColor(.cyan.opacity(0.7))
            Text("MediaPipe · 10-Metric Biomechanics · Swift Charts")
                .font(.system(size: 10))
                .foregroundColor(.dpTextMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.dpSurface)
                .overlay(Capsule().stroke(Color.dpBorder, lineWidth: 1))
        )
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        NavigationLink(destination: VideoPickerView()) {
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [.cyan, Color.dpBlue],
                    startPoint: .leading, endPoint: .trailing
                )

                // Shimmer sweep
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.14), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 90)
                    .offset(x: shimmerOffset)

                // Label
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("분석 시작하기")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }
                .padding(.horizontal, 24)
                .foregroundColor(.white)
            }
            .frame(height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .cyan.opacity(0.38), radius: 22, y: 8)
        }
    }
}
