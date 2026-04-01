// AnalysisView.swift
// 분석 진행 및 결과 화면

import SwiftUI

struct AnalysisView: View {
    let videoURL: URL
    @StateObject private var viewModel = AnalysisViewModel()
    @State private var throwsAppeared = false

    private var statePhase: Int {
        switch viewModel.state {
        case .idle:               return 0
        case .extractingPoses:    return 1
        case .analyzing:          return 2
        case .generatingFeedback: return 3
        case .completed:          return 4
        case .error:              return 5
        }
    }

    var body: some View {
        ZStack {
            DPAnimatedBackground()

            Group {
                switch viewModel.state {
                case .idle, .extractingPoses, .analyzing, .generatingFeedback:
                    AnalysisLoadingView(state: viewModel.state)
                        .transition(.opacity)

                case .completed(let session):
                    resultView(session: session)
                        .transition(.opacity)

                case .error(let msg):
                    errorView(message: msg)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: statePhase)
        }
        .navigationTitle("분석")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.startAnalysis(videoURL: videoURL)
        }
    }

    // MARK: - 결과 뷰

    private func resultView(session: SessionResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                summaryCard(session: session)

                ForEach(Array(session.throws_.enumerated()), id: \.element.id) { index, throwAnalysis in
                    NavigationLink(
                        destination: ThrowDetailView(
                            throwAnalysis: throwAnalysis,
                            videoURL: videoURL,
                            fps: session.fps
                        )
                    ) {
                        throwCard(throwAnalysis: throwAnalysis)
                    }
                    .buttonStyle(CardPressStyle())
                    .opacity(throwsAppeared ? 1 : 0)
                    .offset(y: throwsAppeared ? 0 : 26)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.82)
                            .delay(Double(index) * 0.1 + 0.05),
                        value: throwsAppeared
                    )
                }

                if !viewModel.feedback.isEmpty {
                    feedbackSection
                        .opacity(throwsAppeared ? 1 : 0)
                        .offset(y: throwsAppeared ? 0 : 18)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.82)
                                .delay(Double(session.throws_.count) * 0.1 + 0.1),
                            value: throwsAppeared
                        )
                }
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            throwsAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                throwsAppeared = true
            }
        }
    }

    // MARK: - Summary Card

    private func summaryCard(session: SessionResult) -> some View {
        HStack(spacing: 0) {
            DPStatCell(value: "\(session.totalThrowsDetected)", label: "투구 수",    icon: "figure.cooldown",  color: .cyan)
            statDivider()
            DPStatCell(value: "\(session.totalFrames)",          label: "총 프레임",  icon: "film",             color: .dpBlue)
            statDivider()
            DPStatCell(value: String(format: "%.0f", session.fps), label: "FPS",   icon: "speedometer",      color: .dpPurple)
        }
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.12), Color.dpBlue.opacity(0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.28), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private func statDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 44)
    }

    // MARK: - Throw Card

    private func throwCard(throwAnalysis: ThrowAnalysis) -> some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 14) {
                // Number badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.18), Color.dpBlue.opacity(0.10)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Text("\(throwAnalysis.throwIndex)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("투구 #\(throwAnalysis.throwIndex)")
                        .font(.subheadline.bold())
                        .foregroundColor(.dpTextPrimary)

                    HStack(spacing: 6) {
                        Label(
                            throwAnalysis.throwingArm == "right" ? "오른손" : "왼손",
                            systemImage: "hand.raised"
                        )
                        .font(.caption)
                        .foregroundColor(.dpTextMuted)

                        Text("·")
                            .foregroundColor(.dpTextMuted.opacity(0.5))

                        Text("F \(throwAnalysis.frameRange[0])–\(throwAnalysis.frameRange[1])")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.dpTextMuted)
                    }
                }

                Spacer()

                // Takeback angle quick-stat
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.1f°", throwAnalysis.metrics.takebackAngleDeg))
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundColor(.cyan)
                    Text("테이크백")
                        .font(.system(size: 9))
                        .foregroundColor(.dpTextMuted)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.dpTextMuted.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Issue tags row (only if issues exist)
            if !throwAnalysis.issues.isEmpty {
                Divider()
                    .background(Color.dpBorder)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange.opacity(0.6))

                        ForEach(throwAnalysis.issues.prefix(4), id: \.self) { issue in
                            DPIssueTag(label: dpIssueLabel(issue))
                        }

                        if throwAnalysis.issues.count > 4 {
                            Text("+\(throwAnalysis.issues.count - 4)")
                                .font(.system(size: 10))
                                .foregroundColor(.dpTextMuted)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dpSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            throwAnalysis.issues.isEmpty
                                ? Color.dpBorder
                                : Color.orange.opacity(0.18),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DPSectionHeader(
                title: "AI 코칭 피드백",
                subtitle: "분석 기반 맞춤 개선 사항",
                systemImage: "text.bubble.fill",
                accentColor: .cyan
            )

            Text(viewModel.feedback)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.dpTextPrimary.opacity(0.82))
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.dpSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.cyan.opacity(0.10), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.10))
                    .frame(width: 84, height: 84)
                Circle()
                    .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                    .frame(width: 84, height: 84)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 8) {
                Text("분석 실패")
                    .font(.title3.bold())
                    .foregroundColor(.dpTextPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.dpTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task {
                    viewModel.reset()
                    await viewModel.startAnalysis(videoURL: videoURL)
                }
            } label: {
                Label("다시 시도", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.cyan, Color.dpBlue], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(CardPressStyle())
        }
    }
}

