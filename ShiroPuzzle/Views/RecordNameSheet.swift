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
    @State private var speechSynthesizer: AVSpeechSynthesizer?
    @Environment(\.dismiss) private var dismiss

    /// インストール済みの日本語音声のうち、品質が最も高いものを選ぶ（Premium > Enhanced > Default）
    private static func bestJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let jaVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ja") }
        guard !jaVoices.isEmpty else { return AVSpeechSynthesisVoice(language: "ja-JP") }
        if #available(iOS 16.0, *) {
            return jaVoices.max(by: { a, b in
                a.quality.rawValue < b.quality.rawValue
            })
        }
        return jaVoices.first ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }

    /// 子供向けに「おめでとう！れきだい◯位だよ、きろくをのこそう」を読み上げる
    private func speakCongratulations() {
        let synth = AVSpeechSynthesizer()
        speechSynthesizer = synth
        let rankText: String
        switch rank {
        case 1: rankText = "いち"
        case 2: rankText = "に"
        case 3: rankText = "さん"
        case 4: rankText = "よん"
        case 5: rankText = "ご"
        default: rankText = "\(rank)"
        }
        let text = "おめでとう！\(rankText)ばんのきろくだよ！"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestJapaneseVoice()
        utterance.volume = 1.0
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 1.1
        synth.speak(utterance)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("おめでとう！ \(rank)ばんのきろくだよ！")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                Text("\(pieceCount.rawValue)ピースを \(formatTime(clearTimeSeconds)) でクリア")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("なまえをいれてね", text: $playerName)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.orange.opacity(0.6), lineWidth: 4)
                            )
                    )
                    .padding(.horizontal, 24)

                VStack(spacing: 20) {
                    if recordAudio.isRecording {
                        HStack(spacing: 16) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.red)
                            Text("ろくおんちゅう…")
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Button("とめる") {
                                _ = recordAudio.stopRecording()
                            }
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 20)
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
                            Label(recordAudio.recordedURL != nil ? "もういちどろくおん" : "こえをのこす", systemImage: "mic.fill")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .padding(.horizontal, 36)
                                .padding(.vertical, 24)
                        }
                        .buttonStyle(.bordered)
                        if recordAudio.recordedURL != nil {
                            Text("こえがのこされています")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.vertical, 24)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("きろくをのこす")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("スキップ") {
                        recordAudio.cancelRecording()
                        dismiss()
                        onSave()
                    }
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    speakCongratulations()
                }
            }
        }
    }
}
