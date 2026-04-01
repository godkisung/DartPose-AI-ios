// SampleVideoManager.swift
// 샘플 동영상 관리자
//
// 앱 번들에 포함된 샘플 동영상을 관리하고 접근합니다.

import Foundation

/// 샘플 동영상 정보
struct SampleVideo {
    let name: String
    let filename: String
    let url: URL
}

/// 샘플 동영상 관리자
class SampleVideoManager {
    static let shared = SampleVideoManager()
    
    /// 사용 가능한 모든 샘플 동영상 목록
    var availableSamples: [SampleVideo] {
        let sampleNames = [
            "sample_3", "sample_5", "sample_6", "sample_7", "sample_8", "sample_9",
            "sample_10", "sample_12", "sample_13", "sample_14", "sample_15",
            "sample_16", "sample_17", "sample_19", "sample_20"
        ]
        
        return sampleNames.compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else {
                return nil
            }
            return SampleVideo(
                name: name.replacingOccurrences(of: "sample_", with: "#"),
                filename: name,
                url: url
            )
        }
    }
    
    /// 첫 번째 사용 가능한 샘플 동영상 반환
    func getFirstAvailableSample() -> SampleVideo? {
        return availableSamples.first
    }
    
    /// 특정 샘플 동영상 반환
    func getSample(by filename: String) -> SampleVideo? {
        return availableSamples.first { $0.filename == filename }
    }
}
