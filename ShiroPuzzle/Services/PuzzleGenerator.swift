//
//  PuzzleGenerator.swift
//  ShiroPuzzle
//
//  ランダム配置・ランダム形のスロットとピースを生成
//

import SwiftUI
import CoreGraphics

private let allShapeKinds: [SlotShapeKind] = [.rectangle, .roundedRect, .circle, .ellipse, .triangle]

enum PuzzleGenerator {
    /// 枠をランダムな位置・ランダムな形で配置する
    static func makeSlots(
        pieceCount: PuzzlePieceCount,
        in rect: CGRect,
        inset: CGFloat = 24
    ) -> [PuzzleSlot] {
        guard rect.width > 0, rect.height > 0,
              rect.width.isFinite, rect.height.isFinite else { return [] }
        let n = pieceCount.rawValue
        let usable = rect.insetBy(dx: inset, dy: inset)
        guard usable.width > 0, usable.height > 0 else { return [] }
        let baseSize = min(usable.width, usable.height) / CGFloat(max(2, Int(Double(n).squareRoot() + 1.5)))
        let minSize = baseSize * 0.72
        let maxSize = baseSize * 1.42
        var slots: [PuzzleSlot] = []
        var attempt = 0
        let maxAttempts = 500
        while slots.count < n, attempt < maxAttempts {
            attempt += 1
            let kind = allShapeKinds.randomElement()!
            let w: CGFloat
            let h: CGFloat
            switch kind {
            case .circle:
                let s = CGFloat.random(in: minSize...maxSize)
                w = s; h = s
            case .ellipse:
                w = CGFloat.random(in: minSize...maxSize)
                h = CGFloat.random(in: minSize...maxSize)
            default:
                w = CGFloat.random(in: minSize...maxSize)
                h = CGFloat.random(in: minSize...maxSize)
            }
            let x = usable.minX + CGFloat.random(in: 0...max(0, usable.width - w))
            let y = usable.minY + CGFloat.random(in: 0...max(0, usable.height - h))
            let frame = CGRect(x: x, y: y, width: w, height: h)
            let overlaps = slots.contains { other in
                !frame.intersection(other.frame).isNull
            }
            if !overlaps {
                slots.append(PuzzleSlot(id: slots.count, index: slots.count, frame: frame, shapeKind: kind))
            }
        }
        // 足りない分は試行回数を増やして重なりなしで配置
        var fallbackAttempt = 0
        let fallbackMaxAttempts = 400
        while slots.count < n, fallbackAttempt < fallbackMaxAttempts {
            fallbackAttempt += 1
            let kind = allShapeKinds.randomElement()!
            let w = CGFloat.random(in: minSize...maxSize)
            let h = (kind == .circle) ? w : CGFloat.random(in: minSize...maxSize)
            let x = usable.minX + CGFloat.random(in: 0...max(0, usable.width - w))
            let y = usable.minY + CGFloat.random(in: 0...max(0, usable.height - h))
            let frame = CGRect(x: x, y: y, width: w, height: h)
            let overlaps = slots.contains { other in !frame.intersection(other.frame).isNull }
            if !overlaps {
                slots.append(PuzzleSlot(id: slots.count, index: slots.count, frame: frame, shapeKind: kind))
            }
        }
        // それでも足りない場合のみ重なりを許容して追加（無限ループ防止）
        while slots.count < n {
            let kind = allShapeKinds.randomElement()!
            let w = CGFloat.random(in: minSize...maxSize)
            let h = (kind == .circle) ? w : CGFloat.random(in: minSize...maxSize)
            let x = usable.minX + CGFloat.random(in: 0...max(0, usable.width - w))
            let y = usable.minY + CGFloat.random(in: 0...max(0, usable.height - h))
            let frame = CGRect(x: x, y: y, width: w, height: h)
            slots.append(PuzzleSlot(id: slots.count, index: slots.count, frame: frame, shapeKind: kind))
        }
        return slots
    }

    /// 向きを .up に正規化した画像を返す（ボード表示とピース切り抜きで同一画像を使うため）
    static func normalizedImage(for image: UIImage) -> UIImage? {
        guard image.imageOrientation != .up else { return image }
        return drawImageWithOrientationUp(image)
    }

    /// 各スロットの frame（画面座標）に対応する画像領域を切り出し。画像は scaledToFill(fullW,fullH) で表示しているときの viewOffset/fillScale で変換
    static func makePieceImages(
        from image: UIImage,
        slots: [PuzzleSlot],
        viewOffset: CGPoint,
        fillScale: CGFloat
    ) -> [UIImage] {
        guard !slots.isEmpty, fillScale > 0 else { return [] }
        let imageW = image.size.width
        let imageH = image.size.height
        guard imageW > 0, imageH > 0 else { return [] }
        var result: [UIImage] = []
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        for slot in slots {
            let f = slot.frame
            let cropX = (f.minX - viewOffset.x) / fillScale
            let cropY = (f.minY - viewOffset.y) / fillScale
            let cropW = f.width / fillScale
            let cropH = f.height / fillScale
            guard cropW >= 1, cropH >= 1 else { continue }
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropW, height: cropH), format: format)
            let cropped = renderer.image { _ in
                image.draw(at: CGPoint(x: -cropX, y: -cropY))
            }
            result.append(cropped)
        }
        return result
    }

    private static func drawImageWithOrientationUp(_ image: UIImage) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let drawn = renderer.image { _ in
            image.draw(at: .zero)
        }
        return drawn
    }

    /// 初期ピースリスト（未配置、下部に並べる位置・形情報付き）
    static func makePieces(
        pieceImages: [UIImage],
        initialPositions: [CGPoint],
        shapeKinds: [SlotShapeKind]
    ) -> [PuzzlePiece] {
        zip(pieceImages, initialPositions).enumerated().map { idx, pair in
            PuzzlePiece(
                id: idx,
                slotIndex: idx,
                image: pair.0,
                currentPosition: pair.1,
                isPlaced: false,
                shapeKind: idx < shapeKinds.count ? shapeKinds[idx] : .rectangle
            )
        }
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
