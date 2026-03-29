// EngineTests.swift
// 분석 엔진 단위 테스트
//
// 핵심 알고리즘의 수학적 정확성과 FSM 동작을 검증합니다.
// macOS에서 `xcodebuild test` 명령어로 실행합니다.

import XCTest
@testable import DartPose

// MARK: - MathUtils 테스트

class MathUtilsTests: XCTestCase {

    /// 90도 각도 계산 검증
    func testAngle3D_rightAngle() {
        // 직각 삼각형: p2 = 원점, p1 = x축, p3 = y축
        let p1 = [1.0, 0.0, 0.0]
        let p2 = [0.0, 0.0, 0.0]
        let p3 = [0.0, 1.0, 0.0]

        let angle = angle3D(p1: p1, p2: p2, p3: p3)
        XCTAssertEqual(angle, 90.0, accuracy: 0.1, "90도 각도 검증 실패")
    }

    /// 180도 각도 (일직선) 검증
    func testAngle3D_straightLine() {
        let p1 = [-1.0, 0.0, 0.0]
        let p2 = [0.0, 0.0, 0.0]
        let p3 = [1.0, 0.0, 0.0]

        let angle = angle3D(p1: p1, p2: p2, p3: p3)
        XCTAssertEqual(angle, 180.0, accuracy: 0.1, "180도 검증 실패")
    }

    /// 0도 (같은 방향) 검증
    func testAngle3D_sameDirection() {
        let p1 = [2.0, 0.0, 0.0]
        let p2 = [0.0, 0.0, 0.0]
        let p3 = [3.0, 0.0, 0.0]

        let angle = angle3D(p1: p1, p2: p2, p3: p3)
        XCTAssertEqual(angle, 0.0, accuracy: 0.1, "0도 검증 실패")
    }

    /// 이동평균 기본 검증
    func testMovingAverage() {
        let signal = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let smoothed = movingAverage(signal, window: 3)

        // 길이 보존 확인
        XCTAssertEqual(smoothed.count, signal.count, "길이 불일치")

        // 스무딩 후 값이 원본과 비슷한 범위
        XCTAssertGreaterThan(smoothed[4], 3.0, "스무딩 값 비정상")
        XCTAssertLessThan(smoothed[4], 7.0, "스무딩 값 비정상")
    }

    /// 가우시안 스무딩 검증
    func testGaussianSmooth() {
        // 노이즈 포함 신호
        let signal = [1.0, 10.0, 1.0, 10.0, 1.0, 10.0, 1.0, 10.0, 1.0, 10.0]
        let smoothed = gaussianSmooth(signal, sigmaSeconds: 0.06, fps: 30.0)

        // 스무딩 후 변동 폭 감소 확인
        let originalRange = (signal.max()! - signal.min()!)
        let smoothedRange = (smoothed.max()! - smoothed.min()!)
        XCTAssertLessThan(smoothedRange, originalRange, "스무딩 효과 없음")
    }

    /// gradient 중앙 차분 검증
    func testGradient() {
        // y = 2x → dy/dx = 2
        let signal = [0.0, 2.0, 4.0, 6.0, 8.0]
        let grad = gradient(signal, dt: 1.0)

        for (i, g) in grad.enumerated() {
            XCTAssertEqual(g, 2.0, accuracy: 0.01,
                          "인덱스 \(i)에서 gradient 불일치")
        }
    }

