// AnalysisView.swift
// 분석 진행 및 결과 화면
//
// 영상 분석 파이프라인의 진행 상태를 실시간으로 표시합니다.
// 완료 시 결과 요약과 투구별 상세 결과로 이동합니다.

import SwiftUI

/// 분석 진행 상태 및 결과 표시 화면.
struct AnalysisView: View {
    let videoURL: URL
    @StateObject private var viewModel = AnalysisViewModel()

    var body: some View {
        ZStack {
            // 배경
            Color(red: 0.05, green: 0.05, blue: 0.15)
                .ignoresSafeArea()

            Group {
                switch viewModel.state {
                case .idle, .extractingPoses, .analyzing, .generatingFeedback:
                    progressView

                case .completed(let session):
                    resultView(session: session)

                case .error(let msg):
                    errorView(message: msg)
                }
            }
        }
        .navigationTitle("분석")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.startAnalysis(videoURL: videoURL)
        }
    }

    // MARK: - 진행 상태 뷰

    private var progressView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 애니메이션 아이콘
            Image(systemName: progressIcon)
                .font(.system(size: 60))
                .foregroundColor(.cyan)
                .symbolEffect(.pulse)

            Text(progressTitle)
                .font(.title3.bold())
                .foregroundColor(.white)

            Text(progressSubtitle)
                .font(.subheadline)
                .foregroundColor(.gray)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.5)

            Spacer()
        }
    }

    /// 진행 상태에 따른 아이콘
    private var progressIcon: String {
        switch viewModel.state {
        case .extractingPoses: return "figure.walk"
        case .analyzing: return "waveform.path.ecg"
        case .generatingFeedback: return "text.bubble"
        default: return "hourglass"
        }
    }

    /// 진행 상태 제목
    private var progressTitle: String {
        switch viewModel.state {
        case .extractingPoses: return "포즈 추출 중..."
        case .analyzing: return "투구 분석 중..."
        case .generatingFeedback: return "피드백 생성 중..."
        default: return "준비 중..."
        }
    }

    /// 진행 상태 부제목
    private var progressSubtitle: String {
        switch viewModel.state {
        case .extractingPoses:
            return "영상에서 관절 좌표를 추출하고 있습니다"
        case .analyzing:
            return "투구 구간 분리 및 생체역학 분석 중"
        case .generatingFeedback:
            return "AI 코칭 피드백을 작성하고 있습니다"
        default:
            return "잠시만 기다려주세요"
        }
    }

    // MARK: - 결과 뷰

    private func resultView(session: SessionResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 요약 카드
                summaryCard(session: session)

                // 투구별 상세 결과 리스트
                ForEach(session.throws_) { throwAnalysis in
                    NavigationLink(
                        destination: ResultDetailView(throwAnalysis: throwAnalysis)
                    ) {
                        throwCard(throwAnalysis: throwAnalysis)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 피드백 섹션
                if !viewModel.feedback.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("💡 AI 코칭 피드백")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(viewModel.feedback)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                            )
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }

    /// 세션 요약 카드
    private func summaryCard(session: SessionResult) -> some View {
        HStack(spacing: 24) {
            statBlock(value: "\(session.totalThrowsDetected)", label: "투구 수")
            statBlock(value: "\(session.totalFrames)", label: "총 프레임")
            statBlock(value: String(format: "%.0f", session.fps), label: "FPS")
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0.15), .blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    /// 통계 블록
    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundColor(.cyan)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    /// 투구 카드
    private func throwCard(throwAnalysis: ThrowAnalysis) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("투구 #\(throwAnalysis.throwIndex)")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("\(throwAnalysis.throwingArm)손 · \(throwAnalysis.frameRange[0])~\(throwAnalysis.frameRange[1])")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // 핵심 메트릭 미리보기
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f°", throwAnalysis.metrics.takebackAngleDeg))
                    .font(.subheadline.bold())
                    .foregroundColor(.cyan)
                Text("테이크백")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.leading, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 에러 뷰

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("분석 실패")
                .font(.title3.bold())
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("다시 시도") {
                Task {
                    viewModel.reset()
                    await viewModel.startAnalysis(videoURL: videoURL)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
    }
}
