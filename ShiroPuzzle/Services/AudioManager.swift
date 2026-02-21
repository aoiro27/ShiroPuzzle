//
//  AudioManager.swift
//  ShiroPuzzle
//
//  BGM・効果音の再生。バンドルに以下を入れると再生:
//  - bgm_start.mp3 … 最初の画面用BGM（ループ）
//  - bgm_game.mp3  … ゲーム画面用BGM（ループ）
//  - success / wrong … 正解・不正解の効果音（.wav / .mp3 / .m4a）
//  - clear … クリア時の効果音（.wav / .mp3 / .m4a）
//  ファイルが無い場合は効果音のみシステム音でフォールバック
//

import AVFoundation
import AudioToolbox
import SwiftUI

final class AudioManager: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()

    private var bgmPlayer: AVAudioPlayer?
    /// 効果音再生中は参照を保持（再生終了まで保持して途中で切れないようにする）
    private var sfxPlayer: AVAudioPlayer?

    private override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // 再生できなくてもクラッシュしない
        }
    }

    // MARK: - BGM

    /// 最初の画面用BGM（bgm_start.mp3 / .m4a）
    func playBGMStart() {
        stopBGM()
        guard let url = urlForBGM(resource: "bgm_start") else { return }
        startBGMPlayer(url: url)
    }

    /// ゲーム画面用BGM（bgm_game.mp3 / .m4a）
    func playBGMGame() {
        stopBGM()
        guard let url = urlForBGM(resource: "bgm_game") else { return }
        startBGMPlayer(url: url)
    }

    private func urlForBGM(resource: String) -> URL? {
        Bundle.main.url(forResource: resource, withExtension: "mp3")
            ?? Bundle.main.url(forResource: resource, withExtension: "m4a")
    }

    private func startBGMPlayer(url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.35
            player.prepareToPlay()
            player.play()
            bgmPlayer = player
        } catch {
            bgmPlayer = nil
        }
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }

    // MARK: - 効果音

    func playSuccess() {
        if !playSFX(resource: "success", extensions: ["wav", "mp3", "m4a"]) {
            AudioServicesPlaySystemSound(1057) // 短いポップ音
        }
    }

    func playWrong() {
        if !playSFX(resource: "wrong", extensions: ["wav", "mp3", "m4a"]) {
            AudioServicesPlaySystemSound(1073) // エラー風
        }
    }

    /// クリア時（clear.mp3 / .wav / .m4a）。BGMを止めてクリア音を強調
    func playClear() {
        stopBGM()
        if !playSFX(resource: "clear", extensions: ["wav", "mp3", "m4a"]) {
            AudioServicesPlaySystemSound(1057)
        }
    }

    /// 戻り値: 再生できたか
    private func playSFX(resource: String, extensions: [String]) -> Bool {
        guard let url = extensions.lazy.compactMap({ Bundle.main.url(forResource: resource, withExtension: $0) }).first else { return false }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.delegate = self
            player.prepareToPlay()
            sfxPlayer = player
            player.play()
            return true
        } catch {
            sfxPlayer = nil
            return false
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player === sfxPlayer {
            sfxPlayer = nil
        }
    }
}