// MARK: - Analysis Loading View

private struct AnalysisLoadingView: View {
    let state: AnalysisState

    @State private var pulse = false
    @State private var spinnerRotation: Double = 0

    var body: some View {
        VStack(spacing: 44) {
            Spacer()

            // Pulsing rings + icon
            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(pulse ? 0.04 : 0.16), lineWidth: 1)
                    .frame(width: 172, height: 172)
                    .scaleEffect(pulse ? 1.13 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4),
                        value: pulse
                    )

                Circle()
                    .stroke(Color.cyan.opacity(pulse ? 0.07 : 0.24), lineWidth: 1.5)
                    .frame(width: 124, height: 124)
                    .scaleEffect(pulse ? 1.09 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.3).repeatForever(autoreverses: true).delay(0.2),
                        value: pulse
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.13), Color.dpBlue.opacity(0.07)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulse ? 1.05 : 0.96)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulse
                    )

                Image(systemName: iconName)
                    .font(.system(size: 30))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, Color.dpBlue], startPoint: .top, endPoint: .bottom)
                    )
                    .scaleEffect(pulse ? 1.04 : 0.96)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
            .onAppear { pulse = true }

            // Text
            VStack(spacing: 10) {
                Text(titleText)
                    .font(.title3.bold())
                    .foregroundColor(.dpTextPrimary)
                    .id("title-\(titleText)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(.dpTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .id("sub-\(subtitleText)")
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.3), value: titleText)

            // Pipeline
            pipelineView

            Spacer()
        }
    }

    // MARK: - Pipeline

    private var pipelineView: some View {
        HStack(spacing: 0) {
            pipelineBubble(index: 0, label: "포즈 추출")
            pipelineConnector(filled: currentStep > 0)
            pipelineBubble(index: 1, label: "동작 분석")
            pipelineConnector(filled: currentStep > 1)
            pipelineBubble(index: 2, label: "피드백")
        }
        .padding(.horizontal, 28)
    }

    private func pipelineBubble(index: Int, label: String) -> some View {
        let isActive = currentStep == index
        let isDone   = currentStep > index

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone
                        ? Color.cyan
                        : (isActive ? Color.cyan.opacity(0.17) : Color.dpSurface)
                    )
                    .frame(width: 34, height: 34)
                    .shadow(color: isDone ? .cyan.opacity(0.38) : .clear, radius: 6)

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.08))
                } else if isActive {
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(spinnerRotation))
                        .onAppear {
                            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                                spinnerRotation = 360
                            }
                        }
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.dpTextMuted)
                }
            }

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(isDone || isActive ? .dpTextPrimary.opacity(0.75) : .dpTextMuted.opacity(0.38))
        }
    }

    private func pipelineConnector(filled: Bool) -> some View {
        VStack {
            Rectangle()
                .fill(filled ? Color.cyan.opacity(0.44) : Color.dpBorder)
                .frame(height: 1.5)
                .animation(.easeInOut(duration: 0.4), value: filled)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 22)
    }

    // MARK: - Helpers

    private var currentStep: Int {
        switch state {
        case .extractingPoses:    return 0
        case .analyzing:          return 1
        case .generatingFeedback: return 2
        default:                  return -1
        }
    }

    private var iconName: String {
        switch state {
        case .extractingPoses:    return "figure.walk"
        case .analyzing:          return "waveform.path.ecg"
        case .generatingFeedback: return "text.bubble"
        default:                  return "hourglass"
        }
    }

    private var titleText: String {
        switch state {
        case .extractingPoses:    return "포즈 추출 중..."
        case .analyzing:          return "투구 분석 중..."
        case .generatingFeedback: return "피드백 생성 중..."
        default:                  return "준비 중..."
        }
    }

    private var subtitleText: String {
        switch state {
        case .extractingPoses:    return "영상에서 관절 좌표를 추출하고 있습니다"
        case .analyzing:          return "투구 구간 분리 및 생체역학 분석 중"
        case .generatingFeedback: return "AI 코칭 피드백을 작성하고 있습니다"
        default:                  return "잠시만 기다려주세요"
        }
    }
}
