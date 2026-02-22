//
//  PuzzleModels.swift
//  ShiroPuzzle
//
//  2歳向けパズル用のモデル定義
//

import SwiftUI
import CoreGraphics

/// パズルのピース数（10ピース以内、2歳向けは6が無難）
enum PuzzlePieceCount: Int, CaseIterable {
    case four = 4   // 2x2
    case six = 6    // 2x3
    case eight = 8  // 2x4

    var columns: Int {
        switch self {
        case .four: return 2
        case .six: return 3
        case .eight: return 4
        }
    }

    var rows: Int {
        rawValue / columns
    }
}

/// 枠・ピースの形（ランダムで割り当て）
enum SlotShapeKind: Equatable {
    case rectangle
    case roundedRect
    case circle
    case ellipse
    case triangle
    case star
}

/// 背景にある「はめる穴」のスロット（ランダム位置・ランダム形）
struct PuzzleSlot: Identifiable, Equatable {
    let id: Int
    let index: Int  // 0..<pieceCount
    var frame: CGRect
    var shapeKind: SlotShapeKind
}

/// ドラッグ可能な1ピース（画像の切り抜き + スロット番号 + 形）
struct PuzzlePiece: Identifiable, Equatable {
    let id: Int
    let slotIndex: Int
    var image: UIImage
    var currentPosition: CGPoint
    var isPlaced: Bool
    var shapeKind: SlotShapeKind

    static func == (lhs: PuzzlePiece, rhs: PuzzlePiece) -> Bool {
        lhs.id == rhs.id && lhs.isPlaced == rhs.isPlaced
    }
}

// MARK: - 形に合わせた SwiftUI Shape（枠・ピースのクリップ用）

struct PuzzlePieceShape: Shape {
    let kind: SlotShapeKind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .rectangle:
            return Path(rect)
        case .roundedRect:
            return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.25)
        case .circle:
            let r = min(rect.width, rect.height) / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        case .ellipse:
            return Path(ellipseIn: rect)
        case .triangle:
            return pathRoundedEquilateralTriangle(in: rect)
        case .star:
            return pathStar(in: rect)
        }
    }

    /// 5角形の星型（rect内に収める）
    private func pathStar(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let R = min(rect.width, rect.height) / 2
        let r = R * 0.42  // 内側の頂点の半径
        let points = 5
        var path = Path()
        for i in 0..<(points * 2) {
            let angle = -.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let radius = i.isMultiple(of: 2) ? R : r
            let x = cx + radius * cos(angle)
            let y = cy + radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    /// 正三角形に近い形で角を丸めた三角形（上向き）
    private func pathRoundedEquilateralTriangle(in rect: CGRect) -> Path {
        let h = min(rect.height, rect.width * CGFloat(3).squareRoot() / 2)
        let halfBase = h / CGFloat(3).squareRoot()
        let cx = rect.midX
        let cy = rect.midY
        let top = CGPoint(x: cx, y: cy - h / 2)
        let bottomLeft = CGPoint(x: cx - halfBase, y: cy + h / 2)
        let bottomRight = CGPoint(x: cx + halfBase, y: cy + h / 2)
        let sideLen = h * 2 / CGFloat(3).squareRoot()
        let r = min(sideLen / 4, 14)
        let cut = r * CGFloat(3).squareRoot()

        func norm(_ p: CGPoint) -> CGPoint {
            let d = (p.x * p.x + p.y * p.y).squareRoot()
            return d > 0 ? CGPoint(x: p.x / d, y: p.y / d) : .zero
        }
        func trim(from v: CGPoint, toward a: CGPoint, by c: CGFloat) -> CGPoint {
            let u = norm(CGPoint(x: a.x - v.x, y: a.y - v.y))
            return CGPoint(x: v.x + u.x * c, y: v.y + u.y * c)
        }

        let tTop = trim(from: top, toward: bottomRight, by: cut)
        let tBrTop = trim(from: bottomRight, toward: top, by: cut)
        let tBrLeft = trim(from: bottomRight, toward: bottomLeft, by: cut)
        let tBlRight = trim(from: bottomLeft, toward: bottomRight, by: cut)
        let tBlTop = trim(from: bottomLeft, toward: top, by: cut)
        let tTopLeft = trim(from: top, toward: bottomLeft, by: cut)

        let bisectorBR = norm(CGPoint(
            x: (top.x - bottomRight.x) + (bottomLeft.x - bottomRight.x),
            y: (top.y - bottomRight.y) + (bottomLeft.y - bottomRight.y)
        ))
        let bisectorBL = norm(CGPoint(
            x: (top.x - bottomLeft.x) + (bottomRight.x - bottomLeft.x),
            y: (top.y - bottomLeft.y) + (bottomRight.y - bottomLeft.y)
        ))
        let bisectorT = norm(CGPoint(
            x: (bottomLeft.x - top.x) + (bottomRight.x - top.x),
            y: (bottomLeft.y - top.y) + (bottomRight.y - top.y)
        ))
        let centerBR = CGPoint(x: bottomRight.x + bisectorBR.x * 2 * r, y: bottomRight.y + bisectorBR.y * 2 * r)
        let centerBL = CGPoint(x: bottomLeft.x + bisectorBL.x * 2 * r, y: bottomLeft.y + bisectorBL.y * 2 * r)
        let centerT = CGPoint(x: top.x + bisectorT.x * 2 * r, y: top.y + bisectorT.y * 2 * r)

        func angle(_ center: CGPoint, _ point: CGPoint) -> Angle {
            Angle(radians: atan2(point.y - center.y, point.x - center.x))
        }

        var p = Path()
        p.move(to: tTop)
        p.addLine(to: tBrTop)
        p.addArc(center: centerBR, radius: r, startAngle: angle(centerBR, tBrTop), endAngle: angle(centerBR, tBrLeft), clockwise: false)
        p.addLine(to: tBlRight)
        p.addArc(center: centerBL, radius: r, startAngle: angle(centerBL, tBlRight), endAngle: angle(centerBL, tBlTop), clockwise: false)
        p.addLine(to: tTopLeft)
        p.addArc(center: centerT, radius: r, startAngle: angle(centerT, tTopLeft), endAngle: angle(centerT, tTop), clockwise: false)
        p.closeSubpath()
        return p
    }
}
