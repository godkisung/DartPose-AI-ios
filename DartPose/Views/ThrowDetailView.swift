// ThrowDetailView.swift
// 투구 상세 화면 — AVKit 영상 재생 + Swift Charts 각도 시각화 + 생체역학 메트릭

import SwiftUI
import AVKit
import Charts

// MARK: - Chart Data Model

struct AngleDataPoint: Identifiable {
    let id = UUID()
    let phase: String
    let angle: Double
}

// MARK: - ThrowDetailView

struct ThrowDetailView: View {
    let throwAnalysis: ThrowAnalysis
    let videoURL: URL
    let fps: Double

    @State private var selectedPhase: String = "release"
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    @State private var chartAnimated = false

    // Throw segment time range (seconds)
    private var throwStartSec: Double { Double(throwAnalysis.frameRange[0]) / max(fps, 1) }
    private var throwEndSec: Double   { Double(throwAnalysis.frameRange[1]) / max(fps, 1) }
    private var throwDuration: Double { throwEndSec - throwStartSec }

    // Chart data: 3 key-phase angles
    private var angleChartData: [AngleDataPoint] {
        [
            AngleDataPoint(phase: "테이크백", angle: throwAnalysis.metrics.takebackAngleDeg),
            AngleDataPoint(phase: "릴리즈",   angle: throwAnalysis.metrics.releaseAngleDeg),
            AngleDataPoint(phase: "팔로스루", angle: throwAnalysis.metrics.followThroughAngleDeg),
        ]
    }

