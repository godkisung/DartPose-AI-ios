// DartAnalyzer.swift
// 다트 투구 분석 통합 엔진
//
// ThrowSegmenter, PhaseDetector, PoseNormalizer, MetricsCalculator를
// 조율하여 전체 분석 파이프라인을 실행합니다.
//
// 파이프라인:
//   [FrameData] → PoseNormalizer → ThrowSegmenter → PhaseDetector
//              → MetricsCalculator → SessionResult
//
// Python dart_analyzer.py (367줄) → Swift 포팅

import Foundation

/// 다트 투구 분석 통합 엔진.
///
/// 사용 예시:
/// ```swift
/// let analyzer = DartAnalyzer(fps: 30)
/// let session = analyzer.analyzeSession(frames: frames)
/// ```
class DartAnalyzer {

    let fps: Double
    private let normalizer: PoseNormalizer
    private let segmenter: ThrowSegmenter
    private let phaseDetector: PhaseDetector
    private let metricsCalc: MetricsCalculator

    /// 초기화
    /// - Parameter fps: 입력 영상의 프레임레이트
    init(fps: Double = 30.0) {
        self.fps = fps
        self.normalizer = PoseNormalizer()
        self.segmenter = ThrowSegmenter(fps: fps)
        self.phaseDetector = PhaseDetector(fps: fps)
        self.metricsCalc = MetricsCalculator(fps: fps)
    }

    // MARK: - Public API

    /// 전체 세션(연속 영상)을 분석하여 SessionResult를 반환합니다.
    ///
    /// - Parameter frames: PoseExtractor에서 추출된 FrameData 리스트
    /// - Returns: 세션 전체 분석 결과
    func analyzeSession(frames: [FrameData]) -> SessionResult {
        // keypoints가 있는 유효 프레임만 사용
        let validFrames = frames.filter { $0.keypoints != nil }

        guard validFrames.count >= DartConfig.throwMinFrames else {
            print("  ⚠ 유효 프레임 부족 (\(validFrames.count)개) — 분석 중단")
            return SessionResult(
                totalFrames: frames.count,
                fps: fps,
                totalThrowsDetected: 0
            )
        }

        // Step 1: 투구 팔 자동 감지
        let throwingSide = detectThrowingSide(frames: validFrames)
        print("  ℹ 투구 팔: \(throwingSide)")

        // Step 2: 좌표 정규화 (전체 세션)
        let normalizedData = normalizer.normalize(
            frames: validFrames, throwingSide: throwingSide
        )

        // Step 3: 투구 세그먼트 분리
        let segments = segmenter.segment(
            frames: validFrames,
            normalizedData: normalizedData,
            throwingSide: throwingSide
        )
        print("  ℹ 세그먼트 후보: \(segments.count)개")

        // Step 4: 각 세그먼트 분석
        var analyses: [ThrowAnalysis] = []
        for (i, segment) in segments.enumerated() {
            print("  → 세그먼트 \(i+1) 분석 중... (프레임 \(segment[0].frameIndex)~\(segment[segment.count-1].frameIndex))")

            guard let analysis = analyzeSingleThrow(
                frames: segment, side: throwingSide, throwIndex: analyses.count + 1
            ) else {
                print("    ✗ 분석 실패 — 건너뜀")
                continue
            }

            // 유효성 검증
            let (isValid, reason) = validateThrow(
                analysis: analysis, frames: segment, side: throwingSide
            )
            if isValid {
                analyses.append(analysis)
                print("    ✓ 투구 \(analyses.count) 확정")
            } else {
                print("    ✗ 기각 (\(reason))")
            }
        }

        // Step 5: 다중 투구 일관성 점수 계산
        if analyses.count >= 2 {
            let consistency = metricsCalc.computeConsistencyScore(analyses: analyses)
            for i in 0..<analyses.count {
                analyses[i].metrics.consistencyScore = (consistency * 10).rounded() / 10
            }
            print("  ℹ 일관성 점수: \(String(format: "%.1f", consistency))/100")
        }

        print("  ✅ 총 \(analyses.count)번 투구 감지 완료")

        return SessionResult(
            totalFrames: frames.count,
            fps: fps,
            totalThrowsDetected: analyses.count,
            throws_: analyses
        )
    }

    // MARK: - Single Throw Analysis

    /// 단일 투구 세그먼트를 분석합니다.
    private func analyzeSingleThrow(
        frames: [FrameData],
        side: String,
        throwIndex: Int
    ) -> ThrowAnalysis? {
        guard frames.count >= DartConfig.throwMinFrames else { return nil }

        // 세그먼트 단위로 정규화
        let normalized = normalizer.normalize(frames: frames, throwingSide: side)

        // 4-Phase 감지
        guard let phases = phaseDetector.detect(
            frames: frames, normalizedData: normalized, side: side
        ) else { return nil }

        // 메트릭 계산
        let metrics = metricsCalc.compute(
            frames: frames, normalizedData: normalized, phases: phases, side: side
        )

        return ThrowAnalysis(
            throwIndex: throwIndex,
            throwingArm: side,
            frameRange: [frames[0].frameIndex, frames[frames.count - 1].frameIndex],
            phases: phases,
            metrics: metrics
        )
    }

