// VideoPickerView.swift
// 영상 선택 화면 — 완전 리디자인

import SwiftUI
import PhotosUI

struct VideoPickerView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigateToAnalysis = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            DPAnimatedBackground()

            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 12)

                Spacer()

                selectionStack
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 22)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.8).delay(0.1),
                        value: appeared
                    )

                Spacer()

                statusSection
                    .padding(.bottom, 28)
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
        .onAppear { appeared = true }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("영상 선택")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.dpTextPrimary)

            Text("다트 투구 영상을 선택하면 AI가 자동으로 분석합니다")
                .font(.system(size: 13))
                .foregroundColor(.dpTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .padding(.top, 20)
    }

    // MARK: - Selection Stack

    private var selectionStack: some View {
        VStack(spacing: 14) {
            galleryPickerCard
            sampleVideoCard
            instructionsTip
        }
    }

    // MARK: - Gallery Picker Card

    private var galleryPickerCard: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .videos,
            photoLibrary: .shared()
        ) {
            pickerCard(
                icon: "photo.on.rectangle.angled",
                iconColor: .cyan,
                iconBg: Color.cyan.opacity(0.12),
                title: "갤러리에서 선택",
                subtitle: "직접 촬영한 투구 영상을 분석합니다",
                badge: nil,
                accentBorder: Color.cyan.opacity(0.22)
            )
        }
        .buttonStyle(CardPressStyle())
    }

    // MARK: - Sample Video Card

    @ViewBuilder
    private var sampleVideoCard: some View {
        let samples = SampleVideoManager.shared.availableSamples
        if !samples.isEmpty {
            Menu {
                ForEach(samples, id: \.filename) { sample in
                    Button {
                        videoURL = sample.url
                        navigateToAnalysis = true
                    } label: {
                        Label(sample.name, systemImage: "play.circle.fill")
                    }
                }
            } label: {
                pickerCard(
                    icon: "star.circle.fill",
                    iconColor: .yellow,
                    iconBg: Color.yellow.opacity(0.10),
                    title: "샘플 영상 사용",
                    subtitle: "\(samples.count)개의 샘플 영상이 준비되어 있습니다",
                    badge: "DEMO",
                    accentBorder: Color.yellow.opacity(0.18)
                )
            }
            .buttonStyle(CardPressStyle())
        }
    }

    // MARK: - Instructions Tip

    private var instructionsTip: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.dpBlue.opacity(0.7))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("촬영 팁")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.dpTextPrimary.opacity(0.85))

                Text("측면 또는 약간 비스듬한 각도에서 상체 전체가 보이도록 촬영하면 정확도가 높아집니다.")
                    .font(.system(size: 11))
                    .foregroundColor(.dpTextMuted)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dpBlue.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.dpBlue.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Picker Card Builder

    private func pickerCard(
        icon: String,
        iconColor: Color,
        iconBg: Color,
        title: String,
        subtitle: String,
        badge: String?,
        accentBorder: Color
    ) -> some View {
        HStack(spacing: 18) {
            // Icon bubble
            ZStack {
                Circle()
                    .fill(iconBg)
                    .frame(width: 54, height: 54)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }

            // Labels
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.dpTextPrimary)

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(iconColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(iconColor.opacity(0.10))
                                    .overlay(Capsule().stroke(iconColor.opacity(0.28), lineWidth: 0.75))
                            )
                    }
                }

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.dpTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.dpTextMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.dpSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accentBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        if isLoading {
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    .scaleEffect(0.88)
                Text("영상을 불러오는 중...")
                    .font(.subheadline)
                    .foregroundColor(.dpTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.dpSurface)
                    .overlay(Capsule().stroke(Color.dpBorder, lineWidth: 1))
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if let error = errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red.opacity(0.8))
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.75))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .transition(.opacity)
        }
    }

    // MARK: - Load Video

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

// MARK: - Card Press Button Style

/// Subtle scale-down feedback when a card is tapped.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// PhotosPicker에서 영상 파일을 로드하기 위한 Transferable 구조체
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir  = FileManager.default.temporaryDirectory
            let fileName = "dart_video_\(UUID().uuidString).mov"
            let destURL  = tempDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: received.file, to: destURL)
            return Self(url: destURL)
        }
    }
}
