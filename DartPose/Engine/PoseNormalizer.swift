// PoseNormalizer.swift
// 포즈 정규화 모듈
//
// 핸드헬드 촬영에 의한 카메라 흔들림 보정 및 몸통 크기 기반 좌표 정규화를
// 수행합니다. 측면/측후면/측전면 등 다양한 촬영 각도에서도 동일한
// 분석 신호를 추출하기 위해 원시 좌표 대신 상대 좌표계로 변환합니다.
//
// Python pose_normalizer.py (276줄) → Swift 포팅
// Accelerate(vDSP) 기반 이동평균 스무딩 사용

import Foundation

/// 핵심 포즈 관절 이름 목록 (상체)
private let upperBodyJoints = [
    "leftShoulder", "rightShoulder",
    "leftElbow",    "rightElbow",
    "leftWrist",    "rightWrist",
    "leftHip",      "rightHip",
]

/// 손가락 관절 이름 목록 (Vision Framework에서는 미지원)
private let fingerJoints = [
    "leftThumbTip",  "rightThumbTip",
    "leftIndexTip",  "rightIndexTip",
    "leftMiddleTip", "rightMiddleTip",
]

/// 관절 좌표 시계열: [관절이름: [[x,y,z], [x,y,z], ...]] 프레임별 좌표
typealias JointCoordDict = [String: [[Double]]]

/// 관절 좌표 시계열을 정규화하는 클래스.
///
/// 1. 어깨 중점(mid-shoulder) 기준 상대 좌표 변환 → 카메라 흔들림 제거
/// 2. 어깨-엉덩이 거리 기준 스케일 정규화 → 촬영 거리 차이 제거
/// 3. 이동평균 스무딩 → 잔여 노이즈 제거
class PoseNormalizer {

    /// 이동평균 윈도우 크기
    private let smoothingWindow: Int

    /// 초기화
    /// - Parameter smoothingWindow: 이동평균 윈도우. 클수록 떨림 제거, 해상도 감소.
    init(smoothingWindow: Int = DartConfig.normalizerSmoothingWindow) {
        self.smoothingWindow = smoothingWindow
    }

    // MARK: - Public API

    /// 프레임 리스트를 정규화된 관절 좌표 딕셔너리로 변환합니다.
    ///
    /// - Parameters:
    ///   - frames: FrameData 리스트
    ///   - throwingSide: 투구 팔 방향 ("left" 또는 "right")
    /// - Returns: 관절 이름 → [[x,y,z]] 정규화 좌표 딕셔너리
    func normalize(frames: [FrameData], throwingSide: String) -> JointCoordDict {
        let allJoints = upperBodyJoints + fingerJoints

        // 1단계: 원시 좌표 추출 (없는 값은 이전 프레임으로 채우기)
        let raw = extractRawCoordinates(frames: frames, joints: allJoints)

        // 2단계: 핸드헬드 흔들림 보정 (어깨 중점 기준 상대 좌표)
        let cameraCorrected = correctCameraMotion(raw: raw)

        // 3단계: 몸통 크기 기반 스케일 정규화
        let scaleNormalized = normalizeByTorsoLength(
            data: cameraCorrected, side: throwingSide
        )

        // 4단계: 시간축 이동평균 스무딩
        let smoothed = applyTemporalSmoothing(data: scaleNormalized)

        return smoothed
    }

    // MARK: - Private Methods

    /// 프레임 리스트에서 관절별 원시 좌표 배열을 추출합니다.
    /// 누락된 값(nil)은 직전 유효값으로 채웁니다(forward fill).
    func extractRawCoordinates(
        frames: [FrameData],
        joints: [String]
    ) -> JointCoordDict {
        let n = frames.count
        var result = JointCoordDict()

        for joint in joints {
            var coords = [[Double]](repeating: [0, 0, 0], count: n)
            var lastValid: [Double] = [0, 0, 0]

            for i in 0..<n {
                if let kp = frames[i].keypoints,
                   let val = kp.get(joint) {
                    // 최소 3차원 확보
                    lastValid = Array(val.prefix(3))
                    if lastValid.count < 3 {
                        lastValid.append(contentsOf:
                            [Double](repeating: 0, count: 3 - lastValid.count))
                    }
                }
                coords[i] = lastValid
            }
            result[joint] = coords
        }
        return result
    }

