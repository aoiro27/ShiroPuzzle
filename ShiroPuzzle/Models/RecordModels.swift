//
//  RecordModels.swift
//  ShiroPuzzle
//
//  クリア時間の記録用モデル
//

import Foundation

/// 1件のクリア記録（プレイヤー名・クリア時間・達成日）
struct ClearRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var playerName: String
    var clearTimeSeconds: TimeInterval
    var achievedDate: Date

    init(id: UUID = UUID(), playerName: String, clearTimeSeconds: TimeInterval, achievedDate: Date = Date()) {
        self.id = id
        self.playerName = playerName
        self.clearTimeSeconds = clearTimeSeconds
        self.achievedDate = achievedDate
    }
}
