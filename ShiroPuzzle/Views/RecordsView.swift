//
//  RecordsView.swift
//  ShiroPuzzle
//
//  ピース数ごとの歴代TOP5と達成日を表示
//

import SwiftUI

struct RecordsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var refreshId = 0
    @State private var showResetConfirmation = false

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ja_JP")
        return f
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(PuzzlePieceCount.allCases, id: \.rawValue) { pieceCount in
                    Section {
                        let records = RecordStore.records(for: pieceCount)
                        if records.isEmpty {
                            Text("まだきろくがありません")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                                HStack {
                                    Text("\(index + 1)位")
                                        .font(.headline)
                                        .frame(width: 36, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.playerName)
                                            .font(.body.bold())
                                        Text(dateFormatter.string(from: record.achievedDate))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(formatTime(record.clearTimeSeconds))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.orange)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("\(pieceCount.rawValue)ピース")
                    }
                }
            }
            .id(refreshId)
            .navigationTitle("きろく")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("きろくをリセット", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
            .confirmationDialog("きろくをリセット", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("すべてけす", role: .destructive) {
                    RecordStore.resetAllRecords()
                    refreshId += 1
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("すべてのきろくをけしてもよいですか？")
            }
        }
    }
}
