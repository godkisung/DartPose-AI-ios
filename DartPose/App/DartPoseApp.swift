// DartPoseApp.swift
// AI 다트 코치 — SwiftUI 앱 진입점
//
// NavigationStack 기반 라우팅으로 HomeView를 루트 화면으로 설정합니다.

import SwiftUI

/// 앱 진입점
@main
struct DartPoseApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            // 앱 전체에 다크 모드 선호 색상 설정
            .preferredColorScheme(.dark)
        }
    }
}
