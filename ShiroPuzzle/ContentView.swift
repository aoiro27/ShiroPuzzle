//
//  ContentView.swift
//  ShiroPuzzle
//
//  2歳向けパズル：写真を選んで、形に合わせてはめる
//

import SwiftUI

struct ContentView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showRecords = false
    /// ピース数（Int で保持して Picker の binding を確実にする）
    @State private var selectedPieceCountRaw: Int = 6

    private var pieceCount: PuzzlePieceCount {
        PuzzlePieceCount(rawValue: selectedPieceCountRaw) ?? .six
    }

    var body: some View {
        Group {
            if let image = selectedImage {
                NavigationStack {
                    PuzzleView(image: image, pieceCount: pieceCount) {
                        selectedImage = nil
                    }
                }
            } else {
                startView
            }
        }
        .fullScreenCover(isPresented: $showPhotoPicker) {
            PhotoPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showRecords) {
            RecordsView()
        }
    }

    private var titleView: some View {
        let orangeRed = Color(red: 1.0, green: 0.35, blue: 0.2)
        let coral = Color(red: 1.0, green: 0.45, blue: 0.3)
        let creamBg = Color(red: 1.0, green: 0.97, blue: 0.92)
        return HStack(spacing: 16) {
            Image(systemName: "puzzle.piece.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [coral, orangeRed],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .orange.opacity(0.35), radius: 1, x: 0, y: 2)
            Text("しきしろパズル")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [coral, orangeRed],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .orange.opacity(0.5), radius: 0, x: 2, y: 2)
                .shadow(color: Color.white.opacity(0.9), radius: 0, x: -1, y: -1)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(creamBg)
                .shadow(color: .orange.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.4),
                            Color.orange.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }

    private var startView: some View {
        ZStack {
            Color(red: 1.0, green: 0.98, blue: 0.94)
                .ignoresSafeArea()
            Image("StartBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .clipped()

            VStack(spacing: 40) {
                Spacer()
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.orange.gradient)
                titleView
                Spacer()

                VStack(spacing: 24) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("しゃしんをえらぶ", systemImage: "photo.on.rectangle.angled")
                            .font(.system(size: 28, weight: .semibold))
                            .padding(.horizontal, 36)
                            .padding(.vertical, 28)
                            .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 20))
                            .foregroundStyle(.white)
                    }

                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("カメラでとる", systemImage: "camera.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .padding(.horizontal, 36)
                                .padding(.vertical, 28)
                                .background(Color.orange.opacity(0.85).gradient, in: RoundedRectangle(cornerRadius: 20))
                                .foregroundStyle(.white)
                        }
                    }

                    Button {
                        showRecords = true
                    } label: {
                        Label("きろくをみる", systemImage: "trophy.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .padding(.horizontal, 36)
                            .padding(.vertical, 28)
                            .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 20))
                            .foregroundStyle(.white)
                    }

                    Toggle(isOn: $soundEnabled) {
                        Label("サウンド", systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 22, weight: .medium))
                    }
                    .toggleStyle(.button)
                    .padding(.horizontal, 24)

                    // ピース数（選択がはっきりわかるように）
                    VStack(alignment: .center, spacing: 14) {
                        Text("ピースのかず")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.3, blue: 0.28))
                        HStack(spacing: 14) {
                            ForEach(PuzzlePieceCount.allCases, id: \.rawValue) { count in
                                let isSelected = selectedPieceCountRaw == count.rawValue
                                Button {
                                    selectedPieceCountRaw = count.rawValue
                                } label: {
                                    Text("\(count.rawValue)こ")
                                        .font(.system(size: 28, weight: isSelected ? .bold : .regular))
                                        .foregroundStyle(isSelected ? .white : Color(red: 0.35, green: 0.3, blue: 0.28))
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(isSelected ? Color.orange : Color(white: 0.92))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.bottom, 60)
            }
            .onAppear {
                AudioManager.shared.playBGMStart()
            }
            .onChange(of: soundEnabled) { _, enabled in
                if !enabled { AudioManager.shared.stopBGM() }
                else { AudioManager.shared.playBGMStart() }
            }
        }
    }
}

#Preview {
    ContentView()
}
