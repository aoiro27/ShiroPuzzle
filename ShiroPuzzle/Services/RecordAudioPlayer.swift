//
//  RecordAudioPlayer.swift
//  ShiroPuzzle
//
//  記録に紐づく音声の再生
//

import AVFoundation
import Combine
import Foundation

final class RecordAudioPlayer: NSObject, ObservableObject {
    @Published private(set) var playingRecordId: UUID?

    private var player: AVAudioPlayer?

    /// 録音再生時の音量（BGMより前に聞こえるように）
    private let playbackVolume: Float = 2.0

    func play(url: URL, recordId: UUID) {
        stop()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.volume = playbackVolume
            player = p
            p.play()
            playingRecordId = recordId
            AudioManager.shared.duckBGM()
        } catch {
            playingRecordId = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingRecordId = nil
        AudioManager.shared.restoreBGM()
    }
}

extension RecordAudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.playingRecordId = nil
            AudioManager.shared.restoreBGM()
        }
    }
}
