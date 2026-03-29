// MetricsCalculator.swift
// 메트릭 계산 모듈
//
// ThrowPhases와 정규화된 관절 좌표를 받아
// ThrowMetrics의 모든 필드를 계산합니다.
//
// Huang et al. (2024) 논문 기반 생체역학 지표:
// - 팔꿈치 드리프트, 어깨 안정성, 몸통 흔들림
// - 테이크백 각도, 릴리즈 각도, 팔로스루 각도
// - 최대 팔꿈치 확장 각속도, 릴리즈 타이밍
// - 손가락 스피드, 일관성 점수
//
// Python metrics_calculator.py (435줄) → Swift 포팅

import Foundation

/// 단일 투구의 생체역학 메트릭을 계산하는 클래스.
class MetricsCalculator {

    let fps: Double
    private let dt: Double
    private let normalizer: PoseNormalizer

    /// 초기화
    /// - Parameter fps: 영상 프레임레이트
    init(fps: Double = 30.0) {
        self.fps = fps
        self.dt = 1.0 / fps
        self.normalizer = PoseNormalizer()
    }

    // MARK: - Public API

    /// ThrowMetrics의 모든 필드를 계산합니다.
    ///
    /// ※ 핵심 설계: 메트릭 유형에 따라 좌표 소스를 구분합니다.
    /// - 각도 메트릭: 원시 keypoints 사용
    /// - 위치 메트릭: 정규화 좌표 사용
    func compute(
        frames: [FrameData],
        normalizedData: JointCoordDict,
        phases: ThrowPhases,
        side: String
    ) -> ThrowMetrics {
        let n = frames.count

        // 프레임 절대 인덱스 → 로컬 인덱스 매핑
        var frameIdxMap = [Int: Int]()
        for (i, f) in frames.enumerated() {
            frameIdxMap[f.frameIndex] = i
        }

        /// 절대 프레임 인덱스를 로컬 인덱스로 변환
        func localIdx(_ absFrame: Int) -> Int {
            if let idx = frameIdxMap[absFrame] { return idx }
            let closest = frameIdxMap.keys.min(by: { abs($0 - absFrame) < abs($1 - absFrame) }) ?? 0
            return frameIdxMap[closest] ?? 0
        }

        let addrI = localIdx(phases.address)
        let tbStartI = localIdx(phases.takebackStart)
        let tbMaxI = localIdx(phases.takebackMax)
        let relI = localIdx(phases.release)
        let ftI = localIdx(phases.followThrough)

        // 원시 좌표 (각도 메트릭용)
        let segmenter = ThrowSegmenter(fps: fps)
        let rawShoulder = segmenter.extractRawJointCoords(
            frames: frames, jointName: "\(side)Shoulder"
        ) ?? [[Double]](repeating: [0, 0, 0], count: n)
        let rawElbow = segmenter.extractRawJointCoords(
            frames: frames, jointName: "\(side)Elbow"
        ) ?? [[Double]](repeating: [0, 0, 0], count: n)
        let rawWrist = segmenter.extractRawJointCoords(
            frames: frames, jointName: "\(side)Wrist"
        ) ?? [[Double]](repeating: [0, 0, 0], count: n)
        let rawIndex = segmenter.extractRawJointCoords(
            frames: frames, jointName: "\(side)IndexTip"
        ) ?? [[Double]](repeating: [0, 0, 0], count: n)

        // 정규화 좌표 (위치 메트릭용)
        let normShoulder = normalizedData["\(side)Shoulder"]
            ?? [[Double]](repeating: [0, 0, 0], count: n)
        let normElbow = normalizedData["\(side)Elbow"]
            ?? [[Double]](repeating: [0, 0, 0], count: n)
        let normHip = normalizedData["\(side)Hip"]
            ?? [[Double]](repeating: [0, 0, 0], count: n)

        // 팔꿈치 각도 시계열 (원시 좌표 기반)
        var elbowAngles = [Double](repeating: 0, count: n)
        for i in 0..<n {
            elbowAngles[i] = angle3D(p1: rawShoulder[i], p2: rawElbow[i], p3: rawWrist[i])
        }

        // 1. 팔꿈치 드리프트 (정규화 좌표)
        let elbowDrift = computeElbowDrift(
            elbow: normElbow, shoulder: normShoulder, startI: addrI, endI: ftI
        )

        // 2. 어깨 안정성 (정규화 좌표)
        let shoulderStability = computeJointVariance(
            jointCoords: normShoulder, startI: addrI, endI: ftI
        )

        // 3. 몸통 흔들림 (정규화 좌표)
        let bodySway = computeBodySway(hip: normHip, startI: addrI, endI: relI)

        // 4. 테이크백 각도 (원시 좌표 기반)
        let takebackAngle = elbowAngles[tbMaxI] > 0 ? elbowAngles[tbMaxI] : 0.0

        // 5. 릴리즈 각도 (원시 좌표 기반)
        let releaseAngle = computeReleaseAngle(
            elbowAtRelease: rawElbow[relI], wristAtRelease: rawWrist[relI]
        )

        // 6. 팔로스루 각도 (원시 좌표 기반)
        let followThroughAngle = elbowAngles[ftI] > 0 ? elbowAngles[ftI] : 0.0

        // 7. 최대 팔꿈치 확장 각속도 (원시 좌표 기반)
        let maxElbowVelocity = computeMaxElbowVelocity(
            elbowAngles: elbowAngles, tbMaxI: tbMaxI, relI: relI
        )

        // 8. 릴리즈 타이밍 (ms)
        var timingMs = Double(relI - tbMaxI) * dt * 1000.0
        timingMs = max(timingMs, dt * 1000.0) // 방어: 최소 1프레임

        // 9. 손가락 릴리즈 스피드
        let hasFinger = !rawIndex.allSatisfy {
            $0[0] == 0 && $0[1] == 0 && $0[2] == 0
        }
        let fingerSpeed = hasFinger
            ? computeFingerSpeed(indexTip: rawIndex, relI: relI)
            : 0.0

        return ThrowMetrics(
            elbowDriftNorm: elbowDrift,
            shoulderStability: shoulderStability,
            bodySway: bodySway,
            takebackAngleDeg: takebackAngle,
            releaseAngleDeg: releaseAngle,
            followThroughAngleDeg: followThroughAngle,
            maxElbowVelocityDegS: maxElbowVelocity,
            releaseTimingMs: timingMs,
            fingerReleaseSpeed: fingerSpeed
        )
    }

