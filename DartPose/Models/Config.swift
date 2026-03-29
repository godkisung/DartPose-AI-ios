// Config.swift
// 프로젝트 전역 설정
//
// Python config.py의 모든 임계값과 상수를 Swift 상수로 정의합니다.
// 모든 임계값은 정규화된 좌표 기준입니다 (Vision: 0~1 범위).

import Foundation

/// 분석 엔진의 모든 설정값을 담는 네임스페이스.
/// 인스턴스 생성 불가 (케이스 없는 enum).
enum DartConfig {

    // MARK: - PoseNormalizer 설정

    /// 시간축 이동평균 윈도우 크기 (클수록 떨림 제거, 시간 해상도 감소)
    static let normalizerSmoothingWindow = 5

    // MARK: - ThrowSegmenter (FSM 기반) 설정

    /// 가우시안 스무딩 강도 (초 단위 표준편차)
    static let segmenterSmoothingSigma: Double = 0.06

    /// IDLE → COCKING 전환: 팔꿈치 각도 감소 임계값 (도)
    static let segmenterAngleDropThreshold: Double = 7.0

    /// COCKING → RELEASING 전환: 테이크백 최저 각도 대비 각도 증가량 (도)
    static let segmenterReleaseAngleRise: Double = 10.0

    /// FOLLOW_THROUGH → IDLE 전환: 안정화에 필요한 프레임 수
    static let segmenterIdleStabilityFrames = 8

    /// 유효 투구로 인정되는 최소 팔꿈치 각도 변화 (도)
    static let segmenterMinCockingAngle: Double = 6.0

    /// 한 투구 사이클의 최소 프레임 수
    static let segmenterMinSegmentFrames = 10

    /// 연속 투구 간 최소 시간 간격 (초)
    static let segmenterMinThrowIntervalS: Double = 0.7

    /// 유효 세그먼트의 최대 지속 시간 (초)
    static let segmenterMaxSegmentDurationS: Double = 4.0

    /// 세그먼트 확장 시간 (초) — 피크 전후 여유 프레임 확보
    static let segmenterSegmentPadS: Double = 0.5

    /// 간격이 이 프레임 수 이하인 세그먼트는 하나로 병합
    static let segmenterMergeGapFrames = -1

    /// 유효 세그먼트의 손목 최소 변위 (정규화 단위)
    static let segmenterMinWristDisplacement: Double = 0.04

    // MARK: - Validation Thresholds

    /// 투구로 인정되는 손목 최소 변위 (정규화 단위)
    static let validationMinWristDisplacement: Double = 0.04

    /// 투구로 인정되는 최소 팔꿈치 굽힘 각도 (도)
    static let validationMinTakebackAngle: Double = 5.0

    /// 유효 투구의 테이크백 최대 각도 (도)
    static let validationMaxTakebackAngle: Double = 165.0

    /// 유효 투구의 최소 팔꿈치 확장 각속도 (도/초) — 비활성화됨
    static let validationMinElbowVelocity: Double = 0.0

    /// 노이즈 사이클 필터링: 이 값을 초과하는 팔꿈치 각속도는 추적 오류 (도/초)
    static let validationMaxElbowVelocity: Double = 1500.0

    /// 테이크백 정점 → 릴리즈 타이밍 최소값 (ms)
    static let validationMinReleaseTimingMs: Double = 100.0

    /// 테이크백 정점 → 릴리즈 타이밍 최대값 (ms)
    static let validationMaxReleaseTimingMs: Double = 1200.0

    /// 팔꿈치 ROM 필터: |takeback - release| 최솟값 (도)
    static let validationMinRomAngle: Double = 30.0

    // MARK: - Rule Engine 피드백 임계값

    /// 팔꿈치 드리프트 상한 (정규화 단위)
    static let elbowStabilityThreshold: Double = 0.005

    /// 테이크백 각도 하한 (도)
    static let takebackMinAngle: Double = 30.0

    /// 테이크백 각도 상한 (도)
    static let takebackMaxAngle: Double = 110.0

    /// 릴리즈 시 팔꿈치 확장 각속도 하한 (도/초)
    static let elbowExtensionVelMin: Double = 150.0

    /// 몸통 흔들림 X변위 상한 (정규화 단위)
    static let bodySwayThreshold: Double = 0.05

    /// 어깨 분산 상한 (정규화 단위)
    static let shoulderStabilityThreshold: Double = 0.003

    // MARK: - 기타

    /// 하나의 투구로 인정되는 최소 프레임 수
    static let throwMinFrames = 15
}
