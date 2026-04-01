// AnalysisViewModel.swift
// 영상 분석 뷰모델 (MVVM)
//
// 영상 분석 파이프라인을 조율합니다:
// 1. 영상 URL → PoseExtractor로 포즈 추출
// 2. DartAnalyzer로 분석
// 3. FeedbackGenerator로 피드백 생성
// 4. 결과를 @Published로 UI에 전달

import Foundation
import SwiftUI
import PhotosUI

/// 분석 진행 상태
enum AnalysisState: Equatable {
    /// 대기 중 (분석 시작 전)
    case idle
    /// 영상에서 포즈 추출 중
    case extractingPoses(progress: Double)
    /// 투구 분석 중
    case analyzing
    /// 피드백 생성 중
    case generatingFeedback
    /// 분석 완료
    case completed(SessionResult)
    /// 에러 발생
    case error(String)

    static func == (lhs: AnalysisState, rhs: AnalysisState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.analyzing, .analyzing): return true
        case (.generatingFeedback, .generatingFeedback): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

/// 영상 분석 뷰모델.
/// VideoPickerView → AnalysisView → ResultDetailView 흐름을 제어합니다.
@MainActor
class AnalysisViewModel: ObservableObject {

    /// 현재 분석 상태
    @Published var state: AnalysisState = .idle

    /// 분석 결과 (완료 시 설정)
    @Published var sessionResult: SessionResult?

    /// 피드백 문자열
    @Published var feedback: String = ""

    private let feedbackGenerator = FeedbackGenerator()

    // MARK: - Public API

    /// 선택된 영상 URL로 분석을 시작합니다.
    ///
    /// - Parameter videoURL: 분석할 영상 파일 URL
    func startAnalysis(videoURL: URL) async {
        state = .extractingPoses(progress: 0.0)

        do {
            // Step 1: 포즈 추출
            // ✅ Fix: @MainActor 클래스에서 extractFromVideo를 직접 호출하면
            // copyNextSampleBuffer + VNRequest 루프가 메인 스레드를 차단합니다.
            // Task.detached로 분리하여 UI 프리징과 silent failure를 방지합니다.
            let (frames, fps) = try await Task.detached(priority: .userInitiated) { @Sendable in
                let extractor = PoseExtractor()
                return try await extractor.extractFromVideo(url: videoURL)
            }.value

            guard !frames.isEmpty else {
                state = .error("영상에서 프레임을 추출할 수 없습니다.")
                return
            }
            let validCount = frames.filter { $0.keypoints != nil }.count
            print("UI: Video loaded — total frames=\(frames.count), valid keypoints=\(validCount), fps=\(fps)")

            // Step 2: 투구 분석
            state = .analyzing
            let analyzer = DartAnalyzer(fps: fps)

            // 분석은 CPU 집약적이므로 백그라운드에서 실행
            let session = await Task.detached(priority: .userInitiated) {
                analyzer.analyzeSession(frames: frames)
            }.value

            // Step 3: 피드백 생성
            state = .generatingFeedback
            let feedbackText = feedbackGenerator.generate(session: session)

            // Step 4: 결과 설정
            var result = session
            result.feedback = feedbackText
            sessionResult = result
            feedback = feedbackText
            state = .completed(session)

        } catch {
            state = .error("분석 실패: \(error.localizedDescription)")
        }
    }

    /// 분석 상태를 초기화합니다.
    func reset() {
        state = .idle
        sessionResult = nil
        feedback = ""
    }
}
