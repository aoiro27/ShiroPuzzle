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
        let text = "おめでとう！れきだい\(rankText)いだよ、きろくをのこそう"
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
                    if recordAudio.isRecording {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundStyle(.red)
                            Text("ろくおんちゅう…")
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
                            Label(recordAudio.recordedURL != nil ? "もういちどろくおん" : "しょうしゃのこえをのこす", systemImage: "mic.fill")
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    speakCongratulations()
                }
            }
        }
    }
}