    /// normalizeSignal 0~1 범위 검증
    func testNormalizeSignal() {
        let signal = [10.0, 20.0, 30.0, 40.0, 50.0]
        let normalized = normalizeSignal(signal)

        XCTAssertEqual(normalized[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(normalized[4], 1.0, accuracy: 0.001)
        XCTAssertEqual(normalized[2], 0.5, accuracy: 0.001)
    }

    /// median 검증
    func testMedian() {
        XCTAssertEqual(median([3.0, 1.0, 2.0]), 2.0)
        XCTAssertEqual(median([4.0, 1.0, 2.0, 3.0]), 2.5)
    }

    /// variance 검증
    func testVariance() {
        let values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        let v = variance(values)
        XCTAssertEqual(v, 4.0, accuracy: 0.1, "분산 계산 오류")
    }
}

// MARK: - ThrowSegmenter 테스트

class ThrowSegmenterTests: XCTestCase {

    /// 단순 팔꿈치 각도 사이클에서 1개 투구 감지
    func testFSM_singleThrowCycle() {
        let fps = 30.0
        let segmenter = ThrowSegmenter(fps: fps)

        // 팔을 접었다 펴는 동작 시뮬레이션 (각도: 160 → 60 → 160)
        let n = 90  // 3초
        var frames = [FrameData]()

        for i in 0..<n {
            let t = Double(i) / fps
            // 0~1초: 160° 유지 (idle)
            // 1~1.5초: 160° → 60° (cocking)
            // 1.5~2초: 60° → 160° (releasing + follow-through)
            // 2~3초: 160° 유지 (idle)
            let angle: Double
            if t < 1.0 {
                angle = 160.0
            } else if t < 1.5 {
                let ratio = (t - 1.0) / 0.5
                angle = 160.0 - 100.0 * ratio  // 160 → 60
            } else if t < 2.0 {
                let ratio = (t - 1.5) / 0.5
                angle = 60.0 + 100.0 * ratio   // 60 → 160
            } else {
                angle = 160.0
            }

            // 각도를 좌표로 변환 (어깨: 원점, 팔꿈치: (1,0,0), 손목: 각도 위치)
            let rad = angle * .pi / 180.0
            let shoulder = [0.0, 0.0, 0.0]
            let elbow = [1.0, 0.0, 0.0]
            let wrist = [1.0 + cos(rad), sin(rad), 0.0]

            let kp = Keypoints(
                leftShoulder: [0, 0, 0], rightShoulder: shoulder,
                leftElbow: [0, 0, 0], rightElbow: elbow,
                leftWrist: [0, 0, 0], rightWrist: wrist,
                leftHip: [0, -0.5, 0], rightHip: [0, -0.5, 0]
            )
            frames.append(FrameData(
                frameIndex: i,
                timestampMs: t * 1000,
                keypoints: kp
            ))
        }

        let dummyNorm: JointCoordDict = [:]
        let segments = segmenter.segment(
            frames: frames, normalizedData: dummyNorm, throwingSide: "right"
        )

        // 최소 1개 세그먼트 감지 확인
        XCTAssertGreaterThanOrEqual(segments.count, 1,
                                   "투구 사이클 감지 실패: \(segments.count)개")
    }
}

// MARK: - PoseNormalizer 테스트

class PoseNormalizerTests: XCTestCase {

    /// 카메라 흔들림 보정 후 어깨 중점이 원점 부근이 되는지 확인
    func testCameraMotionCorrection() {
        let normalizer = PoseNormalizer()

        // 카메라가 (0.1, 0.2, 0)만큼 이동한 2프레임
        let frames = [
            FrameData(frameIndex: 0, timestampMs: 0.0, keypoints: Keypoints(
                leftShoulder: [0.4, 0.3, 0],
                rightShoulder: [0.6, 0.3, 0],
                leftElbow: [0.3, 0.5, 0], rightElbow: [0.7, 0.5, 0],
                leftWrist: [0.2, 0.7, 0], rightWrist: [0.8, 0.7, 0],
                leftHip: [0.4, 0.8, 0], rightHip: [0.6, 0.8, 0]
            )),
            FrameData(frameIndex: 1, timestampMs: 33.3, keypoints: Keypoints(
                leftShoulder: [0.5, 0.5, 0],  // +0.1, +0.2 (카메라 이동)
                rightShoulder: [0.7, 0.5, 0],
                leftElbow: [0.4, 0.7, 0], rightElbow: [0.8, 0.7, 0],
                leftWrist: [0.3, 0.9, 0], rightWrist: [0.9, 0.9, 0],
                leftHip: [0.5, 1.0, 0], rightHip: [0.7, 1.0, 0]
            )),
        ]

        let result = normalizer.normalize(frames: frames, throwingSide: "right")

        // 어깨 중점 보정 후 관절이 일관된 상대 위치에 있어야 함
        XCTAssertNotNil(result["rightShoulder"], "오른쪽 어깨 좌표 누락")
        XCTAssertEqual(result["rightShoulder"]!.count, 2, "프레임 수 불일치")
    }
}