    // MARK: - Validation

    /// 분석 결과가 유효한 투구인지 검증합니다.
    private func validateThrow(
        analysis: ThrowAnalysis,
        frames: [FrameData],
        side: String
    ) -> (Bool, String) {
        let wristKey = "\(side)Wrist"

        // 손목 좌표 수집
        var wristCoords: [[Double]] = []
        for f in frames {
            if let kp = f.keypoints, let w = kp.get(wristKey) {
                wristCoords.append(Array(w.prefix(2)))
            }
        }

        guard wristCoords.count >= 5 else {
            return (false, "손목 좌표 부족")
        }

        // 검증 1: 손목 최대 변위
        let origin = wristCoords[0]
        let maxDisp = wristCoords.map { distance2D($0, origin) }.max() ?? 0.0
        if maxDisp < DartConfig.validationMinWristDisplacement {
            return (false, "변위 부족 (\(String(format: "%.3f", maxDisp)))")
        }

        // 검증 2: 릴리즈 타이밍 하한
        if analysis.metrics.releaseTimingMs < DartConfig.validationMinReleaseTimingMs {
            return (false, "릴리즈 타이밍 부족 (\(String(format: "%.0f", analysis.metrics.releaseTimingMs))ms)")
        }

        // 검증 3: 릴리즈 타이밍 상한
        if analysis.metrics.releaseTimingMs > DartConfig.validationMaxReleaseTimingMs {
            return (false, "릴리즈 타이밍 초과 (\(String(format: "%.0f", analysis.metrics.releaseTimingMs))ms)")
        }

        // 검증 4: ROM 필터
        let rom = abs(analysis.metrics.takebackAngleDeg - analysis.metrics.releaseAngleDeg)
        if rom < DartConfig.validationMinRomAngle {
            return (false, "ROM 부족 (\(String(format: "%.1f", rom))°)")
        }

        // 검증 5: 테이크백 최소 각도
        if analysis.metrics.takebackAngleDeg < DartConfig.validationMinTakebackAngle {
            return (false, "팔꿈치 굽힘 부족 (\(String(format: "%.1f", analysis.metrics.takebackAngleDeg))°)")
        }

        // 검증 6: 테이크백 최대 각도
        if analysis.metrics.takebackAngleDeg > DartConfig.validationMaxTakebackAngle {
            return (false, "테이크백 각도 미달 (\(String(format: "%.1f", analysis.metrics.takebackAngleDeg))°)")
        }

        // 검증 7: 각속도 상한
        if analysis.metrics.maxElbowVelocityDegS > DartConfig.validationMaxElbowVelocity {
            return (false, "비현실적인 각속도 (\(String(format: "%.0f", analysis.metrics.maxElbowVelocityDegS))°/s)")
        }

        // 검증 8: 각속도 하한
        if analysis.metrics.maxElbowVelocityDegS < DartConfig.validationMinElbowVelocity {
            return (false, "각속도 부족 (\(String(format: "%.0f", analysis.metrics.maxElbowVelocityDegS))°/s)")
        }

        return (true, "")
    }

    // MARK: - Throwing Side Detection

    /// 투구 팔(좌/우)을 자동 감지합니다 (3개 기준 다수결 투표).
    ///
    /// 1. Visibility: 투구 팔 관절의 평균 가시도
    /// 2. Depth (Z): 투구 팔이 카메라에 더 가까움
    /// 3. Variance: 투구 손목의 XY 분산이 더 큼
    func detectThrowingSide(frames: [FrameData]) -> String {
        let armJoints = ["Shoulder", "Elbow", "Wrist"]

        var rZ = [Double]()
        var lZ = [Double]()
        var rWristXY = [[Double]]()
        var lWristXY = [[Double]]()

        for f in frames {
            guard let kp = f.keypoints else { continue }
            for joint in armJoints {
                if let rc = kp.get("right\(joint)") {
                    rZ.append(rc.count >= 3 ? rc[2] : 0.0)
                }
                if let lc = kp.get("left\(joint)") {
                    lZ.append(lc.count >= 3 ? lc[2] : 0.0)
                }
            }
            if let rw = kp.get("rightWrist") { rWristXY.append(Array(rw.prefix(2))) }
            if let lw = kp.get("leftWrist") { lWristXY.append(Array(lw.prefix(2))) }
        }

        var votes = 0

        // 기준 1: Z축 깊이 (값이 작을수록 카메라에 가까움 = 투구 팔)
        if !rZ.isEmpty, !lZ.isEmpty {
            let rMean = rZ.reduce(0, +) / Double(rZ.count)
            let lMean = lZ.reduce(0, +) / Double(lZ.count)
            votes += rMean < lMean ? 1 : -1
        }

        // 기준 2: 손목 XY 분산
        if rWristXY.count >= 3, lWristXY.count >= 3 {
            let rVarX = variance(rWristXY.map { $0[0] })
            let rVarY = variance(rWristXY.map { $0[1] })
            let lVarX = variance(lWristXY.map { $0[0] })
            let lVarY = variance(lWristXY.map { $0[1] })
            votes += (rVarX + rVarY) > (lVarX + lVarY) ? 1 : -1
        }

        return votes >= 0 ? "right" : "left"
    }
}
