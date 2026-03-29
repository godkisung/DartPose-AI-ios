# DartPose iOS — AI 다트 코치

Python 다트 투구 분석 엔진의 iOS 네이티브 포팅입니다.

## 요구 사항

- macOS 14+ / Xcode 15+
- iOS 17+ (iPhone)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (프로젝트 생성용)

## 빠른 시작

```bash
# 1. XcodeGen 설치 (Homebrew)
brew install xcodegen

# 2. Xcode 프로젝트 생성
cd darts-ios
xcodegen generate

# 3. Xcode에서 열기
open DartPose.xcodeproj

# 4. iPhone 시뮬레이터 선택 후 빌드 (⌘+R)
```

## 프로젝트 구조

```
DartPose/
├── App/           → 앱 진입점
├── Models/        → 데이터 모델 + 설정 상수
├── Engine/        → 분석 엔진 (Python 포팅)
│   ├── PoseNormalizer     → 좌표 정규화
│   ├── ThrowSegmenter     → FSM 투구 세분화
│   ├── PhaseDetector      → 4-Phase 감지
│   ├── MetricsCalculator  → 10가지 생체역학 메트릭
│   ├── DartAnalyzer       → 통합 파이프라인
│   └── FeedbackGenerator  → 한국어 피드백
├── Vision/        → Apple Vision Framework 포즈 추출
├── ViewModels/    → MVVM 뷰모델
├── Views/         → SwiftUI 화면
└── Utilities/     → 수학 유틸리티 (vDSP 기반)
```

## Python ↔ Swift 매핑

| Python 모듈 | Swift 모듈 | 핵심 변환 |
|---|---|---|
| `models.py` | `Models.swift` | dataclass → Codable struct |
| `config.py` | `Config.swift` | dict → enum static let |
| `pose_normalizer.py` | `PoseNormalizer.swift` | numpy → vDSP |
| `throw_segmenter.py` | `ThrowSegmenter.swift` | FSM 로직 동일 |
| `phase_detector.py` | `PhaseDetector.swift` | 하이브리드 스코어링 동일 |
| `metrics_calculator.py` | `MetricsCalculator.swift` | numpy → MathUtils |
| `dart_analyzer.py` | `DartAnalyzer.swift` | 파이프라인 동일 |
| MediaPipe | Vision Framework | 좌표계 변환 포함 |

## 테스트

```bash
xcodebuild test -scheme DartPose -destination 'platform=iOS Simulator,name=iPhone 15'
```