    var body: some View {
        ZStack {
            DPAnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    if !throwAnalysis.issues.isEmpty {
                        issuesSection
                    }
                    videoSection
                    angleChartSection
                    skeletonSection
                    metricsSection(title: "🛡️ 안정성",      metrics: stabilityMetrics)
                    metricsSection(title: "📐 각도",          metrics: angleMetrics)
                    metricsSection(title: "⚡ 속도 & 타이밍", metrics: velocityMetrics)
                    if throwAnalysis.metrics.consistencyScore > 0 {
                        consistencySection
                    }
                    phaseSection
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("투구 #\(throwAnalysis.throwIndex)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupPlayer()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.35)) {
                chartAnimated = true
            }
        }
        .onDisappear {
            player?.pause()
            playerLooper = nil
            player = nil
        }
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let asset        = AVURLAsset(url: videoURL)
        let templateItem = AVPlayerItem(asset: asset)
        let queuePlayer  = AVQueuePlayer()
        let start = CMTime(seconds: throwStartSec, preferredTimescale: 600)
        let end   = CMTime(seconds: throwEndSec,   preferredTimescale: 600)
        let looper = AVPlayerLooper(
            player: queuePlayer, templateItem: templateItem,
            timeRange: CMTimeRange(start: start, end: end)
        )
        self.player       = queuePlayer
        self.playerLooper = looper
        queuePlayer.play()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 0) {
            headerCell(value: "#\(throwAnalysis.throwIndex)", label: "투구", gradient: true)
            headerDivider()
            headerCell(value: throwAnalysis.throwingArm == "right" ? "오른손" : "왼손", label: "투구 팔")
            headerDivider()
            headerCell(value: "\(throwAnalysis.frameRange[1] - throwAnalysis.frameRange[0])", label: "프레임")
            headerDivider()
            headerCell(value: String(format: "%.2fs", throwDuration), label: "구간")
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.11), Color.dpBlue.opacity(0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.38), Color.dpBlue.opacity(0.18)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 16)
    }

    private func headerCell(value: String, label: String, gradient: Bool = false) -> some View {
        VStack(spacing: 4) {
            if gradient {
                Text(value)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, Color.dpBlue], startPoint: .top, endPoint: .bottom)
                    )
            } else {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.dpTextPrimary)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.dpTextMuted)
                .tracking(1.2)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private func headerDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 40)
    }

    // MARK: - Issues Section

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DPSectionHeader(
                title: "⚠️ 감지된 이슈",
                subtitle: "\(throwAnalysis.issues.count)개 항목이 개선을 권장합니다",
                systemImage: nil,
                accentColor: .orange
            )

            FlowLayout(spacing: 8) {
                ForEach(throwAnalysis.issues, id: \.self) { issue in
                    DPIssueTag(label: dpIssueLabel(issue), color: .orange)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Video Section

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DPSectionHeader(
                title: "🎬 투구 영상",
                subtitle: "해당 구간 자동 반복 재생",
                systemImage: nil
            )

            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                    .padding(.horizontal, 16)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.dpSurface)
                    .frame(height: 220)
                    .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .cyan)))
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 16) {
                Label(
                    String(format: "%.2fs ~ %.2fs", throwStartSec, throwEndSec),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundColor(.dpTextMuted)

                Spacer()

                Label(
                    "\(throwAnalysis.frameRange[1] - throwAnalysis.frameRange[0]) 프레임",
                    systemImage: "film"
                )
                .font(.caption)
                .foregroundColor(.dpTextMuted)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Angle Chart Section

    private var angleChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DPSectionHeader(
                title: "📈 각도 변화",
                subtitle: "Phase별 관절 각도 (°) · 점선: 권장 범위",
                systemImage: nil
            )

            VStack(spacing: 0) {
                Chart {
                    // Ideal range band (takebackMin – takebackMax as horizontal guides)
                    RuleMark(y: .value("권장 최소", DartConfig.takebackMinAngle))
                        .foregroundStyle(Color.dpTeal.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .leading, alignment: .bottom) {
                            Text("\(Int(DartConfig.takebackMinAngle))°")
                                .font(.system(size: 9))
                                .foregroundColor(.dpTeal.opacity(0.7))
                        }

                    RuleMark(y: .value("권장 최대", DartConfig.takebackMaxAngle))
                        .foregroundStyle(Color.dpTeal.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .leading, alignment: .top) {
                            Text("\(Int(DartConfig.takebackMaxAngle))°")
                                .font(.system(size: 9))
                                .foregroundColor(.dpTeal.opacity(0.7))
                        }

                    // Data — area fill
                    ForEach(angleChartData) { point in
                        AreaMark(
                            x: .value("Phase", point.phase),
                            y: .value("각도 (°)", chartAnimated ? point.angle : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.28), Color.dpBlue.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Data — line
                    ForEach(angleChartData) { point in
                        LineMark(
                            x: .value("Phase", point.phase),
                            y: .value("각도 (°)", chartAnimated ? point.angle : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, Color.dpBlue],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }

                    // Data — points with annotations
                    ForEach(angleChartData) { point in
                        PointMark(
                            x: .value("Phase", point.phase),
                            y: .value("각도 (°)", chartAnimated ? point.angle : 0)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(52)
                        .annotation(position: .top, spacing: 4) {
                            Text(String(format: "%.1f°", point.angle))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.07))
                        AxisValueLabel()
                            .foregroundStyle(Color.dpTextMuted)
                            .font(.system(size: 10))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.dpTextSecondary)
                            .font(.system(size: 11))
                    }
                }
                .frame(height: 200)
                .animation(.spring(response: 0.8, dampingFraction: 0.72), value: chartAnimated)
                .padding(.top, 20)
                .padding(.bottom, 8)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .glassCard(cornerRadius: 14)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Skeleton Section

    private var skeletonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DPSectionHeader(title: "🦴 포즈 스켈레톤", subtitle: "Phase별 관절 포즈")

            Picker("Phase", selection: $selectedPhase) {
                Text("Address").tag("address")
                Text("테이크백").tag("takebackMax")
                Text("릴리즈").tag("release")
                Text("팔로스루").tag("followThrough")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.dpBorder, lineWidth: 1)
                    )

                if let kp = throwAnalysis.phaseKeypoints[selectedPhase] {
                    SkeletonCanvasView(keypoints: kp, throwingArm: throwAnalysis.throwingArm)
                        .padding(12)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 36))
                            .foregroundColor(.dpTextMuted.opacity(0.4))
                        Text("포즈 데이터 없음")
                            .font(.caption)
                            .foregroundColor(.dpTextMuted)
                    }
                }
            }
            .frame(height: 240)
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.22), value: selectedPhase)

            Text(phaseLabel(selectedPhase))
                .font(.caption)
                .foregroundColor(.dpTextMuted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func phaseLabel(_ phase: String) -> String {
        switch phase {
        case "address":       return "Address — 조준 시작"
        case "takebackMax":   return "Takeback Max — 팔꿈치 최대 굽힘"
        case "release":       return "Release — 다트 릴리즈 순간"
        case "followThrough": return "Follow-through — 팔 완전히 펴짐"
        default:              return phase
        }
    }

    // MARK: - Metrics Data

    private var stabilityMetrics: [MetricItem] {[
        MetricItem(name: "팔꿈치 드리프트", value: throwAnalysis.metrics.elbowDriftNorm,
                   format: "%.4f", unit: "",
                   thresholdGreen: DartConfig.elbowStabilityThreshold, isLowerBetter: true),
        MetricItem(name: "어깨 안정성", value: throwAnalysis.metrics.shoulderStability,
                   format: "%.4f", unit: "",
                   thresholdGreen: DartConfig.shoulderStabilityThreshold, isLowerBetter: true),
        MetricItem(name: "상체 흔들림", value: throwAnalysis.metrics.bodySway,
                   format: "%.4f", unit: "",
                   thresholdGreen: DartConfig.bodySwayThreshold, isLowerBetter: true),
    ]}

    private var angleMetrics: [MetricItem] {[
        MetricItem(name: "테이크백 각도", value: throwAnalysis.metrics.takebackAngleDeg,
                   format: "%.1f", unit: "°",
                   idealRange: DartConfig.takebackMinAngle...DartConfig.takebackMaxAngle),
        MetricItem(name: "릴리즈 각도", value: throwAnalysis.metrics.releaseAngleDeg,
                   format: "%.1f", unit: "°"),
        MetricItem(name: "팔로스루 각도", value: throwAnalysis.metrics.followThroughAngleDeg,
                   format: "%.1f", unit: "°"),
    ]}

    private var velocityMetrics: [MetricItem] {[
        MetricItem(name: "최대 팔꿈치 속도", value: throwAnalysis.metrics.maxElbowVelocityDegS,
                   format: "%.0f", unit: "°/s",
                   thresholdGreen: DartConfig.elbowExtensionVelMin, isLowerBetter: false),
        MetricItem(name: "릴리즈 타이밍", value: throwAnalysis.metrics.releaseTimingMs,
                   format: "%.0f", unit: "ms"),
        MetricItem(name: "손가락 속도", value: throwAnalysis.metrics.fingerReleaseSpeed,
                   format: "%.2f", unit: ""),
    ]}

    // MARK: - Metrics Section

    private func metricsSection(title: String, metrics: [MetricItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.dpTextPrimary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                    metricRow(metric: metric)
                    if index < metrics.count - 1 {
                        Divider()
                            .background(Color.dpBorder)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .glassCard(cornerRadius: 14)
            .padding(.horizontal, 16)
        }
    }

    private func metricRow(metric: MetricItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(metric.statusColor.opacity(0.16))
                    .frame(width: 20, height: 20)
                Circle()
                    .fill(metric.statusColor)
                    .frame(width: 8, height: 8)
            }

            Text(metric.name)
                .font(.subheadline)
                .foregroundColor(.dpTextPrimary.opacity(0.85))

            Spacer()

            Text(String(format: metric.format, metric.value) + metric.unit)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundColor(.cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Consistency Section

    private var consistencySection: some View {
        VStack(spacing: 16) {
            DPSectionHeader(title: "🎯 일관성 점수", subtitle: "투구 간 동작 유사도")

            DPScoreRing(
                score: throwAnalysis.metrics.consistencyScore,
                size: 130,
                lineWidth: 13
            )
            .animation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.2), value: chartAnimated)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    // MARK: - Phase Section

    private var phaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DPSectionHeader(title: "📊 Phase 경계", subtitle: "프레임 인덱스 / 타임스탬프")

            VStack(spacing: 0) {
                phaseRow(name: "Address",         frame: throwAnalysis.phases.address,        icon: "scope",                     color: .blue)
                phaseDivider()
                phaseRow(name: "Takeback 시작",    frame: throwAnalysis.phases.takebackStart,  icon: "arrow.backward.circle",     color: .cyan)
                phaseDivider()
                phaseRow(name: "Takeback 정점",    frame: throwAnalysis.phases.takebackMax,    icon: "arrow.up.circle.fill",      color: .dpTeal)
                phaseDivider()
                phaseRow(name: "Release",          frame: throwAnalysis.phases.release,        icon: "bolt.circle.fill",          color: .orange)
                phaseDivider()
                phaseRow(name: "Follow-through",   frame: throwAnalysis.phases.followThrough,  icon: "arrow.forward.circle.fill", color: .red)
            }
            .glassCard(cornerRadius: 14)
            .padding(.horizontal, 16)
        }
    }

    private func phaseRow(name: String, frame: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.body)
                .frame(width: 22)

            Text(name)
                .font(.subheadline)
                .foregroundColor(.dpTextPrimary.opacity(0.85))

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("Frame \(frame)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.dpTextSecondary)
                Text(String(format: "%.2fs", Double(frame) / max(fps, 1)))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.dpTextMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func phaseDivider() -> some View {
        Divider()
            .background(Color.dpBorder)
            .padding(.horizontal, 16)
    }
}

// MARK: - Flow Layout (wrapping tag cloud)

/// Horizontally wrapping layout for issue tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin   = CGPoint.zero
        var maxY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            origin.x += size.width + spacing
            maxY = max(maxY, origin.y + rowHeight)
        }
        return CGSize(width: maxWidth, height: maxY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x  = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            origin.x += size.width + spacing
        }
    }
}
