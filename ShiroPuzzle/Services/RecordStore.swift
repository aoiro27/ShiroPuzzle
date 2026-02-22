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
    private static let recordingsFolderName = "Recordings"

    /// 記録の表示・判定用に秒を小数第2位で丸める
    static func roundedTime(_ seconds: TimeInterval) -> TimeInterval {
        (seconds * 100).rounded() / 100
    }

    private static func key(for pieceCount: PuzzlePieceCount) -> String {
        "\(keyPrefix)\(pieceCount.rawValue)"
    }

    /// 録音ファイルを保存するディレクトリ（なければ作成）
    private static var recordingsDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(recordingsFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 記録に紐づく音声のファイルURL（録音がない場合は nil）
    static func recordAudioURL(for record: ClearRecord) -> URL? {
        guard let name = record.audioFileName, !name.isEmpty else { return nil }
        let url = recordingsDirectory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 録音を永続保存し、記録用のファイル名を返す（失敗時は nil）
    static func saveRecording(from sourceURL: URL, recordId: UUID) -> String? {
        let fileName = "\(recordId.uuidString).m4a"
        let destURL = recordingsDirectory.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return fileName
        } catch {
            return nil
        }
    }

    /// 指定ピース数のTOP5を取得（速い順）
    static func records(for pieceCount: PuzzlePieceCount) -> [ClearRecord] {
        guard let data = UserDefaults.standard.data(forKey: key(for: pieceCount)),
              let decoded = try? JSONDecoder().decode([ClearRecord].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.clearTimeSeconds < $1.clearTimeSeconds }
    }

    /// 今回のクリア時間がTOP5に入るか（入る場合、何位か 1...5 を返す。入らない場合は nil）。小数第2位で比較。
    static func rankIfInTop5(clearTimeSeconds: TimeInterval, pieceCount: PuzzlePieceCount) -> Int? {
        let current = records(for: pieceCount)
        let roundedNew = roundedTime(clearTimeSeconds)
        let fasterCount = current.filter { roundedTime($0.clearTimeSeconds) < roundedNew }.count
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

    /// すべての記録を削除（4・6・8ピースとも）。紐づく録音ファイルも削除する。
    static func resetAllRecords() {
        for pieceCount in PuzzlePieceCount.allCases {
            let list = records(for: pieceCount)
            for record in list where record.audioFileName != nil {
                if let url = recordAudioURL(for: record) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            UserDefaults.standard.removeObject(forKey: key(for: pieceCount))
        }
    }
}
