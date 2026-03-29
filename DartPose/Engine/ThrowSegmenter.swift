// ThrowSegmenter.swift
// 투구 세분화 모듈 — FSM(상태 기계) 기반
//
// 연속 영상에서 개별 투구 구간을 자동으로 분리합니다.
// 팔꿈치 각도(어깨-팔꿈치-손목) 사이클을 FSM으로 추적하여 투구를 카운트합니다.
//
// Python throw_segmenter.py (588줄) → Swift 포팅
// numpy 연산 → MathUtils.swift(vDSP 기반)로 대체

import Foundation

// MARK: - FSM 상태

/// 투구 감지 FSM 상태
enum FSMState: String {
    /// 대기 상태 (팔이 펴져 있거나 정지)
    case idle = "idle"
    /// 팔 접기 진행 중 (테이크백)
    case cocking = "cocking"
    /// 팔 펴기 진행 중 (릴리즈)
    case releasing = "releasing"
    /// 팔로스루 진행 중 (팔이 다 펴진 후 안정화 대기)
    case followThrough = "followThrough"
}

/// FSM이 감지한 투구 사이클 경계 정보
struct ThrowCycle {
    let start: Int              // 사이클 시작 프레임 인덱스
    let end: Int                // 사이클 종료 프레임 인덱스
    let minAngleFrame: Int      // 최저 각도 프레임 인덱스
    let minAngle: Double        // 최저 각도 (도)
    let angleRange: Double      // 각도 변화량 (도)
}

/// 팔꿈치 각도 사이클 FSM으로 투구 구간을 분리하는 클래스.
///
/// 핵심 알고리즘:
/// 1. 프레임별 팔꿈치 각도 계산 (카메라 거리 불변)
/// 2. 가우시안 스무딩으로 노이즈 제거
/// 3. FSM 상태 전환으로 투구 사이클 감지:
///    IDLE → COCKING → RELEASING → FOLLOW_THROUGH → IDLE
/// 4. 각 사이클을 하나의 투구 세그먼트로 반환
class ThrowSegmenter {

    // MARK: - 속성

    let fps: Double
    private let smoothingSigma: Double
    private let angleDropThreshold: Double
    private let releaseAngleRise: Double
    private let idleStabilityFrames: Int
    private let minCockingAngle: Double
    private let minSegmentFrames: Int
    private let minThrowInterval: Int
    private let segmentPad: Int
    private let mergeGapFrames: Int

    // 디버그용 데이터 (분석 후 외부 접근 가능)
    private(set) var lastElbowAngles: [Double] = []
    private(set) var lastSmoothedAngles: [Double] = []
    private(set) var lastFSMStates: [String] = []
    private(set) var lastCycleBoundaries: [ThrowCycle] = []

    // MARK: - 초기화

    /// 초기화
    /// - Parameter fps: 영상 프레임레이트
    init(
        fps: Double = 30.0,
        smoothingSigma: Double = DartConfig.segmenterSmoothingSigma,
        angleDropThreshold: Double = DartConfig.segmenterAngleDropThreshold,
        releaseAngleRise: Double = DartConfig.segmenterReleaseAngleRise,
        idleStabilityFrames: Int = DartConfig.segmenterIdleStabilityFrames,
        minCockingAngle: Double = DartConfig.segmenterMinCockingAngle,
        minSegmentFrames: Int = DartConfig.segmenterMinSegmentFrames,
        minThrowIntervalS: Double = DartConfig.segmenterMinThrowIntervalS,
        segmentPadS: Double = DartConfig.segmenterSegmentPadS,
        mergeGapFrames: Int = DartConfig.segmenterMergeGapFrames
    ) {
        self.fps = fps
        self.smoothingSigma = smoothingSigma
        self.angleDropThreshold = angleDropThreshold
        self.releaseAngleRise = releaseAngleRise
        self.idleStabilityFrames = idleStabilityFrames
        self.minCockingAngle = minCockingAngle
        self.minSegmentFrames = minSegmentFrames
        self.minThrowInterval = max(1, Int(minThrowIntervalS * fps))
        self.segmentPad = max(1, Int(segmentPadS * fps))
        self.mergeGapFrames = mergeGapFrames
    }

