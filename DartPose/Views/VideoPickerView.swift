// VideoPickerView.swift
// 영상 선택 화면
//
// PhotosPicker를 사용하여 갤러리에서 다트 투구 영상을 선택합니다.
// 선택 즉시 AnalysisView로 네비게이션합니다.

import SwiftUI
import PhotosUI

/// 영상 선택 화면.
/// 갤러리에서 영상을 선택하면 분석 화면으로 이동합니다.
struct VideoPickerView: View {
    /// 선택된 PhotosPicker 항목
    @State private var selectedItem: PhotosPickerItem?
    /// 로딩된 영상 URL
    @State private var videoURL: URL?
    /// 로딩 중 상태
    @State private var isLoading = false
    /// 에러 메시지
    @State private var errorMessage: String?
    /// 분석 화면 네비게이션 트리거
    @State private var navigateToAnalysis = false

    var body: some View {
        ZStack {
            // 배경
            Color(red: 0.05, green: 0.05, blue: 0.15)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 안내 텍스트
                VStack(spacing: 8) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.cyan)

                    Text("다트 투구 영상 선택")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text("갤러리 또는 샘플 영상을 선택하세요")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)

                Spacer()

                // 샘플 영상 버튼
                let samples = SampleVideoManager.shared.availableSamples
                if !samples.isEmpty {
                    Menu {
                        ForEach(samples, id: \.filename) { sample in
                            Button(action: {
                                videoURL = sample.url
                                navigateToAnalysis = true
                            }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("샘플 \(sample.name)")
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)

                            Text("샘플 영상 선택")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            style: StrokeStyle(lineWidth: 2, dash: [8])
                                        )
                                        .foregroundColor(.yellow.opacity(0.3))
                                )
                        )
                    }
                    .padding(.horizontal, 24)
                }

                // 영상 선택 버튼
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.cyan)

                        Text("갤러리에서 선택")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 2, dash: [8])
                                    )
                                    .foregroundColor(.cyan.opacity(0.3))
                            )
                    )
                }
                .padding(.horizontal, 24)

                // 에러 메시지
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // 로딩 표시
                if isLoading {
                    ProgressView("영상 로딩 중...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .foregroundColor(.white)
                }

                Spacer()
            }

        }
        .navigationTitle("영상 선택")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToAnalysis) {
            AnalysisView(videoURL: videoURL ?? URL(fileURLWithPath: ""))
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }
            loadVideo(from: item)
        }
    }

    /// PhotosPicker 항목에서 영상 URL을 로드합니다.
    private func loadVideo(from item: PhotosPickerItem) {
        isLoading = true
        errorMessage = nil

        item.loadTransferable(type: VideoTransferable.self) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let video):
                    if let video = video {
                        videoURL = video.url
                        navigateToAnalysis = true
                    } else {
                        errorMessage = "영상을 로드할 수 없습니다."
                    }
                case .failure(let error):
                    errorMessage = "영상 로드 실패: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// PhotosPicker에서 영상 파일을 로드하기 위한 Transferable 구조체
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // 임시 디렉터리에 복사
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "dart_video_\(UUID().uuidString).mov"
            let destURL = tempDir.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: received.file, to: destURL)
            return Self(url: destURL)
        }
    }
}
