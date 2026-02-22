//
//  RecordNameSheet.swift
//  ShiroPuzzle
//
//  TOP5入りしたときのプレイヤー名入力シート（任意で音声録音）
//

import AVFoundation
import SwiftUI

struct RecordNameSheet: View {
    let clearTimeSeconds: TimeInterval
    let rank: Int
    let pieceCount: PuzzlePieceCount
    var onSave: () -> Void

    @State private var playerName: String = ""
    @StateObject private var recordAudio = RecordAudioService()
    @Environment(\.dismiss) private var dismiss

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("おめでとう！ 歴代\(rank)位だよ！")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("\(pieceCount.rawValue)ピースを \(formatTime(clearTimeSeconds)) でクリア")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                TextField("なまえをいれてね", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    Text("こえをのこす（きょかなら）")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if recordAudio.isRecording {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundStyle(.red)
                            Text("ろくおうちゅう…")
                                .foregroundStyle(.secondary)
                            Button("とめる") {
                                _ = recordAudio.stopRecording()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    } else {
                        Button {
                            AVAudioSession.sharedInstance().requestRecordPermission { _ in
                                Task { @MainActor in
                                    _ = recordAudio.startRecording()
                                }
                            }
                        } label: {
                            Label(recordAudio.recordedURL != nil ? "もういちどろくおう" : "こえをろくおう", systemImage: "mic.fill")
                        }
                        .buttonStyle(.bordered)
                        if recordAudio.recordedURL != nil {
                            Text("こえがのこされています")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.vertical, 16)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("きろくをのこす")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("スキップ") {
                        recordAudio.cancelRecording()
                        dismiss()
                        onSave()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("のこす") {
                        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let recordId = UUID()
                        var audioFileName: String? = nil
                        if let url = recordAudio.recordedURL {
                            audioFileName = RecordStore.saveRecording(from: url, recordId: recordId)
                        }
                        recordAudio.clearRecordedURL()
                        RecordStore.addRecord(
                            ClearRecord(
                                id: recordId,
                                playerName: name.isEmpty ? "ななし" : name,
                                clearTimeSeconds: clearTimeSeconds,
                                achievedDate: Date(),
                                audioFileName: audioFileName
                            ),
                            pieceCount: pieceCount
                        )
                        dismiss()
                        onSave()
                    }
                }
            }
        }
    }
}
