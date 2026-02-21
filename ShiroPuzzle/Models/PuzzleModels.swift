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
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
}
