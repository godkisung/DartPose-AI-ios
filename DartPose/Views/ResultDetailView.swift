// ResultDetailView.swift
// 투구별 상세 결과 화면
//
// 단일 투구의 10가지 생체역학 메트릭을 시각화합니다.
// 게이지 형태로 각 지표의 상태를 직관적으로 보여줍니다.

import SwiftUI

/// 투구 상세 결과 화면.
/// 10가지 생체역학 메트릭과 스켈레톤 오버레이를 표시합니다.
struct ResultDetailView: View {
    let throwAnalysis: ThrowAnalysis

    /// 스켈레톤 뷰에서 선택된 Phase
    @State private var selectedPhase: String = "release"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 헤더
                headerSection

                // ✅ 스켈레톤 시각화 (Phase별 포즈 오버레이)
                skeletonSection

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

    // MARK: - 스켈레톤 시각화

    private var skeletonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🦴 포즈 스켈레톤")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            // Phase 선택 Picker
            Picker("Phase", selection: $selectedPhase) {
                Text("Address").tag("address")
                Text("테이크백").tag("takebackMax")
                Text("릴리즈").tag("release")
                Text("팔로스루").tag("followThrough")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            // 스켈레톤 Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))

                if let kp = throwAnalysis.phaseKeypoints[selectedPhase] {
                    SkeletonCanvasView(
                        keypoints: kp,
                        throwingArm: throwAnalysis.throwingArm
                    )
                    .padding(12)
                    .onAppear {
                        let dict = kp.toDict()
                        print("UI: Skeleton keypoints for phase '\(selectedPhase)': \(dict.count) joints, keys=\(dict.keys.sorted().joined(separator: ","))")
                    }
                } else {
                    Text("포즈 데이터 없음")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .onAppear {
                            print("UI: No skeleton keypoints for phase '\(selectedPhase)' — phaseKeypoints keys: \(throwAnalysis.phaseKeypoints.keys.sorted().joined(separator: ","))")
                        }
                }
            }
            .frame(height: 240)
            .padding(.horizontal, 16)

            // Phase 라벨
            Text(phaseLabel(selectedPhase))
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func phaseLabel(_ phase: String) -> String {
        switch phase {
        case "address":      return "Address — 조준 시작"
        case "takebackMax":  return "Takeback Max — 팔꿈치 최대 굽힘"
        case "release":      return "Release — 다트 릴리즈 순간"
        case "followThrough": return "Follow-through — 팔 완전히 펴짐"
        default:             return phase
        }
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

// MARK: - 스켈레톤 Canvas View

/// 관절 좌표를 받아 스틱 피겨를 그리는 SwiftUI Canvas 뷰.
/// Vision의 정규화 좌표(0~1, Y↓)를 캔버스 크기에 맞게 스케일링합니다.
struct SkeletonCanvasView: View {

    let keypoints: Keypoints
    let throwingArm: String

    // 그릴 뼈대(bone) 연결 목록: (시작관절, 끝관절, 색상)
    private var bones: [(String, String, Color)] {
        let arm = throwingArm
        let off = arm == "right" ? "left" : "right"
        return [
            // 몸통
            ("leftShoulder",  "rightShoulder", .gray),
            ("leftHip",       "rightHip",      .gray),
            ("\(arm)Shoulder", "\(arm)Hip",    .gray),
            ("\(off)Shoulder", "\(off)Hip",    .gray),
            // 비투구 팔 (흰색)
            ("\(off)Shoulder", "\(off)Elbow",  .white.opacity(0.5)),
            ("\(off)Elbow",    "\(off)Wrist",  .white.opacity(0.5)),
            // 투구 팔 (시안 — 강조)
            ("\(arm)Shoulder", "\(arm)Elbow",  .cyan),
            ("\(arm)Elbow",    "\(arm)Wrist",  .cyan),
        ]
    }

    var body: some View {
        Canvas { context, size in
            let kpDict = keypoints.toDict()

            /// 관절 이름 → Canvas 좌표 변환
            func pt(_ name: String) -> CGPoint? {
                guard let coords = kpDict[name],
                      coords.count >= 2,
                      coords[0] != 0 || coords[1] != 0 else { return nil }
                return CGPoint(
                    x: coords[0] * size.width,
                    y: coords[1] * size.height   // Y는 이미 ↓ 방향으로 저장됨
                )
            }

            // 뼈대 선 그리기
            for (from, to, color) in bones {
                guard let p1 = pt(from), let p2 = pt(to) else { continue }
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(path, with: .color(color), lineWidth: 3)
            }

            // 관절 점 그리기
            let joints = ["leftShoulder", "rightShoulder",
                          "leftElbow",    "rightElbow",
                          "leftWrist",    "rightWrist",
                          "leftHip",      "rightHip"]
            for name in joints {
                guard let p = pt(name) else { continue }
                let isThrowingArm = name.hasPrefix(throwingArm)
                let radius: CGFloat = isThrowingArm ? 6 : 4
                let fillColor: Color = isThrowingArm ? .cyan : .white.opacity(0.7)
                let rect = CGRect(
                    x: p.x - radius, y: p.y - radius,
                    width: radius * 2, height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(fillColor))
            }
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
