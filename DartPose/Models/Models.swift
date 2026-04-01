// Models.swift
// 데이터 모델 정의
//
// Python models.py의 데이터 클래스를 Swift struct로 1:1 포팅합니다.
// 모든 모델은 Codable을 준수하여 JSON 직렬화/역직렬화를 지원합니다.

import Foundation

// MARK: - Keypoints (관절 좌표)

/// 단일 프레임에서 추출된 관절 좌표 (정규화된 0~1 좌표).
/// Apple Vision Framework 또는 MediaPipe에서 추출된 3D 좌표를 담습니다.
struct Keypoints: Codable {
    // 핵심 상체 관절 — [x, y, z] 배열
    var leftShoulder: [Double]
    var rightShoulder: [Double]
    var leftElbow: [Double]
    var rightElbow: [Double]
    var leftWrist: [Double]
    var rightWrist: [Double]
    var leftHip: [Double]
    var rightHip: [Double]

    // 손가락 끝점 (Vision Framework에서는 미지원 → nil)
    var leftThumbTip: [Double]?
    var rightThumbTip: [Double]?
    var leftIndexTip: [Double]?
    var rightIndexTip: [Double]?
    var leftMiddleTip: [Double]?
    var rightMiddleTip: [Double]?

    /// 관절 이름으로 좌표를 반환합니다.
    /// - Parameter jointName: 관절 이름 (예: "rightWrist")
    /// - Returns: [x, y, z] 좌표 배열. 없으면 nil.
    func get(_ jointName: String) -> [Double]? {
        switch jointName {
        case "leftShoulder":  return leftShoulder
        case "rightShoulder": return rightShoulder
        case "leftElbow":     return leftElbow
        case "rightElbow":    return rightElbow
        case "leftWrist":     return leftWrist
        case "rightWrist":    return rightWrist
        case "leftHip":       return leftHip
        case "rightHip":      return rightHip
        case "leftThumbTip":  return leftThumbTip
        case "rightThumbTip": return rightThumbTip
        case "leftIndexTip":  return leftIndexTip
        case "rightIndexTip": return rightIndexTip
        case "leftMiddleTip": return leftMiddleTip
        case "rightMiddleTip": return rightMiddleTip
        default: return nil
        }
    }

    /// 딕셔너리로 변환합니다.
    func toDict() -> [String: [Double]] {
        var d: [String: [Double]] = [
            "leftShoulder": leftShoulder,
            "rightShoulder": rightShoulder,
            "leftElbow": leftElbow,
            "rightElbow": rightElbow,
            "leftWrist": leftWrist,
            "rightWrist": rightWrist,
            "leftHip": leftHip,
            "rightHip": rightHip,
        ]
        if let v = leftThumbTip  { d["leftThumbTip"] = v }
        if let v = rightThumbTip { d["rightThumbTip"] = v }
        if let v = leftIndexTip  { d["leftIndexTip"] = v }
        if let v = rightIndexTip { d["rightIndexTip"] = v }
        if let v = leftMiddleTip { d["leftMiddleTip"] = v }
        if let v = rightMiddleTip { d["rightMiddleTip"] = v }
        return d
    }
}

// MARK: - FrameData (단일 프레임)

/// 단일 프레임 데이터.
/// PoseExtractor에서 추출된 관절 좌표와 타임스탬프를 담습니다.
struct FrameData: Codable {
    /// 프레임 인덱스 (0부터 시작)
    let frameIndex: Int
    /// 타임스탬프 (밀리초)
    let timestampMs: Double
    /// 포즈 관절 좌표 (추출 실패 시 nil)
    var keypoints: Keypoints?
}

// MARK: - ThrowPhases (투구 단계)