    // MARK: - Public API

    /// 투구 세그먼트를 분리합니다.
    ///
    /// - Parameters:
    ///   - frames: keypoints가 있는 FrameData 리스트
    ///   - normalizedData: PoseNormalizer.normalize()의 출력 (API 호환용)
    ///   - throwingSide: 투구 팔 방향 ("left" 또는 "right")
    /// - Returns: 투구 세그먼트 리스트. 각 원소는 [FrameData] 배열.
    func segment(
        frames: [FrameData],
        normalizedData: JointCoordDict,
        throwingSide: String
    ) -> [[FrameData]] {
        guard frames.count >= minSegmentFrames else {
            clearDebugData()
            return frames.isEmpty ? [] : [frames]
        }

        // Step 1: 원시 좌표에서 관절 좌표 추출
        guard let shoulderCoords = extractRawJointCoords(
                  frames: frames, jointName: "\(throwingSide)Shoulder"),
              let elbowCoords = extractRawJointCoords(
                  frames: frames, jointName: "\(throwingSide)Elbow"),
              let wristCoords = extractRawJointCoords(
                  frames: frames, jointName: "\(throwingSide)Wrist")
        else {
            clearDebugData()
            return [frames]
        }

        // Step 2: 프레임별 팔꿈치 각도 계산 (카메라 거리 불변)
        let elbowAngles = computeElbowAngles(
            shoulder: shoulderCoords, elbow: elbowCoords, wrist: wristCoords
        )

        // Step 3: 가우시안 스무딩
        let smoothedAngles = gaussianSmooth(
            elbowAngles, sigmaSeconds: smoothingSigma, fps: fps
        )

        // 디버그 데이터 저장
        lastElbowAngles = elbowAngles
        lastSmoothedAngles = smoothedAngles

        // Step 4: FSM으로 투구 사이클 감지
        let cycles = runFSM(smoothedAngles: smoothedAngles)
        lastCycleBoundaries = cycles

        guard !cycles.isEmpty else {
            print("  ⚠ FSM 사이클 감지 실패 — 전체를 1개 투구로 처리")
            return [frames]
        }

        print("  ℹ FSM 감지된 투구 사이클: \(cycles.count)개")

        // Step 5: 사이클을 세그먼트로 변환 (패딩 포함)
        let rawSegments = cyclesToSegments(frames: frames, cycles: cycles)

        // Step 6: 무효 세그먼트 필터링
        let filtered = filterInvalidSegments(
            segments: rawSegments, allFrames: frames, throwingSide: throwingSide
        )

        // Step 7: 가까운 세그먼트 병합
        let merged = mergeCloseSegments(segments: filtered)

        return merged.isEmpty ? [frames] : merged
    }

    // MARK: - FSM Core

