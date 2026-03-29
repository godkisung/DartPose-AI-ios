// PhaseDetector.swift
// 투구 페이즈 감지 모듈
//
// 단일 투구 세그먼트에서 4단계(Address, Takeback, Release, Follow-through)를
// 정밀하게 감지합니다.
//
// 하이브리드 릴리즈 스코어링:
//   Score = w1·Peak(θ̇_elbow) + w2·d/dt(||wrist-elbow||)
//   가속도 단독이 아닌 복합 가중치 스코어링 방식으로 노이즈 증폭 리스크 억제.
//
// Python phase_detector.py (408줄) → Swift 포팅

import Foundation

/// 하이브리드 릴리즈 스코어링 가중치
private let wElbowAngularVel: Double = 0.65   // 팔꿈치 각속도 주 가중치
private let wForearmExtension: Double = 0.35   // 전완 확장 보조 가중치

/// 페이즈 타임아웃 (초)
private let phaseTimeoutS: Double = 2.0

/// 투구 단계(Phase)를 감지하는 클래스.
///
/// FSM Loose 모드:
/// - Address가 없어도 Takeback 피크가 확실하면 투구로 인정
/// - 각 Phase에 타임아웃 적용 (2초 초과 시 강제 전환)
class PhaseDetector {

    let fps: Double
    private let dt: Double
    private let normalizer: PoseNormalizer
    private let phaseTimeoutFrames: Int

    /// 초기화
    /// - Parameter fps: 영상 프레임레이트
    init(fps: Double = 30.0) {
        self.fps = fps
        self.dt = 1.0 / fps
        self.normalizer = PoseNormalizer()
        self.phaseTimeoutFrames = Int(phaseTimeoutS * fps)
    }

    // MARK: - Public API

    /// 투구 세그먼트에서 4-Phase 경계를 감지합니다.
    ///
    /// ※ 핵심 설계: 각도 계산은 **원시 keypoints**에서 직접 수행합니다.
    ///
    /// - Parameters:
    ///   - frames: 단일 투구 세그먼트의 FrameData 리스트
    ///   - normalizedData: PoseNormalizer 출력 (Phase에서는 미사용)
    ///   - side: 투구 팔 방향
    /// - Returns: ThrowPhases 객체. 감지 실패 시 nil.
    func detect(
        frames: [FrameData],
        normalizedData: JointCoordDict,
        side: String
    ) -> ThrowPhases? {
        let n = frames.count
        guard n >= 10 else { return nil }

        // 원시 keypoints에서 직접 좌표 추출
        let segmenter = ThrowSegmenter(fps: fps)
        guard let shoulder = segmenter.extractRawJointCoords(
                  frames: frames, jointName: "\(side)Shoulder"),
              let elbow = segmenter.extractRawJointCoords(
                  frames: frames, jointName: "\(side)Elbow"),
              let wrist = segmenter.extractRawJointCoords(
                  frames: frames, jointName: "\(side)Wrist")
        else { return nil }

        // Step 1: 팔꿈치 각도 시계열 (원시 좌표 기반)
        var elbowAngles = [Double](repeating: 0, count: n)
        for i in 0..<n {
            elbowAngles[i] = angle3D(p1: shoulder[i], p2: elbow[i], p3: wrist[i])
        }

        // 각도가 전부 0이면 데이터 불량
        if elbowAngles.allSatisfy({ $0 < 1.0 }) { return nil }

        // Step 2: 팔꿈치 각속도 (1차 미분)
        let angleVelocity = gradient(elbowAngles, dt: dt)

        // Step 3: 손목-팔꿈치 거리 변화율 (릴리즈 보조 신호)
        var forearmLengths = [Double](repeating: 0, count: n)
        for i in 0..<n {
            forearmLengths[i] = distance3D(wrist[i], elbow[i])
        }
        let forearmRate = gradient(forearmLengths, dt: dt)

        // Step 4: 스무딩 (FPS 적응형 윈도우)
        let smoothWindow = max(3, Int(fps / 6.0)) | 1
        let smoothAngles = movingAverage(elbowAngles, window: smoothWindow)
        let smoothVelocity = movingAverage(angleVelocity, window: smoothWindow)
        let smoothForearm = movingAverage(forearmRate, window: smoothWindow)

        // Step 5: 테이크백 정점 감지
        let searchEnd = max(5, Int(Double(n) * 0.75))
        let searchAngles = Array(smoothAngles.prefix(searchEnd))

        // 5° 미만 프레임 무시 (관절 감지 실패 배제)
        var validAngles = searchAngles.map { $0 >= 5.0 ? $0 : Double.infinity }
        let takebackMaxLocal: Int
        if validAngles.contains(where: { $0 != Double.infinity }) {
            takebackMaxLocal = argmin(validAngles)
        } else {
            takebackMaxLocal = argmin(searchAngles)
        }

        // Step 6: 하이브리드 릴리즈 스코어링
        var releaseLocal = detectReleaseHybrid(
            angleVelocity: smoothVelocity,
            forearmRate: smoothForearm,
            takebackMax: takebackMaxLocal,
            n: n
        )

        // Step 7: 타임아웃 보정
        if releaseLocal - takebackMaxLocal > phaseTimeoutFrames {
            releaseLocal = min(n - 1, takebackMaxLocal + phaseTimeoutFrames)
        }

        // Step 8: 나머지 Phase 경계 결정 (Loose FSM)
        let addressLocal = 0

        var takebackStartLocal = findTakebackStart(
            smoothAngles: smoothAngles,
            addressLocal: addressLocal,
            takebackMaxLocal: takebackMaxLocal
        )
        if takebackStartLocal >= takebackMaxLocal {
            takebackStartLocal = addressLocal
        }

        var followThroughLocal = findFollowThrough(
            smoothAngles: smoothAngles,
            releaseLocal: releaseLocal,
            n: n
        )
        if followThroughLocal - releaseLocal > phaseTimeoutFrames {
            followThroughLocal = min(n - 1, releaseLocal + phaseTimeoutFrames)
        }

        // Step 9: 절대 프레임 인덱스로 변환
        func toAbs(_ localI: Int) -> Int {
            return frames[min(localI, n - 1)].frameIndex
        }

        return ThrowPhases(
            address: toAbs(addressLocal),
            takebackStart: toAbs(takebackStartLocal),
            takebackMax: toAbs(takebackMaxLocal),
            release: toAbs(releaseLocal),
            followThrough: toAbs(followThroughLocal)
        )
    }

