// PoseExtractor.swift
// MediaPipe Tasks Vision 기반 포즈 추출 모듈
//
// 영상 파일에서 프레임별 관절 좌표를 추출합니다.
// MediaPipe PoseLandmarker를 사용하여 BlazePose 33-keypoint topology를 출력합니다.
//
// ✅ Apple Vision 대비 개선 사항:
//   - 손가락 끝점(index, thumb) 지원 → fingerReleaseSpeed 활성화
//   - 실측 metric Z-depth → detectThrowingSide 3-vote 시스템 복원
//   - FSM 패리티 손실 없음 (Python Ground Truth와 1:1 좌표계 일치)
//
// 좌표계: (0,0)=좌상단, Y↓ (MediaPipe Python과 동일)

import Foundation
import AVFoundation
import MediaPipeTasksVision
import UIKit

/// MediaPipe PoseLandmarker 기반 포즈 추출기.
///
/// 사용 예시:
/// ```swift
/// let extractor = PoseExtractor()
/// let (frames, fps) = try await extractor.extractFromVideo(url: videoURL)
/// ```
class PoseExtractor {

    // MARK: - BlazePose 33-Keypoint 인덱스 매핑

    private enum MP {
        static let leftShoulder  = 11
        static let rightShoulder = 12
        static let leftElbow     = 13
        static let rightElbow    = 14
        static let leftWrist     = 15
        static let rightWrist    = 16
        static let leftIndex     = 19   // 검지 끝
        static let rightIndex    = 20
        static let leftThumb     = 21   // 엄지 끝
        static let rightThumb    = 22
        static let leftHip       = 23
        static let rightHip      = 24
    }

    // MARK: - Public API

    /// 영상 파일에서 프레임별 포즈 데이터를 추출합니다.
    ///
    /// AVAssetReader로 프레임을 순회하며 MediaPipe PoseLandmarker를
    /// video 모드로 실행하여 33개 관절 좌표를 추출합니다.
    ///
    /// - Parameter url: 영상 파일 URL
    /// - Returns: (프레임 데이터 배열, FPS) 튜플
    /// - Throws: 영상 읽기, 모델 로드, 포즈 추출 실패 시 에러
    func extractFromVideo(url: URL) async throws -> ([FrameData], Double) {
        // AVAsset 메타데이터 로드
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw PoseExtractorError.noVideoTrack
        }