    /// FSM을 실행하여 투구 사이클 경계를 감지합니다.
    private func runFSM(smoothedAngles: [Double]) -> [ThrowCycle] {
        let n = smoothedAngles.count
        var state = FSMState.idle
        var cycles: [ThrowCycle] = []

        // 로컬 최대 각도 추적 윈도우 크기 (약 0.5초)
        let lookback = max(5, Int(fps * 0.5))

        // FSM 상태 변수
        var recentMaxAngle = smoothedAngles[0]
        var cockingEntryAngle = 0.0
        var cycleStart = 0
        var minAngle = Double.infinity
        var minAngleFrame = 0
        var stabilityCount = 0
        var lastCycleEnd = -minThrowInterval

        // hysteresis 최소 체류 프레임
        let minStateFrames = max(3, Int(fps * 0.1))
        var stateEntryFrame = 0

        // FSM 상태 기록 (디버그용)
        var fsmStates: [String] = []

        for i in 0..<n {
            let angle = smoothedAngles[i]
            let framesInState = i - stateEntryFrame
            fsmStates.append(state.rawValue)

            switch state {
            case .idle:
                // 최근 윈도우 내 최대 각도 추적
                let lookbackStart = max(0, i - lookback)
                recentMaxAngle = smoothedAngles[lookbackStart...i].max() ?? angle

                // 현재 각도가 최근 최대에서 drop_threshold 이상 떨어지면 → COCKING
                let drop = recentMaxAngle - angle
                if drop > angleDropThreshold {
                    if i - lastCycleEnd >= minThrowInterval {
                        state = .cocking
                        stateEntryFrame = i
                        cockingEntryAngle = recentMaxAngle
                        cycleStart = max(0, i - minStateFrames)
                        minAngle = angle
                        minAngleFrame = i
                    }
                }

            case .cocking:
                // 최저 각도 갱신
                if angle < minAngle {
                    minAngle = angle
                    minAngleFrame = i
                }

                if framesInState >= minStateFrames {
                    // 각도가 최저점에서 releaseAngleRise 이상 증가 → RELEASING
                    if angle - minAngle > releaseAngleRise {
                        state = .releasing
                        stateEntryFrame = i
                    }
                    // 타임아웃: 2초 이상 COCKING이면 무효 → IDLE
                    else if framesInState > Int(2.0 * fps) {
                        state = .idle
                        stateEntryFrame = i
                    }
                }

            case .releasing:
                if framesInState >= minStateFrames {
                    // 각도가 cocking 진입 각도 근처(±15°)로 돌아오면 → FOLLOW_THROUGH
                    if angle >= cockingEntryAngle - 15.0 {
                        state = .followThrough
                        stateEntryFrame = i
                        stabilityCount = 0
                    }
                    // 타임아웃: 1.5초 이상 지속되면 강제 전환
                    else if framesInState > Int(1.5 * fps) {
                        state = .followThrough
                        stateEntryFrame = i
                        stabilityCount = 0
                    }
                }

            case .followThrough:
                // 각도 변화가 안정(±2°/프레임 이하)이면 카운터 증가
                if i > 0 {
                    let angleDelta = abs(angle - smoothedAngles[i - 1])
                    if angleDelta < 2.0 {
                        stabilityCount += 1
                    } else {
                        stabilityCount = max(0, stabilityCount - 1)
                    }
                }

                // 안정 프레임 수 도달 → 1회 투구 완료
                if stabilityCount >= idleStabilityFrames ||
                   framesInState > Int(1.5 * fps) {
                    let angleRange = cockingEntryAngle - minAngle
                    if angleRange >= minCockingAngle {
                        cycles.append(ThrowCycle(
                            start: cycleStart,
                            end: i,
                            minAngleFrame: minAngleFrame,
                            minAngle: minAngle,
                            angleRange: angleRange
                        ))
                        lastCycleEnd = i
                    }
                    state = .idle
                    stateEntryFrame = i
                }
            }
        }

        // 마지막 미완료 사이클 처리
        if state == .releasing || state == .followThrough {
            let angleRange = cockingEntryAngle - minAngle
            if angleRange >= minCockingAngle {
                cycles.append(ThrowCycle(
                    start: cycleStart,
                    end: n - 1,
                    minAngleFrame: minAngleFrame,
                    minAngle: minAngle,
                    angleRange: angleRange
                ))
            }
        }

        lastFSMStates = fsmStates
        return cycles
    }

    // MARK: - Segment Construction

    /// FSM 사이클 경계를 프레임 세그먼트로 변환합니다.
    private func cyclesToSegments(
        frames: [FrameData],
        cycles: [ThrowCycle]
    ) -> [[FrameData]] {
        let n = frames.count
        var segments: [[FrameData]] = []

        for (idx, cycle) in cycles.enumerated() {
            var start = max(0, cycle.start - segmentPad)
            var end = min(n - 1, cycle.end + segmentPad)

            // 인접 사이클과 패딩이 겹치지 않도록 중간점으로 클리핑
            if idx > 0 {
                let midpoint = (cycles[idx - 1].end + cycle.start) / 2
                start = max(start, midpoint + 1)
            }
            if idx < cycles.count - 1 {
                let midpoint = (cycle.end + cycles[idx + 1].start) / 2
                end = min(end, midpoint)
            }

            segments.append(Array(frames[start...end]))
        }
        return segments
    }

