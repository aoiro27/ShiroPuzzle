//
//  RecordStore.swift
//  ShiroPuzzle
//
//  ピース数ごとの歴代TOP5をUserDefaultsで永続化
//

import Foundation

enum RecordStore {
    private static let maxRecordsPerPieceCount = 5
    private static let keyPrefix = "clearRecords_"

    private static func key(for pieceCount: PuzzlePieceCount) -> String {
        "\(keyPrefix)\(pieceCount.rawValue)"
    }

    /// 指定ピース数のTOP5を取得（速い順）
    static func records(for pieceCount: PuzzlePieceCount) -> [ClearRecord] {
        guard let data = UserDefaults.standard.data(forKey: key(for: pieceCount)),
              let decoded = try? JSONDecoder().decode([ClearRecord].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.clearTimeSeconds < $1.clearTimeSeconds }
    }

    /// 今回のクリア時間がTOP5に入るか（入る場合、何位か 1...5 を返す。入らない場合は nil）
    static func rankIfInTop5(clearTimeSeconds: TimeInterval, pieceCount: PuzzlePieceCount) -> Int? {
        let current = records(for: pieceCount)
        // 今回より速い既存記録の数 + 1 が順位（同タイムは「抜かれる」ので +1 される）
        let fasterCount = current.filter { $0.clearTimeSeconds < clearTimeSeconds }.count
        let rank = fasterCount + 1
        if current.count < maxRecordsPerPieceCount {
            return rank
        }
        guard rank <= maxRecordsPerPieceCount else { return nil }
        return rank
    }

    /// 記録を追加（TOP5に収まるように保存）
    static func addRecord(_ record: ClearRecord, pieceCount: PuzzlePieceCount) {
        var list = records(for: pieceCount)
        list.append(record)
        list.sort { $0.clearTimeSeconds < $1.clearTimeSeconds }
        list = Array(list.prefix(maxRecordsPerPieceCount))
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: key(for: pieceCount))
    }

    /// すべての記録を削除（4・6・8ピースとも）
    static func resetAllRecords() {
        for pieceCount in PuzzlePieceCount.allCases {
            UserDefaults.standard.removeObject(forKey: key(for: pieceCount))
        }
    }
}
