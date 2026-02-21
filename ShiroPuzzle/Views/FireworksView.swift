//
//  FireworksView.swift
//  ShiroPuzzle
//
//  CAEmitterLayer を使った花火演出
//

import SwiftUI
import UIKit

struct FireworksView: UIViewRepresentable {
    func makeUIView(context: Context) -> FireworksUIView {
        FireworksUIView()
    }

    func updateUIView(_ uiView: FireworksUIView, context: Context) {
        uiView.setNeedsLayout()
    }
}

final class FireworksUIView: UIView {
    private var rocketLayers: [CAEmitterLayer] = []
    private var burstLayers: [CAEmitterLayer] = []
    private var particleImage: CGImage?
    private var hasFired = false

    override class var layerClass: AnyClass { CALayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        particleImage = makeParticleImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }
        if rocketLayers.isEmpty {
            setupEmitters(width: w, height: h)
        } else {
            updateEmitterPositions(width: w, height: h)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, !hasFired {
            hasFired = true
            fire()
        }
    }

    private func makeParticleImage() -> CGImage? {
        let size: CGFloat = 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: rect)
        }
        return image.cgImage
    }

    /// 打ち上げロケット用（下から上へ）
    private func makeRocketCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = particleImage
        cell.color = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1).cgColor
        cell.alphaRange = 0.1
        cell.alphaSpeed = -0.2
        cell.birthRate = 220
        cell.lifetime = 0.7
        cell.lifetimeRange = 0.2
        cell.velocity = 400
        cell.velocityRange = 100
        cell.emissionRange = 0.12
        cell.emissionLongitude = -.pi / 2
        cell.scale = 0.22
        cell.scaleRange = 0.1
        cell.yAcceleration = 25
        return cell
    }

    /// 開いた花火のパーティクル（はっきり見えるように大きめ・多め）
    private func makeBurstCell(color: UIColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = particleImage
        cell.color = color.cgColor
        cell.redRange = 0.15
        cell.greenRange = 0.15
        cell.blueRange = 0.1
        cell.alphaRange = 0.1
        cell.alphaSpeed = -0.35
        cell.birthRate = 350
        cell.lifetime = 1.6
        cell.lifetimeRange = 0.4
        cell.velocity = 260
        cell.velocityRange = 100
        cell.emissionRange = .pi * 2
        cell.emissionLongitude = -.pi / 2
        cell.scale = 0.28
        cell.scaleRange = 0.12
        cell.scaleSpeed = -0.01
        cell.yAcceleration = 140
        return cell
    }

    private func setupEmitters(width w: CGFloat, height h: CGFloat) {
        let rocketX: [CGFloat] = [w * 0.3, w * 0.5, w * 0.7]
        let rocketY: CGFloat = h * 0.88
        for x in rocketX {
            let layer = CAEmitterLayer()
            layer.frame = bounds
            layer.emitterPosition = CGPoint(x: x, y: rocketY)
            layer.emitterShape = .point
            layer.emitterSize = CGSize(width: 2, height: 2)
            layer.birthRate = 0
            layer.emitterCells = [makeRocketCell()]
            layer.renderMode = .unordered
            self.layer.addSublayer(layer)
            rocketLayers.append(layer)
        }
        let burstPositions: [(CGFloat, CGFloat)] = [
            (w * 0.3, h * 0.28),
            (w * 0.5, h * 0.25),
            (w * 0.7, h * 0.28)
        ]
        let colors: [UIColor] = [
            UIColor(red: 1, green: 0.9, blue: 0.25, alpha: 1),
            UIColor(red: 1, green: 0.35, blue: 0.15, alpha: 1),
            UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 1)
        ]
        for (i, (x, y)) in burstPositions.enumerated() {
            let layer = CAEmitterLayer()
            layer.frame = bounds
            layer.emitterPosition = CGPoint(x: x, y: y)
            layer.emitterShape = .point
            layer.emitterSize = CGSize(width: 1, height: 1)
            layer.birthRate = 0
            layer.emitterCells = [makeBurstCell(color: colors[i])]
            layer.renderMode = .unordered
            self.layer.addSublayer(layer)
            burstLayers.append(layer)
        }
    }

    private func updateEmitterPositions(width w: CGFloat, height h: CGFloat) {
        let rocketX: [CGFloat] = [w * 0.3, w * 0.5, w * 0.7]
        let rocketY: CGFloat = h * 0.88
        for (i, layer) in rocketLayers.enumerated() where i < rocketX.count {
            layer.frame = bounds
            layer.emitterPosition = CGPoint(x: rocketX[i], y: rocketY)
        }
        let burstPositions: [(CGFloat, CGFloat)] = [
            (w * 0.3, h * 0.28),
            (w * 0.5, h * 0.25),
            (w * 0.7, h * 0.28)
        ]
        for (i, layer) in burstLayers.enumerated() where i < burstPositions.count {
            layer.frame = bounds
            layer.emitterPosition = CGPoint(x: burstPositions[i].0, y: burstPositions[i].1)
        }
    }

    private func fire() {
        for layer in rocketLayers {
            layer.birthRate = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            self?.rocketLayers.forEach { $0.birthRate = 0 }
            self?.burstLayers.forEach { $0.birthRate = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.burstLayers.forEach { $0.birthRate = 0 }
        }
    }
}
