// FeedbackGenerator.swift
// 코칭 피드백 생성 모듈
//
// 분석 결과를 자연어 한국어 코칭 피드백으로 변환합니다.
// 8개 이슈 템플릿 기반 피드백을 제공합니다.
//
// Python feedback_generator.py → Swift 포팅

import Foundation

/// 이슈 코드 → 한국어 피드백 템플릿 매핑
private let issueTemplates: [String: String] = [
    "elbow_unstable_y": """
        투구 동안 팔꿈치의 높이가 불안정합니다. \
        팔꿈치를 고정하고 전완(forearm)만 움직이도록 의식해보세요.
        """,
    "takeback_too_deep": """
        테이크백(뒤로 당기기)이 너무 깊습니다. \
        다트를 귀 옆까지만 당기되, 팔꿈치가 얼굴 앞으로 나오지 않도록 해보세요.
        """,
    "takeback_too_shallow": """
        테이크백이 너무 얕습니다. \
        좀 더 뒤로 당겨 충분한 가속 구간을 확보하면 정확도가 올라갑니다.
        """,
    "slow_elbow_extension": """
        릴리즈 시 팔꿈치를 펴는 속도가 느립니다. \
        팔꿈치를 스냅하듯 빠르게 이어서 목표 지점을 향해 쭉 뻗어주세요.
        """,
    "body_sway_detected": """
        투구 시 상체가 좌우로 흔들리고 있습니다. \
        양 발에 체중을 고르게 분배하고, 던지는 동안 상체를 고정해보세요.
        """,
    "shoulder_unstable": """
        어깨 높이가 투구 중에 변합니다. \
        어깨를 일정한 높이로 유지하며 전완만으로 던지는 연습을 해보세요.
        """,
    "inconsistent_takeback": """
        투구마다 테이크백(뒤로 당기는) 각도가 다릅니다. \
        매번 같은 위치까지 당기는 연습을 통해 일관성을 높여보세요.
        """,
    "inconsistent_elbow_speed": """
        투구마다 팔꿈치를 펴는 속도가 일정하지 않습니다. \
        같은 리듬과 템포로 던지는 연습이 정확도 향상에 도움됩니다.
        """,
]

/// 코칭 피드백 생성기.
/// 분석 결과의 이슈 목록을 한국어 코칭 메시지로 변환합니다.
class FeedbackGenerator {

    /// 세션 분석 결과를 코칭 피드백 문자열로 변환합니다.
    /// - Parameter session: 세션 분석 결과
    /// - Returns: 한국어 코칭 피드백 문자열
    func generate(session: SessionResult) -> String {
        guard !session.throws_.isEmpty else {
            return "⚠ 분석된 투구가 없습니다. 영상에서 다트 투구 동작이 인식되지 않았습니다."
        }

        var lines: [String] = []
        lines.append("📊 다트 투구 분석 리포트 (\(session.totalThrowsDetected)회 투구)")
        lines.append(String(repeating: "=", count: 50))

        for throwAnalysis in session.throws_ {
            let m = throwAnalysis.metrics

            lines.append("")
            lines.append("🎯 투구 #\(throwAnalysis.throwIndex) (\(throwAnalysis.throwingArm)손)")
            lines.append("   프레임 범위: \(throwAnalysis.frameRange[0]) ~ \(throwAnalysis.frameRange[1])")
            lines.append("   · 팔꿈치 드리프트: \(String(format: "%.4f", m.elbowDriftNorm))")
            lines.append("   · 테이크백 각도: \(String(format: "%.1f", m.takebackAngleDeg))°")
            lines.append("   · 최대 팔꿈치 속도: \(String(format: "%.1f", m.maxElbowVelocityDegS))°/s")
            lines.append("   · 릴리즈 타이밍: \(String(format: "%.0f", m.releaseTimingMs))ms")
            lines.append("   · 상체 흔들림: \(String(format: "%.4f", m.bodySway))")

            if !throwAnalysis.issues.isEmpty {
                lines.append("")
                lines.append("   💡 개선 포인트:")
                for issue in throwAnalysis.issues {
                    let feedback = issueTemplates[issue] ?? "  (알 수 없는 이슈: \(issue))"
                    lines.append("     → \(feedback)")
                }
            } else {
                lines.append("   ✅ 특별한 이슈 없음 — 좋은 폼입니다!")
            }
        }

        // 전체 요약
        let allIssues = session.throws_.flatMap(\.issues)
        lines.append("")
        lines.append(String(repeating: "=", count: 50))

        if !allIssues.isEmpty {
            // 빈도순 정렬
            var issueCounts = [String: Int]()
            for issue in allIssues {
                issueCounts[issue, default: 0] += 1
            }
            let sorted = issueCounts.sorted { $0.value > $1.value }.prefix(3)

            lines.append("📝 전체 요약 (가장 빈번한 이슈):")
            for (issue, count) in sorted {
                lines.append("   · \(issue): \(count)회 / \(session.totalThrowsDetected)회 투구")
            }
        } else {
            lines.append("✅ 전체적으로 안정적인 폼입니다. 잘하고 있어요!")
        }

        return lines.joined(separator: "\n")
    }
}
