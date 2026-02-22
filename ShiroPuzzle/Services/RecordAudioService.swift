//
//  RecordAudioService.swift
//  ShiroPuzzle
//
//  新記録用の音声録音（AVAudioRecorder）
//

import AVFoundation
import Combine
import Foundation

final class RecordAudioService: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordedURL: URL?

    private var recorder: AVAudioRecorder?
    private var tempURL: URL?

    /// 録音を開始。失敗時は false。権限は呼び出し元で事前にリクエストすること。
    func startRecording() -> Bool {
        guard !isRecording else { return true }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            return false
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("record_\(UUID().uuidString).m4a")
        tempURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
        ]
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            isRecording = true
            recordedURL = nil
            return true
        } catch {
            return false
        }
    }

    /// 録音を停止し、録音ファイルのURLを返す（未録音・失敗時は nil）
    func stopRecording() -> URL? {
        guard isRecording, let rec = recorder else { return nil }
        rec.stop()
        recorder = nil
        isRecording = false
        let url = tempURL
        tempURL = nil
        recordedURL = url
        return url
    }

    /// 録音をキャンセル（一時ファイル削除）
    func cancelRecording() {
        if isRecording {
            recorder?.stop()
            recorder = nil
            isRecording = false
        }
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
            tempURL = nil
        }
        recordedURL = nil
    }

    /// 保存後に一時ファイルをクリア
    func clearRecordedURL() {
        recordedURL = nil
    }
}