/// 투구 단계별 프레임 인덱스 (세션 내 절대 인덱스).
/// 각 단계의 시작 프레임을 정수로 기록합니다.
struct ThrowPhases: Codable {
    /// 준비 자세 시작 (다트 조준 시작)
    let address: Int
    /// 테이크백 시작 (팔을 뒤로 당기기 시작)
    let takebackStart: Int
    /// 테이크백 정점 (가장 뒤로 당겨진 시점)
    let takebackMax: Int
    /// 릴리즈 (다트를 놓는 찰나)
    let release: Int
    /// 팔로스루 완료 (팔이 완전히 펴진 시점)
    let followThrough: Int
}

// MARK: - ThrowMetrics (생체역학 수치)

/// 고도화된 단일 투구 생체역학 수치 지표.
/// Huang et al. (2024) 논문 기반 10가지 메트릭을 포함합니다.
struct ThrowMetrics: Codable {
    // 1. 안정성 지표 (Stability)
    /// 투구 중 팔꿈치의 이동 거리 (정규화 단위)
    var elbowDriftNorm: Double = 0.0
    /// 어깨 고정성 (분산)
    var shoulderStability: Double = 0.0
    /// 몸통 흔들림 (X축 변위)
    var bodySway: Double = 0.0

    // 2. 각도 지표 (Angles)
    /// 테이크백 정점에서의 팔꿈치 각도
    var takebackAngleDeg: Double = 0.0
    /// 릴리즈 순간의 지면 대비 팔뚝 각도
    var releaseAngleDeg: Double = 0.0
    /// 팔로스루 완료 시 팔 각도
    var followThroughAngleDeg: Double = 0.0

    // 3. 속도/타이밍 지표 (Velocity & Timing)
    /// 최대 팔꿈치 확장 속도
    var maxElbowVelocityDegS: Double = 0.0
    /// 가속 시작부터 릴리즈까지 걸린 시간
    var releaseTimingMs: Double = 0.0
    /// 릴리즈 순간 손가락이 벌어지는 속도
    var fingerReleaseSpeed: Double = 0.0

    // 4. 일관성 점수 (Consistency — 세션 분석 시 계산)
    /// 이전 투구들과의 유사도 (0~100)
    var consistencyScore: Double = 0.0
}

// MARK: - ThrowAnalysis (단일 투구 분석 결과)

/// 단일 투구 분석 결과.
/// 투구 인덱스, 사용 팔, 프레임 범위, 4-Phase, 메트릭, 이슈를 포함합니다.
struct ThrowAnalysis: Codable, Identifiable {
    /// `Identifiable` 프로토콜용 고유 ID
    var id: UUID = UUID()
    /// 투구 순번 (1부터 시작)
    var throwIndex: Int
    /// 투구 팔 방향 ("left" 또는 "right")
    let throwingArm: String
    /// 프레임 범위 [시작, 끝] 절대 인덱스
    let frameRange: [Int]
    /// 4-Phase 경계
    let phases: ThrowPhases
    /// 생체역학 메트릭
    var metrics: ThrowMetrics
    /// 감지된 이슈 목록
    var issues: [String] = []

    /// Phase 경계 프레임에서의 관절 좌표 스냅샷 (스켈레톤 시각화용)
    /// Keys: "address", "takebackMax", "release", "followThrough"
    var phaseKeypoints: [String: Keypoints] = [:]

    /// CodingKeys — id, phaseKeypoints는 JSON에 포함하지 않음
    enum CodingKeys: String, CodingKey {
        case throwIndex, throwingArm, frameRange, phases, metrics, issues
    }
}

// MARK: - SessionResult (세션 전체 분석 결과)

/// 전체 세션 (여러 투구) 분석 결과.
struct SessionResult: Codable {
    /// 전체 프레임 수
    let totalFrames: Int
    /// 영상 FPS
    let fps: Double
    /// 감지된 투구 수
    let totalThrowsDetected: Int
    /// 각 투구 분석 결과
    var throws_: [ThrowAnalysis] = []
    /// 피드백 문자열
    var feedback: String = ""

    enum CodingKeys: String, CodingKey {
        case totalFrames, fps, totalThrowsDetected
        case throws_ = "throws"
        case feedback
    }
}
