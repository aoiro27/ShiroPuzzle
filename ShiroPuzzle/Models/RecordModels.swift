//
//  RecordModels.swift
//  ShiroPuzzle
//
//  クリア時間の記録用モデル
//

import Foundation

/// 1件のクリア記録（プレイヤー名・クリア時間・達成日・任意の音声）
struct ClearRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var playerName: String
    var clearTimeSeconds: TimeInterval
    var achievedDate: Date
    /// 録音がある場合のファイル名（Recordings フォルダ内）
    var audioFileName: String?

    init(id: UUID = UUID(), playerName: String, clearTimeSeconds: TimeInterval, achievedDate: Date = Date(), audioFileName: String? = nil) {
        self.id = id
        self.playerName = playerName
        self.clearTimeSeconds = clearTimeSeconds
        self.achievedDate = achievedDate
        self.audioFileName = audioFileName
    }

    enum CodingKeys: String, CodingKey {
        case id, playerName, clearTimeSeconds, achievedDate, audioFileName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        playerName = try c.decode(String.self, forKey: .playerName)
        clearTimeSeconds = try c.decode(TimeInterval.self, forKey: .clearTimeSeconds)
        achievedDate = try c.decode(Date.self, forKey: .achievedDate)
        audioFileName = try c.decodeIfPresent(String.self, forKey: .audioFileName)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(playerName, forKey: .playerName)
        try c.encode(clearTimeSeconds, forKey: .clearTimeSeconds)
        try c.encode(achievedDate, forKey: .achievedDate)
        try c.encodeIfPresent(audioFileName, forKey: .audioFileName)
    }
}