    /// 세션 내 여러 투구 간 일관성 점수를 계산합니다 (0~100점).
    func computeConsistencyScore(analyses: [ThrowAnalysis]) -> Double {
        guard analyses.count >= 2 else { return 100.0 }

        /// 표준편차를 스케일로 정규화 (0~1)
        func normStd(_ values: [Double], scale: Double) -> Double {
            guard values.count >= 2 else { return 0.0 }
            return min(1.0, standardDeviation(values) / scale)
        }

        let takebackStd = normStd(
            analyses.filter { $0.metrics.takebackAngleDeg > 0 }
                    .map(\.metrics.takebackAngleDeg),
            scale: 20.0
        )
        let velocityStd = normStd(
            analyses.filter { $0.metrics.maxElbowVelocityDegS > 0 }
                    .map(\.metrics.maxElbowVelocityDegS),
            scale: 100.0
        )
        let timingStd = normStd(
            analyses.filter { $0.metrics.releaseTimingMs > 0 }
                    .map(\.metrics.releaseTimingMs),
            scale: 100.0
        )
        let releaseAngleStd = normStd(
            analyses.map(\.metrics.releaseAngleDeg),
            scale: 15.0
        )

        let inconsistency =
            takebackStd * 0.30 +
            velocityStd * 0.30 +
            timingStd * 0.20 +
            releaseAngleStd * 0.20

        return (1.0 - inconsistency) * 100.0
    }

    // MARK: - Private Metric Calculators

