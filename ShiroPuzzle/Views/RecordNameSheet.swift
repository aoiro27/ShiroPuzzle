//
//  RecordNameSheet.swift
//  ShiroPuzzle
//
//  TOP5入り：ステップ1＝名前、ステップ2＝音声「いくよ〜」→3・2・1・スタート→5秒録音
//

import AVFoundation
import SwiftUI

struct RecordNameSheet: View {
    let clearTimeSeconds: TimeInterval
    let rank: Int
    let pieceCount: PuzzlePieceCount
    var onSave: () -> Void

    @State private var step: Int = 1
    @State private var playerName: String = ""
    @StateObject private var recordAudio = RecordAudioService()
    @State private var speechSynthesizer: AVSpeechSynthesizer?
    @Environment(\.dismiss) private var dismiss

    // ステップ2: 録音フロー
    @State private var countdownLabel: String? = nil       // "3", "2", "1", "スタート"
    @State private var recordingRemaining: Int? = nil     // 5〜0
    @State private var recordingDone: Bool = false
    @State private var micDenied: Bool = false
    @State private var recordingTask: Task<Void, Never>?

    private static func bestJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let jaVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ja") }
        guard !jaVoices.isEmpty else { return AVSpeechSynthesisVoice(language: "ja-JP") }
        if #available(iOS 16.0, *) {
            return jaVoices.max(by: { a, b in a.quality.rawValue < b.quality.rawValue })
        }
        return jaVoices.first ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }

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
        utterance.volume = 1.0  // 0.0〜1.0 が範囲で、1.0 が最大（API上限）
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 1.1
        synth.speak(utterance)
    }

    /// 録音画面で「しょうりのこえをのこしておこう、いくよ〜」を読み上げ
    private func speakRecordingIntro() {
        let synth = AVSpeechSynthesizer()
        speechSynthesizer = synth
        let utterance = AVSpeechUtterance(string: "しょうりのこえをのこしておこう、いくよ〜")
        utterance.voice = Self.bestJapaneseVoice()
        utterance.volume = 1.0  // 0.0〜1.0 が範囲で、1.0 が最大（API上限）
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.pitchMultiplier = 1.1
        synth.speak(utterance)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", m, s)
    }

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    private func runRecordingSequence() {
        recordingTask = Task { @MainActor in
            let granted = await requestMicPermission()
            guard granted else {
                micDenied = true
                return
            }
            speakRecordingIntro()
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if Task.isCancelled { return }
            for label in ["3", "2", "1", "スタート"] {
                countdownLabel = label
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            countdownLabel = nil
            guard recordAudio.startRecording() else {
                micDenied = true
                return
            }
            for remaining in (1...5).reversed() {
                recordingRemaining = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            _ = recordAudio.stopRecording()
            recordingRemaining = nil
            recordingDone = true
        }
    }

    private func saveAndDismiss() {
        recordingTask?.cancel()
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
                clearTimeSeconds: RecordStore.roundedTime(clearTimeSeconds),
                achievedDate: Date(),
                audioFileName: audioFileName
            ),
            pieceCount: pieceCount
        )
        dismiss()
        onSave()
    }

    var body: some View {
        NavigationStack {
            Group {
                if step == 1 {
                    step1NameView
                } else {
                    step2RecordingView
                }
            }
            .navigationTitle(step == 1 ? "きろくをのこす" : "こえをのこす")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("スキップ") {
                        recordingTask?.cancel()
                        recordAudio.cancelRecording()
                        dismiss()
                        onSave()
                    }
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                if step == 1 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("次へ") { step = 2 }
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                } else if !recordingDone && !micDenied {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("こえなしでのこす") {
                            recordingTask?.cancel()
                            recordAudio.cancelRecording()
                            saveAndDismiss()
                        }
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                    }
                }
            }
            .onAppear {
                if step == 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { speakCongratulations() }
                }
            }
        }
    }

    private var step1NameView: some View {
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

            Spacer()
        }
        .padding(.top, 40)
    }

    @ViewBuilder
    private var step2RecordingView: some View {
        VStack(spacing: 32) {
            if micDenied {
                Text("マイクがつかえません")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("なまえだけきろくするよ")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("のこす") { saveAndDismiss() }
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .padding(.horizontal, 56)
                    .padding(.vertical, 24)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            } else if let label = countdownLabel {
                Text(label)
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Spacer()
            } else if let remaining = recordingRemaining {
                Image(systemName: "mic.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                Text("ろくおんちゅう…")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("のこり \(remaining) びょう")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                Spacer()
            } else if recordingDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("ろくおんおわったよ！")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Spacer()
                Button("のこす") { saveAndDismiss() }
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .padding(.horizontal, 56)
                    .padding(.vertical, 24)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            } else {
                Text("じゅんびちゅう…")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.top, 40)
        .onAppear {
            if step == 2, !micDenied, countdownLabel == nil, recordingRemaining == nil, !recordingDone {
                runRecordingSequence()
            }
        }
    }
}