    /// 핸드헬드 카메라 흔들림을 제거합니다.
    /// 어깨 중점(mid-shoulder)의 이동 궤적을 계산하고,
    /// 모든 관절에서 이 이동량을 차감합니다.
    private func correctCameraMotion(raw: JointCoordDict) -> JointCoordDict {
        let lShoulder = raw["leftShoulder"] ?? []
        let rShoulder = raw["rightShoulder"] ?? []
        let n = max(lShoulder.count, rShoulder.count)

        // 어깨 중점 계산
        var midShoulder = [[Double]](repeating: [0, 0, 0], count: n)
        for i in 0..<n {
            let l = i < lShoulder.count ? lShoulder[i] : [0, 0, 0]
            let r = i < rShoulder.count ? rShoulder[i] : [0, 0, 0]
            midShoulder[i] = [
                (l[0] + r[0]) / 2.0,
                (l[1] + r[1]) / 2.0,
                (l[2] + r[2]) / 2.0,
            ]
        }

        // 모든 관절에서 어깨 중점을 차감
        var corrected = JointCoordDict()
        for (joint, coords) in raw {
            var newCoords = [[Double]](repeating: [0, 0, 0], count: coords.count)
            for i in 0..<coords.count {
                let mid = i < midShoulder.count ? midShoulder[i] : [0, 0, 0]
                newCoords[i] = [
                    coords[i][0] - mid[0],
                    coords[i][1] - mid[1],
                    coords[i][2] - mid[2],
                ]
            }
            corrected[joint] = newCoords
        }
        return corrected
    }

    /// 몸통 길이(어깨-엉덩이 거리)로 좌표를 정규화합니다.
    private func normalizeByTorsoLength(
        data: JointCoordDict,
        side: String
    ) -> JointCoordDict {
        let shoulder = data["\(side)Shoulder"] ?? []
        let hip = data["\(side)Hip"] ?? []

        // 어깨-엉덩이 거리 프레임별 계산
        var torsoLengths = [Double]()
        let count = min(shoulder.count, hip.count)
        for i in 0..<count {
            torsoLengths.append(distance3D(shoulder[i], hip[i]))
        }

        // 중앙값 사용 (이상치 방어)
        let medianTorso = median(torsoLengths)
        let scale = medianTorso > 0.01 ? medianTorso : 1.0

        // 모든 관절 좌표를 스케일로 나누기
        var normalized = JointCoordDict()
        for (joint, coords) in data {
            normalized[joint] = coords.map { c in
                [c[0] / scale, c[1] / scale, c[2] / scale]
            }
        }
        return normalized
    }

    /// 시간축 이동평균(moving average) 스무딩을 적용합니다.
    private func applyTemporalSmoothing(data: JointCoordDict) -> JointCoordDict {
        var smoothed = JointCoordDict()

        for (joint, coords) in data {
            let n = coords.count
            guard n > smoothingWindow else {
                smoothed[joint] = coords
                continue
            }

            // 각 축(x, y, z)에 독립적으로 이동평균 적용
            var xArr = [Double](repeating: 0, count: n)
            var yArr = [Double](repeating: 0, count: n)
            var zArr = [Double](repeating: 0, count: n)
            for i in 0..<n {
                xArr[i] = coords[i][0]
                yArr[i] = coords[i][1]
                zArr[i] = coords[i][2]
            }

            let smoothX = movingAverage(xArr, window: smoothingWindow)
            let smoothY = movingAverage(yArr, window: smoothingWindow)
            let smoothZ = movingAverage(zArr, window: smoothingWindow)

            var result = [[Double]](repeating: [0, 0, 0], count: n)
            for i in 0..<n {
                result[i] = [smoothX[i], smoothY[i], smoothZ[i]]
            }
            smoothed[joint] = result
        }
        return smoothed
    }
}
