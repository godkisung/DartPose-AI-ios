// ResultDetailView.swift
// 투구별 상세 결과 화면
//
// 단일 투구의 10가지 생체역학 메트릭을 시각화합니다.
// 게이지 형태로 각 지표의 상태를 직관적으로 보여줍니다.

import SwiftUI

/// 투구 상세 결과 화면.
/// 10가지 생체역학 메트릭을 게이지와 수치로 표시합니다.
struct ResultDetailView: View {
    let throwAnalysis: ThrowAnalysis

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 헤더
                headerSection

                // 안정성 지표
                metricsSection(
                    title: "🛡️ 안정성",
                    metrics: [
                        MetricItem(
                            name: "팔꿈치 드리프트",
                            value: throwAnalysis.metrics.elbowDriftNorm,
                            format: "%.4f",
                            unit: "",
                            thresholdGreen: DartConfig.elbowStabilityThreshold,
                            isLowerBetter: true
                        ),
                        MetricItem(
                            name: "어깨 안정성",
                            value: throwAnalysis.metrics.shoulderStability,
                            format: "%.4f",
                            unit: "",
                            thresholdGreen: DartConfig.shoulderStabilityThreshold,
                            isLowerBetter: true
                        ),
                        MetricItem(
                            name: "상체 흔들림",
                            value: throwAnalysis.metrics.bodySway,
                            format: "%.4f",
                            unit: "",
                            thresholdGreen: DartConfig.bodySwayThreshold,
                            isLowerBetter: true
                        ),
                    ]
                )

                // 각도 지표
                metricsSection(
                    title: "📐 각도",
                    metrics: [
                        MetricItem(
                            name: "테이크백 각도",
                            value: throwAnalysis.metrics.takebackAngleDeg,
                            format: "%.1f",
                            unit: "°",
                            idealRange: DartConfig.takebackMinAngle...DartConfig.takebackMaxAngle
                        ),
                        MetricItem(
                            name: "릴리즈 각도",
                            value: throwAnalysis.metrics.releaseAngleDeg,
                            format: "%.1f",
                            unit: "°"
                        ),
                        MetricItem(
                            name: "팔로스루 각도",
                            value: throwAnalysis.metrics.followThroughAngleDeg,
                            format: "%.1f",
                            unit: "°"
                        ),
                    ]
                )

                // 속도/타이밍 지표
                metricsSection(
                    title: "⚡ 속도 & 타이밍",
                    metrics: [
                        MetricItem(
                            name: "최대 팔꿈치 속도",
                            value: throwAnalysis.metrics.maxElbowVelocityDegS,
                            format: "%.0f",
                            unit: "°/s",
                            thresholdGreen: DartConfig.elbowExtensionVelMin,
                            isLowerBetter: false
                        ),
                        MetricItem(
                            name: "릴리즈 타이밍",
                            value: throwAnalysis.metrics.releaseTimingMs,
                            format: "%.0f",
                            unit: "ms"
                        ),
                        MetricItem(
                            name: "손가락 속도",
                            value: throwAnalysis.metrics.fingerReleaseSpeed,
                            format: "%.2f",
                            unit: ""
                        ),
                    ]
                )

                // 일관성 점수
                if throwAnalysis.metrics.consistencyScore > 0 {
                    consistencySection
                }

                // Phase 정보
                phaseSection
            }
            .padding(.vertical, 16)
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.15).ignoresSafeArea())
        .navigationTitle("투구 #\(throwAnalysis.throwIndex)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 헤더

    private var headerSection: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("#\(throwAnalysis.throwIndex)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                Text("투구 번호")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            VStack(spacing: 4) {
                Text(throwAnalysis.throwingArm == "right" ? "오른손" : "왼손")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("투구 팔")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            VStack(spacing: 4) {
                Text("\(throwAnalysis.frameRange[1] - throwAnalysis.frameRange[0])")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("프레임")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 메트릭 섹션

    private func metricsSection(title: String, metrics: [MetricItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(metrics) { metric in
                    metricRow(metric: metric)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, 16)
        }
    }

    /// 메트릭 행
    private func metricRow(metric: MetricItem) -> some View {
        HStack {
            // 상태 인디케이터
            Circle()
                .fill(metric.statusColor)
                .frame(width: 8, height: 8)

            Text(metric.name)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(String(format: metric.format, metric.value) + metric.unit)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.cyan)
                .fontWeight(.semibold)
        }
    }

    // MARK: - 일관성 섹션

    private var consistencySection: some View {
        VStack(spacing: 8) {
            Text("🎯 일관성 점수")
                .font(.headline)
                .foregroundColor(.white)

            Text(String(format: "%.1f", throwAnalysis.metrics.consistencyScore))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(consistencyColor)

            Text("/ 100")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, 16)
    }

    /// 일관성 색상
    private var consistencyColor: Color {
        let score = throwAnalysis.metrics.consistencyScore
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .orange
    }

    // MARK: - Phase 섹션

    private var phaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Phase 경계")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                phaseRow(name: "Address", frame: throwAnalysis.phases.address, color: .blue)
                phaseRow(name: "Takeback 시작", frame: throwAnalysis.phases.takebackStart, color: .cyan)
                phaseRow(name: "Takeback 정점", frame: throwAnalysis.phases.takebackMax, color: .green)
                phaseRow(name: "Release", frame: throwAnalysis.phases.release, color: .orange)
                phaseRow(name: "Follow-through", frame: throwAnalysis.phases.followThrough, color: .red)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, 16)
        }
    }

    /// Phase 행
    private func phaseRow(name: String, frame: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text("Frame \(frame)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - MetricItem 모델

/// 메트릭 표시용 데이터 모델
struct MetricItem: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let format: String
    let unit: String
    var thresholdGreen: Double? = nil
    var isLowerBetter: Bool = true
    var idealRange: ClosedRange<Double>? = nil

    /// 상태에 따른 인디케이터 색상
    var statusColor: Color {
        if let range = idealRange {
            return range.contains(value) ? .green : .orange
        }
        if let threshold = thresholdGreen {
            if isLowerBetter {
                return value <= threshold ? .green : .orange
            } else {
                return value >= threshold ? .green : .orange
            }
        }
        return .gray
    }
}
