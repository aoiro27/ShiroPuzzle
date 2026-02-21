//
//  ContentView.swift
//  ShiroPuzzle
//
//  2歳向けパズル：写真を選んで、形に合わせてはめる
//

import SwiftUI

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
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
    }

    private var startView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.95, blue: 0.9),
                    Color(red: 1.0, green: 0.98, blue: 0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange.gradient)
                Text("しろパズル")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(Color(red: 0.15, green: 0.12, blue: 0.1))
                Text("写真を選んで、形に合わせて\nピースをはめよう！")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.35, green: 0.3, blue: 0.28))
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("写真を選ぶ", systemImage: "photo.on.rectangle.angled")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 48)

                    // ピース数（選択がはっきりわかるように）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ピースの数")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(red: 0.35, green: 0.3, blue: 0.28))
                        HStack(spacing: 10) {
                            ForEach(PuzzlePieceCount.allCases, id: \.rawValue) { count in
                                let isSelected = selectedPieceCountRaw == count.rawValue
                                Button {
                                    selectedPieceCountRaw = count.rawValue
                                } label: {
                                    Text("\(count.rawValue)こ")
                                        .font(.body)
                                        .fontWeight(isSelected ? .bold : .regular)
                                        .foregroundStyle(isSelected ? .white : Color(red: 0.35, green: 0.3, blue: 0.28))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(isSelected ? Color.orange : Color(white: 0.92))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 48)
                }
                .padding(.bottom, 60)
            }
            .onAppear {
                AudioManager.shared.playBGMStart()
            }
        }
    }
}

#Preview {
    ContentView()
}
