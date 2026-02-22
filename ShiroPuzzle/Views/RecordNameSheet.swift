//
//  RecordNameSheet.swift
//  ShiroPuzzle
//
//  TOP5入りしたときのプレイヤー名入力シート
//

import SwiftUI

struct RecordNameSheet: View {
    let clearTimeSeconds: TimeInterval
    let rank: Int
    let pieceCount: PuzzlePieceCount
    var onSave: () -> Void

    @State private var playerName: String = ""
    @Environment(\.dismiss) private var dismiss

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("おめでとう！ 歴代\(rank)位だよ！")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("\(pieceCount.rawValue)ピースを \(formatTime(clearTimeSeconds)) でクリア")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                TextField("なまえをいれてね", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("きろくをのこす")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("スキップ") {
                        dismiss()
                        onSave()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("のこす") {
                        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                        RecordStore.addRecord(
                            ClearRecord(
                                playerName: name.isEmpty ? "ななし" : name,
                                clearTimeSeconds: clearTimeSeconds
                            ),
                            pieceCount: pieceCount
                        )
                        dismiss()
                        onSave()
                    }
                }
            }
        }
    }
}