    // MARK: - Release Detection

    /// 하이브리드 스코어링으로 릴리즈 순간을 감지합니다.
    private func detectReleaseHybrid(
        angleVelocity: [Double],
        forearmRate: [Double],
        takebackMax: Int,
        n: Int
    ) -> Int {
        let searchStart = takebackMax + 1
        guard searchStart < n - 1 else { return n - 1 }

        let regionVel = Array(angleVelocity.suffix(from: searchStart))
        let regionArm = Array(forearmRate.suffix(from: searchStart))
        guard !regionVel.isEmpty else { return n - 1 }

        // 각 신호를 0~1 범위로 정규화
        let normVel = normalizeSignal(regionVel)
        let normArm = normalizeSignal(regionArm)

        // 하이브리드 스코어 계산
        var hybridScore = [Double](repeating: 0, count: regionVel.count)
        for i in 0..<regionVel.count {
            hybridScore[i] = wElbowAngularVel * normVel[i]
                           + wForearmExtension * normArm[i]
        }

        // 최대 스코어 시점 = 릴리즈
        let localRelease = argmax(hybridScore)
        let releaseIdx = searchStart + localRelease

        // 검증: 팔이 실제로 펴지는 동작이 있는지
        if angleVelocity[releaseIdx] > 0 {
            return releaseIdx
        }

        // Fallback: 각속도 최대값만 사용
        let fallbackLocal = argmax(regionVel)
        let fallbackIdx = searchStart + fallbackLocal
        if angleVelocity[fallbackIdx] > 0 {
            return fallbackIdx
        }

        // 최종 Fallback: 테이크백에서 40% 진행 시점
        return min(n - 1, takebackMax + max(1, Int(Double(n - takebackMax) * 0.4)))
    }

    /// 테이크백 시작 시점을 찾습니다.
    private func findTakebackStart(
        smoothAngles: [Double],
        addressLocal: Int,
        takebackMaxLocal: Int
    ) -> Int {
        let range = Array(smoothAngles[addressLocal...min(takebackMaxLocal, smoothAngles.count - 1)])
        guard range.count >= 3 else { return addressLocal }
        let localMax = argmax(range)
        return addressLocal + localMax
    }

    /// 팔로스루 완료 시점을 감지합니다.
    private func findFollowThrough(
        smoothAngles: [Double],
        releaseLocal: Int,
        n: Int
    ) -> Int {
        let searchStart = releaseLocal + 1
        guard searchStart < n else { return n - 1 }

        let region = Array(smoothAngles.suffix(from: searchStart))
        guard region.count >= 2 else { return n - 1 }

        let localMax = argmax(region)
        return min(n - 1, searchStart + localMax)
    }
}
