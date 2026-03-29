// HomeView.swift
// 메인 홈 화면
//
// 앱의 루트 화면입니다. 로고와 "영상 분석 시작" 버튼을 제공합니다.
// NavigationLink로 VideoPickerView로 이동합니다.

import SwiftUI

/// 앱 메인 홈 화면.
/// 앱 로고, 설명, 영상 분석 시작 버튼을 제공합니다.
struct HomeView: View {
    var body: some View {
        ZStack {
            // 배경 그래디언트
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.08, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // 로고 영역
                VStack(spacing: 16) {
                    Image(systemName: "figure.cooldown")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .cyan.opacity(0.5), radius: 20)

                    Text("DartPose")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("AI 다트 코치")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }

                // 기능 설명 카드
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "video.fill", text: "영상에서 투구 동작 자동 감지")
                    featureRow(icon: "figure.strengthtraining.traditional",
                             text: "생체역학 기반 10가지 지표 분석")
                    featureRow(icon: "chart.bar.fill", text: "투구별 상세 리포트 제공")
                    featureRow(icon: "text.bubble.fill", text: "AI 코칭 피드백")
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()

                // 영상 분석 시작 버튼
                NavigationLink(destination: VideoPickerView()) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                        Text("영상 분석 시작")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .cyan.opacity(0.4), radius: 10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
    }

    /// 기능 설명 행
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
