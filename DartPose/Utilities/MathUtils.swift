// MathUtils.swift
// 수학 유틸리티 모듈
//
// numpy 연산을 대체하는 Swift 유틸리티 함수들입니다.
// Accelerate 프레임워크(vDSP)를 활용하여 고성능 벡터/행렬 연산을 수행합니다.
// iOS Swift 포팅 시 Python numpy 함수와 1:1 매핑됩니다.

import Foundation
import Accelerate  // vDSP 고성능 연산

// MARK: - 3D 벡터 연산

/// 두 3D 벡터의 내적을 계산합니다.
/// - np.dot(a, b) 대체
func dot3D(_ a: [Double], _ b: [Double]) -> Double {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

/// 3D 벡터의 노름(크기)을 계산합니다.
/// - np.linalg.norm(v) 대체
func norm3D(_ v: [Double]) -> Double {
    return sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
}

/// 2D 벡터의 노름(크기)을 계산합니다.
func norm2D(_ v: [Double]) -> Double {
    return sqrt(v[0] * v[0] + v[1] * v[1])
}

/// 두 3D 점 사이의 거리를 계산합니다.
func distance3D(_ a: [Double], _ b: [Double]) -> Double {
    let dx = a[0] - b[0]
    let dy = a[1] - b[1]
    let dz = a[2] - b[2]
    return sqrt(dx * dx + dy * dy + dz * dz)
}

/// 두 2D 점 사이의 거리를 계산합니다.
func distance2D(_ a: [Double], _ b: [Double]) -> Double {
    let dx = a[0] - b[0]
    let dy = a[1] - b[1]
    return sqrt(dx * dx + dy * dy)
}

// MARK: - 각도 계산

/// p2를 꼭짓점으로 하는 3점 각도를 도(degree) 단위로 반환합니다.
/// - PoseNormalizer._angle3d() 대체
/// - Parameters:
///   - p1: 첫 번째 점 (예: 어깨)
///   - p2: 꼭짓점 (예: 팔꿈치)
///   - p3: 세 번째 점 (예: 손목)
/// - Returns: 각도 (도). 유효하지 않은 입력이면 0.0.
func angle3D(p1: [Double], p2: [Double], p3: [Double]) -> Double {
    // p2에서 p1, p3 방향 벡터
    let v1 = [p1[0] - p2[0], p1[1] - p2[1], p1[2] - p2[2]]
    let v2 = [p3[0] - p2[0], p3[1] - p2[1], p3[2] - p2[2]]

    let n1 = norm3D(v1)
    let n2 = norm3D(v2)

    // 벡터 크기가 0에 가까우면 각도 산출 불가
    guard n1 > 1e-8, n2 > 1e-8 else { return 0.0 }

    // 내적 → 코사인 → 각도
    let cosVal = max(-1.0, min(1.0, dot3D(v1, v2) / (n1 * n2)))
    return acos(cosVal) * 180.0 / .pi
}

/// XY 이미지 좌표 기반 p2를 꼭짓점으로 하는 3점 각도를 도(degree) 단위로 반환합니다.
/// Z축을 무시합니다.
///
/// ⚠️ Apple Vision Framework는 Z축을 실제 depth가 아닌 confidence(0~1)로 반환합니다.
/// 팔꿈치 각도 계산에는 이 함수를 사용해야 합니다.
/// - Returns: 각도 (도). 유효하지 않은 입력이면 0.0.
func angle2D(p1: [Double], p2: [Double], p3: [Double]) -> Double {
    let v1 = [p1[0] - p2[0], p1[1] - p2[1]]
    let v2 = [p3[0] - p2[0], p3[1] - p2[1]]

    let n1 = sqrt(v1[0]*v1[0] + v1[1]*v1[1])
    let n2 = sqrt(v2[0]*v2[0] + v2[1]*v2[1])

    guard n1 > 1e-8, n2 > 1e-8 else { return 0.0 }

    let cosVal = max(-1.0, min(1.0, (v1[0]*v2[0] + v1[1]*v2[1]) / (n1 * n2)))
    return acos(cosVal) * 180.0 / .pi
}

// MARK: - 신호 처리 (vDSP 기반)

/// 1D 신호에 이동평균(moving average) 스무딩을 적용합니다.
/// - np.convolve(signal, kernel, "same") 대체
/// - vDSP.convolve를 사용하여 고성능 컨볼루션 수행
/// - Parameters:
///   - signal: 입력 1D 신호
///   - window: 윈도우 크기 (홀수 권장)
/// - Returns: 스무딩된 신호 (같은 길이)
func movingAverage(_ signal: [Double], window: Int) -> [Double] {
    guard window > 1, signal.count > window else { return signal }

    // 홀수 보장 (vDSP 포팅 1:1 매칭)
    let w = window | 1
    let kernel = [Double](repeating: 1.0 / Double(w), count: w)

    // 경계 처리를 위한 패딩
    let halfW = w / 2
    var padded = [Double](repeating: signal[0], count: halfW)
    padded.append(contentsOf: signal)
    padded.append(contentsOf: [Double](repeating: signal[signal.count - 1], count: halfW))

    // vDSP 컨볼루션
    var result = [Double](repeating: 0.0, count: signal.count)
    vDSP_convD(padded, 1, kernel, 1, &result, 1,
               vDSP_Length(signal.count), vDSP_Length(w))

    return result
}

/// 1D 신호에 가우시안 스무딩을 적용합니다.
/// - ThrowSegmenter._gaussianSmooth() 대체
/// - Parameters:
///   - signal: 입력 1D 신호
///   - sigmaSeconds: 가우시안 표준편차 (초 단위)
///   - fps: 프레임레이트
/// - Returns: 스무딩된 신호 (같은 길이)
func gaussianSmooth(_ signal: [Double], sigmaSeconds: Double, fps: Double) -> [Double] {
    guard signal.count > 1 else { return signal }

    // FPS 기반 동적 프레임 환산
    let sigmaFrames = max(1.0, sigmaSeconds * fps)

    // 커널 크기: 홀수 보장
    let kernelSize = Int(6.0 * sigmaFrames) | 1
    let half = kernelSize / 2

    // 가우시안 커널 생성
    var kernel = [Double](repeating: 0.0, count: kernelSize)
    var sum = 0.0
    for i in 0..<kernelSize {
        let x = Double(i - half)
        kernel[i] = exp(-0.5 * (x / sigmaFrames) * (x / sigmaFrames))
        sum += kernel[i]
    }
    // 정규화
    for i in 0..<kernelSize {
        kernel[i] /= sum
    }

    // 경계 처리를 위한 패딩
    var padded = [Double](repeating: signal[0], count: half)
    padded.append(contentsOf: signal)
    padded.append(contentsOf: [Double](repeating: signal[signal.count - 1], count: half))

    // vDSP 컨볼루션
    var result = [Double](repeating: 0.0, count: signal.count)
    vDSP_convD(padded, 1, kernel, 1, &result, 1,
               vDSP_Length(signal.count), vDSP_Length(kernelSize))

    return result
}

/// 1D 신호의 수치 미분(gradient)을 계산합니다.
/// - np.gradient(signal, dt) 대체
/// - 중앙 차분(central difference) 방식
/// - Parameters:
///   - signal: 입력 1D 신호
///   - dt: 시간 간격 (초)
/// - Returns: 미분 신호 (같은 길이)
func gradient(_ signal: [Double], dt: Double) -> [Double] {
    let n = signal.count
    guard n >= 2 else { return [Double](repeating: 0.0, count: n) }

    var result = [Double](repeating: 0.0, count: n)

    // 끝점: 전진/후진 차분
    result[0] = (signal[1] - signal[0]) / dt
    result[n - 1] = (signal[n - 1] - signal[n - 2]) / dt

    // 내부: 중앙 차분
    for i in 1..<(n - 1) {
        result[i] = (signal[i + 1] - signal[i - 1]) / (2.0 * dt)
    }

    return result
}

/// 신호를 0~1 범위로 정규화합니다 (min-max scaling).
/// - PhaseDetector._normalizeSignal() 대체
/// - Parameter signal: 입력 1D 신호
/// - Returns: 정규화된 신호. 범위가 0이면 0 배열 반환.
func normalizeSignal(_ signal: [Double]) -> [Double] {
    guard let vMin = signal.min(), let vMax = signal.max() else {
        return signal
    }
    let range = vMax - vMin
    guard range > 1e-10 else {
        return [Double](repeating: 0.0, count: signal.count)
    }
    return signal.map { ($0 - vMin) / range }
}

// MARK: - 통계 유틸리티

/// 배열의 중앙값을 반환합니다.
/// - np.median() 대체
func median(_ arr: [Double]) -> Double {
    guard !arr.isEmpty else { return 0.0 }
    let sorted = arr.sorted()
    let mid = sorted.count / 2
    if sorted.count % 2 == 0 {
        return (sorted[mid - 1] + sorted[mid]) / 2.0
    }
    return sorted[mid]
}

/// 배열의 분산을 반환합니다.
/// - np.var() 대체
func variance(_ arr: [Double]) -> Double {
    guard arr.count >= 2 else { return 0.0 }
    let mean = arr.reduce(0.0, +) / Double(arr.count)
    let sumSquares = arr.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) }
    return sumSquares / Double(arr.count)
}

/// 배열의 표준편차를 반환합니다.
/// - np.std() 대체
func standardDeviation(_ arr: [Double]) -> Double {
    return sqrt(variance(arr))
}

/// 배열에서 최대값의 인덱스를 반환합니다.
/// - np.argmax() 대체
func argmax(_ arr: [Double]) -> Int {
    guard !arr.isEmpty else { return 0 }
    var maxIdx = 0
    var maxVal = arr[0]
    for i in 1..<arr.count {
        if arr[i] > maxVal {
            maxVal = arr[i]
            maxIdx = i
        }
    }
    return maxIdx
}

/// 배열에서 최소값의 인덱스를 반환합니다.
/// - np.argmin() 대체
func argmin(_ arr: [Double]) -> Int {
    guard !arr.isEmpty else { return 0 }
    var minIdx = 0
    var minVal = arr[0]
    for i in 1..<arr.count {
        if arr[i] < minVal {
            minVal = arr[i]
            minIdx = i
        }
    }
    return minIdx
}

/// 배열의 인덱스를 오름차순 정렬합니다 (값 기준).
/// - np.argsort() 대체
func argsort(_ arr: [Double]) -> [Int] {
    return arr.indices.sorted { arr[$0] < arr[$1] }
}
