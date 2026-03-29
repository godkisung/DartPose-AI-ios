// PoseExtractor.swift
// Apple Vision Framework 기반 포즈 추출 모듈
//
// 영상 파일에서 프레임별 관절 좌표를 추출합니다.
// MediaPipe 대신 Apple Vision의 VNDetectHumanBodyPoseRequest를 사용합니다.
//
// ⚠️ 좌표계 차이:
//   - MediaPipe: (0,0)=좌상단, Y↓ (화면 좌표)
//   - Vision:    (0,0)=좌하단, Y↑ (수학 좌표)
//   → 이 모듈에서 Y축을 반전하여 MediaPipe 호환 좌표로 출력합니다.

import Foundation
import AVFoundation
import Vision

/// Apple Vision Framework 기반 포즈 추출기.
///
/// 사용 예시:
/// ```swift
/// let extractor = PoseExtractor()
/// let (frames, fps) = try await extractor.extractFromVideo(url: videoURL)
/// ```
class PoseExtractor {

    // MARK: - Vision → 엔진 관절 매핑

    /// Vision 관절 이름 → 엔진 관절 이름 매핑 테이블
    /// Vision Framework에서 지원하는 관절만 포함 (손가락은 미지원)
    private static let jointMapping: [(VNHumanBodyPoseObservation.JointName, String)] = [
        (.leftShoulder,  "leftShoulder"),
        (.rightShoulder, "rightShoulder"),
        (.leftElbow,     "leftElbow"),
        (.rightElbow,    "rightElbow"),
        (.leftWrist,     "leftWrist"),
        (.rightWrist,    "rightWrist"),
        (.leftHip,       "leftHip"),
        (.rightHip,      "rightHip"),
    ]

    // MARK: - Public API

    /// 영상 파일에서 프레임별 포즈 데이터를 추출합니다.
    ///
    /// 비동기로 AVAssetReader를 통해 프레임을 순회하며
    /// VNDetectHumanBodyPoseRequest로 관절 좌표를 추출합니다.
    ///
    /// - Parameter url: 영상 파일 URL
    /// - Returns: (프레임 데이터 배열, FPS) 튜플
    /// - Throws: 영상 읽기 또는 포즈 추출 실패 시 에러
    func extractFromVideo(url: URL) async throws -> ([FrameData], Double) {
        // AVAsset에서 영상 정보 로드
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw PoseExtractorError.noVideoTrack
        }

        // FPS 및 해상도 로드
        let fps = try await Double(videoTrack.load(.nominalFrameRate))
        let naturalSize = try await videoTrack.load(.naturalSize)
        print("  ℹ 영상 정보: \(Int(naturalSize.width))x\(Int(naturalSize.height)), \(String(format: "%.1f", fps))fps")

        // AVAssetReader 설정
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        // Vision 포즈 요청
        let poseRequest = VNDetectHumanBodyPoseRequest()

        var frames: [FrameData] = []
        var frameIndex = 0
        let dt = 1.0 / fps  // 프레임 간격 (초)

        // 프레임 순회
        while let sampleBuffer = output.copyNextSampleBuffer() {
            let timestampMs = Double(frameIndex) * dt * 1000.0

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                frames.append(FrameData(frameIndex: frameIndex, timestampMs: timestampMs))
                frameIndex += 1
                continue
            }

            // Vision 포즈 감지 실행
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: .up,
                options: [:]
            )

            do {
                try handler.perform([poseRequest])

                if let observation = poseRequest.results?.first {
                    // 관절 좌표 추출 + 좌표계 변환
                    let keypoints = convertObservation(
                        observation: observation,
                        imageHeight: naturalSize.height
                    )
                    frames.append(FrameData(
                        frameIndex: frameIndex,
                        timestampMs: timestampMs,
                        keypoints: keypoints
                    ))
                } else {
                    // 포즈 감지 실패 → keypoints = nil
                    frames.append(FrameData(
                        frameIndex: frameIndex,
                        timestampMs: timestampMs
                    ))
                }
            } catch {
                frames.append(FrameData(
                    frameIndex: frameIndex,
                    timestampMs: timestampMs
                ))
            }

            frameIndex += 1
        }

        print("  ✓ 포즈 추출 완료: \(frames.count)개 프레임")
        return (frames, fps)
    }

    // MARK: - Private

    /// Vision 관절 관측을 엔진 Keypoints로 변환합니다.
    ///
    /// Vision 좌표계(Y↑)를 MediaPipe 호환 좌표계(Y↓)로 변환합니다.
    /// - Y축 반전: y = 1.0 - y (정규화 좌표 기준)
    /// - Z축: Vision에서는 confidence로 대체 (깊이 미지원)
    private func convertObservation(
        observation: VNHumanBodyPoseObservation,
        imageHeight: CGFloat
    ) -> Keypoints? {
        /// 단일 관절 좌표 추출 + Y축 반전
        func getPoint(_ jointName: VNHumanBodyPoseObservation.JointName) -> [Double] {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > 0.1 else {
                return [0, 0, 0]
            }
            // Vision: (0,0)=좌하단, Y↑ → MediaPipe 호환: Y↓
            // Z축은 confidence로 대체 (0~1)
            return [
                Double(point.location.x),       // X: 그대로 (0~1 정규화)
                1.0 - Double(point.location.y),  // Y: 반전 (위가 0이 되도록)
                Double(point.confidence),        // Z: confidence 활용
            ]
        }

        // 모든 관절 추출
        let ls = getPoint(.leftShoulder)
        let rs = getPoint(.rightShoulder)
        let le = getPoint(.leftElbow)
        let re = getPoint(.rightElbow)
        let lw = getPoint(.leftWrist)
        let rw = getPoint(.rightWrist)
        let lh = getPoint(.leftHip)
        let rh = getPoint(.rightHip)

        // 모든 관절이 (0,0,0)이면 감지 실패
        let allCoords = [ls, rs, le, re, lw, rw, lh, rh]
        if allCoords.allSatisfy({ $0[0] == 0 && $0[1] == 0 }) {
            return nil
        }

        return Keypoints(
            leftShoulder: ls,
            rightShoulder: rs,
            leftElbow: le,
            rightElbow: re,
            leftWrist: lw,
            rightWrist: rw,
            leftHip: lh,
            rightHip: rh
            // 손가락 좌표: Vision Framework에서 미지원 → nil (기본값)
        )
    }
}

// MARK: - Errors

/// PoseExtractor 에러 정의
enum PoseExtractorError: Error, LocalizedError {
    case noVideoTrack
    case readerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "영상에서 비디오 트랙을 찾을 수 없습니다."
        case .readerFailed(let msg):
            return "영상 읽기 실패: \(msg)"
        }
    }
}