    /// 투구 중 팔꿈치 흔들림을 상완 길이로 정규화하여 계산합니다.
    private func computeElbowDrift(
        elbow: [[Double]],
        shoulder: [[Double]],
        startI: Int,
        endI: Int
    ) -> Double {
        let safeEnd = min(endI, elbow.count - 1)
        guard safeEnd > startI else { return 0.0 }

        // XY만 사용
        var pathLength = 0.0
        for i in (startI + 1)...safeEnd {
            pathLength += distance2D(
                Array(elbow[i].prefix(2)),
                Array(elbow[i - 1].prefix(2))
            )
        }

        let directDist = distance2D(
            Array(elbow[safeEnd].prefix(2)),
            Array(elbow[startI].prefix(2))
        )

        let rawDrift = max(0.0, pathLength - directDist)

        // 상완 길이(어깨-팔꿈치 거리 중앙값)로 정규화
        var humerusLengths = [Double]()
        for i in startI...safeEnd {
            humerusLengths.append(distance2D(
                Array(shoulder[i].prefix(2)),
                Array(elbow[i].prefix(2))
            ))
        }
        let medianHumerus = median(humerusLengths)
        guard medianHumerus > 1e-5 else { return rawDrift }

        return rawDrift / medianHumerus
    }

    /// 관절의 XY 좌표 분산 합산을 계산합니다.
    private func computeJointVariance(
        jointCoords: [[Double]],
        startI: Int,
        endI: Int
    ) -> Double {
        let safeEnd = min(endI, jointCoords.count - 1)
        guard safeEnd > startI else { return 0.0 }

        let segment = Array(jointCoords[startI...safeEnd])
        let xArr = segment.map { $0[0] }
        let yArr = segment.map { $0[1] }
        return variance(xArr) + variance(yArr)
    }

    /// 몸통 좌우 흔들림을 계산합니다.
    private func computeBodySway(
        hip: [[Double]],
        startI: Int,
        endI: Int
    ) -> Double {
        let safeEnd = min(endI, hip.count - 1)
        guard safeEnd > startI else { return 0.0 }

        let xVals = (startI...safeEnd).map { hip[$0][0] }
        return (xVals.max() ?? 0.0) - (xVals.min() ?? 0.0)
    }

    /// 릴리즈 시점의 전완 각도를 계산합니다.
    private func computeReleaseAngle(
        elbowAtRelease: [Double],
        wristAtRelease: [Double]
    ) -> Double {
        let forearmVec = [
            wristAtRelease[0] - elbowAtRelease[0],
            wristAtRelease[1] - elbowAtRelease[1],
            wristAtRelease[2] - elbowAtRelease[2],
        ]
        guard norm3D(forearmVec) > 1e-8 else { return 0.0 }

        // -Y: MediaPipe/Vision Y축 반전 (위가 +이 되도록)
        // abs(X): 투구 방향에 무관하게 0~90 범위
        let angle = atan2(-forearmVec[1], abs(forearmVec[0]))
        return angle * 180.0 / .pi
    }

    /// 테이크백~릴리즈 구간의 최대 팔꿈치 각속도를 계산합니다.
    private func computeMaxElbowVelocity(
        elbowAngles: [Double],
        tbMaxI: Int,
        relI: Int
    ) -> Double {
        let end = min(relI + 1, elbowAngles.count)
        let segment = Array(elbowAngles[tbMaxI..<end])
        guard segment.count >= 2 else { return 0.0 }

        let velocities = gradient(segment, dt: dt)
        let positiveVelocities = velocities.filter { $0 > 0 }
        return positiveVelocities.max() ?? 0.0
    }

    /// 릴리즈 전후 손가락 이동 속도를 계산합니다.
    private func computeFingerSpeed(
        indexTip: [[Double]],
        relI: Int,
        window: Int = 3
    ) -> Double {
        let n = indexTip.count
        let start = max(0, relI - window)
        let end = min(n - 1, relI + window)
        guard end > start else { return 0.0 }

        let segment = Array(indexTip[start...end])

        // 손가락 좌표가 모두 0이면 감지 실패
        if segment.allSatisfy({ $0[0] == 0 && $0[1] == 0 }) { return 0.0 }

        // XY 속도의 최대값
        var maxSpeed = 0.0
        for i in 1..<segment.count {
            let disp = distance2D(
                Array(segment[i].prefix(2)),
                Array(segment[i - 1].prefix(2))
            )
            let speed = disp / dt
            maxSpeed = max(maxSpeed, speed)
        }
        return maxSpeed
    }
}