        let fps = try await Double(videoTrack.load(.nominalFrameRate))
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)

        let estimatedFrameCount = Int(duration.seconds * fps)
        let orientation = imageOrientation(from: preferredTransform)
        print("[PoseExtractor] 영상 정보: \(Int(naturalSize.width))x\(Int(naturalSize.height)), \(String(format: "%.1f", fps))fps")
        print("[PoseExtractor] preferredTransform: a=\(preferredTransform.a), b=\(preferredTransform.b)")
        print("[PoseExtractor] UIImage orientation: \(orientation.rawValue), 예상 프레임 수: \(estimatedFrameCount)")

        // MediaPipe PoseLandmarker 초기화 (video 모드)
        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") else {
            throw PoseExtractorError.modelNotFound
        }
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .video
        options.numPoses = 1
        let landmarker = try PoseLandmarker(options: options)

        // AVAssetReader 설정
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var frames: [FrameData] = []
        var frameIndex = 0
        var poseSuccessCount = 0
        let dt = 1.0 / fps

        // 프레임 순회
        while let sampleBuffer = output.copyNextSampleBuffer() {
            let timestampMs = Double(frameIndex) * dt * 1000.0

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                frames.append(FrameData(frameIndex: frameIndex, timestampMs: timestampMs))
                frameIndex += 1
                continue
            }

            do {
                let mpImage = try MPImage(pixelBuffer: pixelBuffer, orientation: orientation)
                let result = try landmarker.detect(
                    videoFrame: mpImage,
                    timestampInMilliseconds: Int(timestampMs)
                )

                if let poseLandmarks = result.landmarks.first {
                    let keypoints = convertLandmarks(poseLandmarks)
                    frames.append(FrameData(
                        frameIndex: frameIndex,
                        timestampMs: timestampMs,
                        keypoints: keypoints
                    ))
                    if keypoints != nil { poseSuccessCount += 1 }
                } else {
                    frames.append(FrameData(frameIndex: frameIndex, timestampMs: timestampMs))
                }
            } catch {
                frames.append(FrameData(frameIndex: frameIndex, timestampMs: timestampMs))
            }

            frameIndex += 1
        }

        // 추출 완료 로그
        let successRate = frames.isEmpty ? 0.0 : Double(poseSuccessCount) / Double(frames.count) * 100.0
        print("[PoseExtractor] 총 읽은 프레임: \(frames.count)")
        print("[PoseExtractor] 포즈 추출 성공: \(poseSuccessCount) / \(frames.count) (\(String(format: "%.1f", successRate))%)")
        if poseSuccessCount == 0 {
            print("[PoseExtractor] ⚠️ 포즈 감지 0건 — 모델 파일 경로 또는 영상 내 인물 존재 여부를 확인하세요.")
        }

        return (frames, fps)
    }

    // MARK: - Private

    /// AVFoundation preferredTransform을 UIImage.Orientation으로 변환합니다.
    ///
    /// MPImage 초기화 시 올바른 orientation을 전달하기 위해 사용합니다.
    private func imageOrientation(from transform: CGAffineTransform) -> UIImage.Orientation {
        if abs(transform.a) < 0.1 {
            return transform.b > 0 ? .right : .left
        }
        if transform.a < 0 {
            return .down
        }
        return .up
    }

    /// MediaPipe NormalizedLandmark 배열을 엔진 Keypoints로 변환합니다.
    ///
    /// - 좌표계: MediaPipe normalized (0,0)=좌상단, Y↓ — Python과 동일, 변환 불필요.
    /// - Z: 엉덩이 중점 기준 metric depth (음수 = 카메라에 가까움).
    private func convertLandmarks(_ landmarks: [NormalizedLandmark]) -> Keypoints? {
        guard landmarks.count > MP.rightHip else { return nil }

        func lm(_ idx: Int) -> [Double] {
            let l = landmarks[idx]
            return [Double(l.x), Double(l.y), Double(l.z)]
        }

        let ls = lm(MP.leftShoulder)
        let rs = lm(MP.rightShoulder)

        // 핵심 관절이 원점이면 감지 실패로 처리
        if ls[0] == 0 && ls[1] == 0 && rs[0] == 0 && rs[1] == 0 {
            return nil
        }

        return Keypoints(
            leftShoulder:  ls,
            rightShoulder: rs,
            leftElbow:     lm(MP.leftElbow),
            rightElbow:    lm(MP.rightElbow),
            leftWrist:     lm(MP.leftWrist),
            rightWrist:    lm(MP.rightWrist),
            leftHip:       lm(MP.leftHip),
            rightHip:      lm(MP.rightHip),
            leftThumbTip:  lm(MP.leftThumb),
            rightThumbTip: lm(MP.rightThumb),
            leftIndexTip:  lm(MP.leftIndex),
            rightIndexTip: lm(MP.rightIndex)
            // leftMiddleTip, rightMiddleTip: BlazePose-33에는 중지 끝점 미포함
        )
    }
}

// MARK: - Errors

/// PoseExtractor 에러 정의
enum PoseExtractorError: Error, LocalizedError {
    case noVideoTrack
    case modelNotFound
    case readerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "영상에서 비디오 트랙을 찾을 수 없습니다."
        case .modelNotFound:
            return "MediaPipe 모델 파일(pose_landmarker_full.task)을 번들에서 찾을 수 없습니다. 프로젝트에 파일을 추가했는지 확인하세요."
        case .readerFailed(let msg):
            return "영상 읽기 실패: \(msg)"
        }
    }
}