    /// 무효 세그먼트를 필터링합니다.
    private func filterInvalidSegments(
        segments: [[FrameData]],
        allFrames: [FrameData],
        throwingSide: String
    ) -> [[FrameData]] {
        var valid: [[FrameData]] = []

        for seg in segments {
            // 조건 1: 최소 프레임 수
            guard seg.count >= minSegmentFrames else { continue }

            // 조건 2: 손목 이동 변위 확인
            let wristKey = "\(throwingSide)Wrist"
            var wristCoords: [[Double]] = []
            for f in seg {
                if let kp = f.keypoints, let w = kp.get(wristKey) {
                    wristCoords.append(Array(w.prefix(2)))
                }
            }

            if wristCoords.count >= 3 {
                let origin = wristCoords[0]
                let maxDisp = wristCoords.map { distance2D($0, origin) }.max() ?? 0.0
                if maxDisp < DartConfig.segmenterMinWristDisplacement {
                    continue
                }
            }

            valid.append(seg)
        }
        return valid
    }

    // MARK: - Core Algorithms

    /// 원시 keypoints에서 특정 관절 좌표를 추출합니다.
    /// 누락된 프레임은 직전 값으로 채웁니다 (forward fill).
    func extractRawJointCoords(
        frames: [FrameData],
        jointName: String
    ) -> [[Double]]? {
        let n = frames.count
        var coords = [[Double]](repeating: [0, 0, 0], count: n)
        var lastValid: [Double]?

        for i in 0..<n {
            if let kp = frames[i].keypoints,
               let w = kp.get(jointName) {
                lastValid = Array(w.prefix(3))
                if lastValid!.count < 3 {
                    lastValid!.append(contentsOf:
                        [Double](repeating: 0, count: 3 - lastValid!.count))
                }
            }
            if let lv = lastValid {
                coords[i] = lv
            }
        }

        // 유효 좌표가 하나도 없으면 nil
        guard lastValid != nil else { return nil }
        return coords
    }

    /// 어깨-팔꿈치-손목 각도를 계산합니다.
    /// 각도는 카메라 거리에 불변합니다 (벡터 내적 기반).
    func computeElbowAngles(
        shoulder: [[Double]],
        elbow: [[Double]],
        wrist: [[Double]]
    ) -> [Double] {
        let n = shoulder.count
        var angles = [Double](repeating: 180.0, count: n)

        for i in 0..<n {
            angles[i] = angle3D(p1: shoulder[i], p2: elbow[i], p3: wrist[i])
            // angle3D가 0.0 반환 시 (무효 벡터) 기본값 유지
            if angles[i] < 0.001 { angles[i] = 180.0 }
        }
        return angles
    }

    /// 인접한 세그먼트 간격이 너무 가까우면 하나로 병합합니다.
    private func mergeCloseSegments(segments: [[FrameData]]) -> [[FrameData]] {
        guard segments.count >= 2 else { return segments }

        var merged: [[FrameData]] = []
        var current = segments[0]

        for i in 1..<segments.count {
            let nextSeg = segments[i]
            let gap = nextSeg[0].frameIndex - current[current.count - 1].frameIndex
            if gap <= mergeGapFrames {
                current.append(contentsOf: nextSeg)
            } else {
                merged.append(current)
                current = nextSeg
            }
        }
        merged.append(current)
        return merged
    }

    /// 디버그 데이터를 초기화합니다.
    private func clearDebugData() {
        lastElbowAngles = []
        lastSmoothedAngles = []
        lastFSMStates = []
        lastCycleBoundaries = []
    }
}
