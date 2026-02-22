//
//  OpeningVideoView.swift
//  ShiroPuzzle
//
//  起動時オープニング動画（mp4）再生。終了時またはタップでスキップしてメインへ。
//

import SwiftUI
import AVFoundation

struct OpeningVideoView: View {
    /// 動画終了 or スキップ時に呼ぶ
    var onFinish: () -> Void

    var body: some View {
        ZStack {
            OpeningVideoPlayerView(onFinish: onFinish)
                .ignoresSafeArea()

            // タップでスキップ
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onFinish()
                }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - AVPlayer を SwiftUI で表示（フルスクリーン・終了検知）

private struct OpeningVideoPlayerView: UIViewRepresentable {
    let onFinish: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = OpeningVideoPlayerUIView()
        view.onFinish = onFinish
        view.setupPlayer()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class OpeningVideoPlayerUIView: UIView {
    var onFinish: (() -> Void)?
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
    }

    func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "opening", withExtension: "mp4") else {
            // 動画がない場合は即メインへ
            DispatchQueue.main.async { [weak self] in self?.onFinish?() }
            return
        }

        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)
        self.player = avPlayer

        let layer = self.layer as! AVPlayerLayer
        layer.player = avPlayer
        layer.videoGravity = .resizeAspect

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.onFinish?()
        }

        avPlayer.play()
    }

    deinit {
        if let o = endObserver {
            NotificationCenter.default.removeObserver(o)
        }
        player?.pause()
    }
}
