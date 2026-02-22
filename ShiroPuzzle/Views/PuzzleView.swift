//
//  PuzzleView.swift
//  ShiroPuzzle
//
//  形に合わせてはめるパズル画面（背景スロット + ドラッグでピースをはめる）
//

import SwiftUI

private struct TrayBounds: Equatable {
    var top: CGFloat
    var bottom: CGFloat
}

private struct TrayBoundsKey: PreferenceKey {
    static var defaultValue: TrayBounds? { nil }
    static func reduce(value: inout TrayBounds?, nextValue: () -> TrayBounds?) {
        if let next = nextValue() { value = next }
    }
}

/// 初回レイアウト確定後に枠・ピース生成で使う値（Preference で渡し、遅延タスクで参照）
private struct LayoutContext: Equatable {
    var rect: CGRect
    var viewOffset: CGPoint
    var fillScale: CGFloat
    var fullW: CGFloat
    var fullH: CGFloat
    var safeBottom: CGFloat
    var trayHeight: CGFloat
}

private struct LayoutContextKey: PreferenceKey {
    static var defaultValue: LayoutContext? { nil }
    static func reduce(value: inout LayoutContext?, nextValue: () -> LayoutContext?) {
        if let next = nextValue() { value = next }
    }
}

/// 不正解時の「首振り」エフェクト（左右に振ってから戻す）
private struct WrongShakeEffect: ViewModifier {
    let isActive: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: isActive) { _, active in
                if active { runShake() } else { offset = 0 }
            }
    }

    private func runShake() {
        let steps: [CGFloat] = [12, -12, 8, -8, 4, -4, 0]
        Task { @MainActor in
            for step in steps {
                withAnimation(.easeInOut(duration: 0.04)) {
                    offset = step
                }
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
        }
    }
}

/// ピースがハマったときの「揺れ＋フラッシュ」エフェクト
private struct PlaceSuccessEffect: ViewModifier {
    let trigger: Int
    @State private var shakeOffset: CGFloat = 0
    @State private var flashOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .overlay {
                Color.white
                    .opacity(flashOpacity)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
            .onChange(of: trigger) { _, _ in
                runShake()
                runFlash()
            }
    }

    private func runShake() {
        let steps: [CGFloat] = [6, -6, 4, -4, 2, -2, 0]
        Task { @MainActor in
            for step in steps {
                withAnimation(.easeInOut(duration: 0.03)) {
                    shakeOffset = step
                }
                try? await Task.sleep(nanoseconds: 32_000_000)
            }
        }
    }

    private func runFlash() {
        withAnimation(.easeOut(duration: 0.12)) {
            flashOpacity = 0.4
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                flashOpacity = 0
            }
        }
    }
}

struct PuzzleView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    let image: UIImage
    let pieceCount: PuzzlePieceCount
    /// スタート画面に戻る（「写真を選び直す」で呼ぶ）
    var onBackToStart: () -> Void = {}
    @State private var slots: [PuzzleSlot] = []
    @State private var pieces: [PuzzlePiece] = []
    @State private var boardRect: CGRect = .zero
    @State private var pieceSize: CGSize = .zero
    @State private var allPlaced = false
    @State private var showCelebration = false
    /// もういちど用：ピースの初期位置（下部トレイ内に縮小して並んだ位置）
    @State private var initialPiecePositions: [CGPoint] = []
    /// トレイ内でのピース縮小率（枠内に収める、1.0=等倍）
    @State private var trayPieceScale: CGFloat = 1.0
    /// 向き正規化した画像（ボード表示とピース切り抜きで同一にする）
    @State private var displayImage: UIImage?
    /// 「もういちど」で枠・ピースを再生成するためのカウンタ（.id でビュー再生成 → onAppear で再実行）
    @State private var regenerateCount = 0
    /// 初回のみレイアウト確定を待ってから枠・ピース生成する（初回だけ geo が未確定でずれるため）
    @State private var hasCompletedInitialLayout = false
    /// 現在のレイアウト（Preference で更新。初回遅延タスクでこの値を使って再生成）
    @State private var lastLayoutContext: LayoutContext?
    /// ピースがハマったときのエフェクト用（インクリメントで揺れ＋フラッシュ発火）
    @State private var placeEffectTrigger = 0
    /// 正解時「ぱちん」＋枠の光用（はまった直後のピースIDとスロットindex）
    @State private var lastPlacedPieceId: Int?
    @State private var lastPlacedSlotIndex: Int?
    /// 不正解時「首振り」用（戻す直前のピースID）
    @State private var shakingPieceId: Int?
    /// クリア時間計測用：ゲーム開始時刻（ピース生成完了時にセット）
    @State private var gameStartDate: Date?
    /// TOP5入りしたときの記録用：名前入力シート表示
    @State private var showRecordNameSheet = false
    /// 記録保存するクリア時間（秒）
    @State private var pendingClearTimeSeconds: TimeInterval = 0
    /// 記録の順位（1〜5）
    @State private var pendingRecordRank: Int = 0

    private let slotInset: CGFloat = 12
    private let snapThreshold: CGFloat = 50

    /// レイアウトが有効になるまでの最小サイズ（0以下や未確定でフレーム計算をしない）
    private let minBoardSize: CGFloat = 200

    /// 上部ボタンエリアの高さ（写真を選び直す）
    private let topBarHeight: CGFloat = 56
    /// 下部ピース置き場の高さ（サフェリア下に収めつつピースが入るよう固定）
    private let pieceTrayHeight: CGFloat = 200

    var body: some View {
        GeometryReader { geo in
            puzzleContent(geo: geo)
                .modifier(PlaceSuccessEffect(trigger: placeEffectTrigger))
        }
        .onPreferenceChange(LayoutContextKey.self) { ctx in
            lastLayoutContext = ctx
        }
        .onPreferenceChange(TrayBoundsKey.self) { bounds in
            guard let b = bounds else { return }
            let trayTop = b.top
            let trayBottom = b.bottom
            var updated = pieces
            var changed = false
            for i in updated.indices where !updated[i].isPlaced {
                let piece = updated[i]
                let ph = slots.first(where: { $0.index == piece.slotIndex })?.frame.height ?? pieceSize.height
                let halfH = (ph * trayPieceScale) / 2
                let margin: CGFloat = 20
                let trayMinY = trayTop + halfH + margin
                let trayMaxY = trayBottom - halfH - margin
                let clampedY = min(max(piece.currentPosition.y, trayMinY), trayMaxY)
                if abs(piece.currentPosition.y - clampedY) > 0.5 {
                    updated[i].currentPosition = CGPoint(x: piece.currentPosition.x, y: clampedY)
                    changed = true
                }
            }
            if changed { pieces = updated }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button {
                    onBackToStart()
                } label: {
                    Label("しゃしんをえらびなおす", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Spacer()
                Toggle(isOn: $soundEnabled) {
                    Label("サウンド", systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.headline)
                }
                .toggleStyle(.button)
                .padding(.trailing, 12)
            }
            .background(.ultraThinMaterial)
        }
        .navigationBarHidden(true)
        .onChange(of: pieces.filter(\.isPlaced).count) { _, count in
            allPlaced = count == pieceCount.rawValue
            if allPlaced {
                showCelebration = true
                AudioManager.shared.playClear()
                if let start = gameStartDate {
                    let elapsed = Date().timeIntervalSince(start)
                    if let rank = RecordStore.rankIfInTop5(clearTimeSeconds: elapsed, pieceCount: pieceCount) {
                        pendingClearTimeSeconds = elapsed
                        pendingRecordRank = rank
                        showRecordNameSheet = true
                    }
                }
            }
        }
        .overlay {
            if showCelebration {
                celebrationOverlay
            }
        }
        .sheet(isPresented: $showRecordNameSheet) {
            RecordNameSheet(
                clearTimeSeconds: pendingClearTimeSeconds,
                rank: pendingRecordRank,
                pieceCount: pieceCount,
                onSave: { showRecordNameSheet = false }
            )
        }
        .onAppear {
            AudioManager.shared.playBGMGame()
        }
        .onChange(of: soundEnabled) { _, enabled in
            if !enabled { AudioManager.shared.stopBGM() }
            else { AudioManager.shared.playBGMGame() }
        }
    }

    private func puzzleContent(geo: GeometryProxy) -> some View {
        let safe = geo.safeAreaInsets
        let fullW = geo.size.width
        let fullH = geo.size.height
        let trayH = pieceTrayHeight
        let imageSize = image.size
        let imageW = max(imageSize.width, 0.1)
        let imageH = max(imageSize.height, 0.1)
        let fillScale = max(fullW / imageW, fullH / imageH)
        let viewOffsetX = (fullW - imageW * fillScale) / 2
        let viewOffsetY = (fullH - imageH * fillScale) / 2
        let viewOffset = CGPoint(x: viewOffsetX, y: viewOffsetY)
        let boardH = max(0, fullH - safe.bottom - trayH)
        let layoutValid = fullW >= minBoardSize && boardH >= minBoardSize
        let boardAreaRect = CGRect(origin: .zero, size: CGSize(width: fullW, height: boardH))
        let trayTop = fullH - safe.bottom - trayH
        let trayBottom = fullH - safe.bottom

        return ZStack(alignment: .topLeading) {
            if layoutValid {
                Image(uiImage: displayImage ?? image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: fullW, height: fullH)
                    .clipped()
            } else {
                Color(.systemGroupedBackground).ignoresSafeArea()
            }

            if layoutValid {
                pieceTrayBackground(geo: geo, trayHeight: trayH)
            }

            if layoutValid {
                ZStack(alignment: .topLeading) {
                    boardSlotsOnly(in: boardAreaRect, glowingSlotIndex: lastPlacedSlotIndex)
                        .onAppear {
                            if !hasCompletedInitialLayout {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 150_000_000)
                                    if let ctx = lastLayoutContext {
                                        updateSlotsAndPieces(context: ctx, imageForPieces: displayImage ?? image, onGameStarted: { gameStartDate = Date() })
                                    }
                                    hasCompletedInitialLayout = true
                                }
                            } else {
                                updateSlotsAndPieces(in: boardAreaRect, geo: geo, trayHeight: trayH, imageForPieces: displayImage ?? image, viewOffset: viewOffset, fillScale: fillScale, onGameStarted: { gameStartDate = Date() })
                            }
                        }
                    ForEach(pieces.filter(\.isPlaced)) { piece in
                        if let slot = slots.first(where: { $0.index == piece.slotIndex }),
                           slot.frame.width > 0, slot.frame.height > 0 {
                            let isJustPlaced = lastPlacedPieceId == piece.id
                            pieceImage(piece)
                                .frame(width: slot.frame.width, height: slot.frame.height)
                                .clipShape(PuzzlePieceShape(kind: piece.shapeKind))
                                .scaleEffect(isJustPlaced ? 1.15 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: lastPlacedPieceId)
                                .position(x: slot.frame.midX, y: slot.frame.midY)
                        }
                    }
                }
                .frame(width: fullW, height: boardH)
                .clipped()
                .id(regenerateCount)

                ZStack(alignment: .topLeading) {
                    ForEach(pieces.filter { !$0.isPlaced }) { piece in
                        draggablePieceInTray(
                            piece, in: boardAreaRect,
                            boardTop: 0,
                            trayTop: trayTop, trayBottom: trayBottom,
                            trayPieceScale: trayPieceScale,
                            draggingPieceId: $draggingPieceId, dragOffset: $dragOffset,
                            shakingPieceId: $shakingPieceId,
                            placePiece: { id, slot in
                                placeEffectTrigger += 1
                                placePiece(id: id, at: slot)
                            },
                            returnPieceToTray: { id in returnPieceToTray(id: id, trayTop: trayTop, trayBottom: trayBottom) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if layoutValid, let start = gameStartDate, !allPlaced {
                VStack {
                    TimelineView(.periodic(from: start, by: 1.0)) { context in
                        Text(formatElapsed(context.date.timeIntervalSince(start)))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.black.opacity(0.5)))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .preference(key: TrayBoundsKey.self, value: layoutValid ? TrayBounds(top: trayTop, bottom: trayBottom) : nil)
        .preference(key: LayoutContextKey.self, value: layoutValid ? LayoutContext(rect: boardAreaRect, viewOffset: viewOffset, fillScale: fillScale, fullW: fullW, fullH: fullH, safeBottom: safe.bottom, trayHeight: trayH) : nil)
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func updateSlotsAndPieces(in rect: CGRect, geo: GeometryProxy, trayHeight: CGFloat, imageForPieces: UIImage, viewOffset: CGPoint, fillScale: CGFloat, onGameStarted: (() -> Void)? = nil) {
        applySlotsAndPieces(rect: rect, viewOffset: viewOffset, fillScale: fillScale, fullW: geo.size.width, fullH: geo.size.height, safeBottom: geo.safeAreaInsets.bottom, trayHeight: trayHeight, imageForPieces: imageForPieces, onGameStarted: onGameStarted)
    }

    private func applySlotsAndPieces(rect: CGRect, viewOffset: CGPoint, fillScale: CGFloat, fullW: CGFloat, fullH: CGFloat, safeBottom: CGFloat, trayHeight: CGFloat, imageForPieces: UIImage, onGameStarted: (() -> Void)? = nil) {
        guard rect.width >= minBoardSize, rect.height >= minBoardSize,
              rect.width.isFinite, rect.height.isFinite else { return }
        let expectedCount = pieceCount.rawValue
        let newSlots = PuzzleGenerator.makeSlots(pieceCount: pieceCount, in: rect, inset: slotInset)
        guard newSlots.count == expectedCount else { return }
        slots = newSlots
        guard newSlots.allSatisfy({ $0.frame.width > 0 && $0.frame.height > 0 }) else { return }
        pieceSize = newSlots[0].frame.size

        if pieces.isEmpty || pieces.count != expectedCount {
            if displayImage == nil {
                displayImage = PuzzleGenerator.normalizedImage(for: imageForPieces) ?? imageForPieces
            }
            let img = displayImage ?? imageForPieces
            let images = PuzzleGenerator.makePieceImages(from: img, slots: newSlots, viewOffset: viewOffset, fillScale: fillScale)
            guard images.count == expectedCount else { return }
            let margin: CGFloat = 20
            let totalPieceW = newSlots.reduce(0) { $0 + $1.frame.width }
            let maxPieceH = newSlots.map(\.frame.height).max() ?? 0
            let n = newSlots.count
            let trayMarginH: CGFloat = 24
            let trayMarginV: CGFloat = 24
            let usableTrayW = max(1, fullW - 2 * margin - trayMarginH)
            let usableTrayH = max(1, trayHeight - 2 * trayMarginV)
            let minSpacing: CGFloat = 8
            let scaleForWidth = (usableTrayW - CGFloat(max(0, n - 1)) * minSpacing) / max(totalPieceW, 0.1)
            let scaleForHeight = usableTrayH / max(maxPieceH, 0.1)
            let scale = min(1.0, scaleForWidth, scaleForHeight)
            trayPieceScale = scale
            let totalScaledW = totalPieceW * scale + CGFloat(max(0, n - 1)) * minSpacing
            let leftX = max(margin, min(fullW - margin - totalScaledW, fullW / 2 - totalScaledW / 2))
            let trayTop = fullH - safeBottom - trayHeight
            let pieceH = maxPieceH * scale
            let halfH = pieceH / 2
            let bufferFromTrayTop: CGFloat = 32
            let minCenterY = trayTop + halfH + max(trayMarginV, bufferFromTrayTop)
            let maxCenterY = trayTop + trayHeight - halfH - trayMarginV
            let trayCenterY = trayTop + trayHeight * 0.6
            let centerY = min(max(minCenterY, trayCenterY), maxCenterY)
            var positions: [CGPoint] = []
            var x = leftX
            for i in 0..<newSlots.count {
                let w = newSlots[i].frame.width * scale
                positions.append(CGPoint(x: x + w / 2, y: centerY))
                x += w + minSpacing
            }
            initialPiecePositions = positions
            let shapeKinds = newSlots.map(\.shapeKind)
            pieces = PuzzleGenerator.makePieces(pieceImages: images, initialPositions: positions, shapeKinds: shapeKinds)
            onGameStarted?()
        }
    }

    /// 初回用：Preference で確定したレイアウトを使って枠・ピース生成（ずれ防止）
    private func updateSlotsAndPieces(context ctx: LayoutContext, imageForPieces: UIImage, onGameStarted: (() -> Void)? = nil) {
        applySlotsAndPieces(rect: ctx.rect, viewOffset: ctx.viewOffset, fillScale: ctx.fillScale, fullW: ctx.fullW, fullH: ctx.fullH, safeBottom: ctx.safeBottom, trayHeight: ctx.trayHeight, imageForPieces: imageForPieces, onGameStarted: onGameStarted)
    }

    /// 下部のピース置き場の背景（グレー帯・画面最下部まで隙間なく）
    private func pieceTrayBackground(geo: GeometryProxy, trayHeight: CGFloat) -> some View {
        let safeBottom = geo.safeAreaInsets.bottom
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle()
                .fill(Color(.systemGray5).opacity(0.75))
                .frame(height: trayHeight + safeBottom)
                .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 同じ画像でピースを未配置の状態に戻す（もういちど）
    private func resetPuzzleForSameImage() {
        guard !initialPiecePositions.isEmpty, initialPiecePositions.count == pieces.count else { return }
        pieces = pieces.enumerated().map { _, p in
            PuzzlePiece(
                id: p.id,
                slotIndex: p.slotIndex,
                image: p.image,
                currentPosition: initialPiecePositions[p.id],
                isPlaced: false,
                shapeKind: p.shapeKind
            )
        }
    }

    /// スロットの枠だけを描画（背景画像は別レイヤーでフル表示）。正解直後は枠を光らせる
    private func boardSlotsOnly(in rect: CGRect, glowingSlotIndex: Int?) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(slots) { slot in
                if slot.frame.width > 0, slot.frame.height > 0 {
                    let localX = slot.frame.midX - rect.minX
                    let localY = slot.frame.midY - rect.minY
                    let shape = PuzzlePieceShape(kind: slot.shapeKind)
                    let isGlowing = glowingSlotIndex == slot.index
                    ZStack {
                        shape
                            .stroke(Color.primary.opacity(0.5), lineWidth: 4)
                            .background(shape.fill(Color.white))
                        if isGlowing {
                            shape
                                .stroke(Color.yellow, lineWidth: 6)
                                .opacity(0.9)
                                .blur(radius: 2)
                        }
                    }
                    .frame(width: slot.frame.width, height: slot.frame.height)
                    .position(x: localX, y: localY)
                }
            }
        }
        .frame(width: max(1, rect.width), height: max(1, rect.height))
    }

    private func pieceImage(_ piece: PuzzlePiece) -> some View {
        Image(uiImage: piece.image)
            .resizable()
            .scaledToFill()
    }

    @State private var draggingPieceId: Int?
    @State private var dragOffset: CGSize = .zero

    /// 未配置ピース（全画面座標で描画・ドラッグで上にも動かせる）
    private func draggablePieceInTray(
        _ piece: PuzzlePiece, in rect: CGRect,
        boardTop: CGFloat,
        trayTop: CGFloat, trayBottom: CGFloat, trayPieceScale: CGFloat,
        draggingPieceId: Binding<Int?>, dragOffset: Binding<CGSize>,
        shakingPieceId: Binding<Int?>,
        placePiece: @escaping (Int, PuzzleSlot) -> Void, returnPieceToTray: @escaping (Int) -> Void
    ) -> some View {
        let slot = slots.first(where: { $0.index == piece.slotIndex })
        let pw = max(1, slot?.frame.width ?? pieceSize.width)
        let ph = max(1, slot?.frame.height ?? pieceSize.height)
        let isDragging = draggingPieceId.wrappedValue == piece.id
        let dx = isDragging ? dragOffset.wrappedValue.width : 0
        let dy = isDragging ? dragOffset.wrappedValue.height : 0
        let trayH = trayBottom - trayTop
        let halfPieceH = (ph * trayPieceScale) / 2
        let trayMargin: CGFloat = 20
        let trayMinY = trayTop + halfPieceH + trayMargin
        let trayMaxY = trayBottom - halfPieceH - trayMargin
        let drawnY: CGFloat = isDragging
            ? piece.currentPosition.y + dy
            : min(max(piece.currentPosition.y, trayMinY), trayMaxY)
        let currentY = drawnY
        let isAboveTray = currentY < trayTop
        let displayScale: CGFloat = isAboveTray ? 1.0 : trayPieceScale
        return pieceImage(piece)
            .frame(width: pw * displayScale, height: ph * displayScale)
            .animation(.easeInOut(duration: 0.2), value: displayScale)
            .clipShape(PuzzlePieceShape(kind: piece.shapeKind))
            .shadow(color: .black.opacity(0.3), radius: isDragging ? 12 : 4, y: 4)
            .position(x: piece.currentPosition.x + dx, y: drawnY)
            .zIndex(isDragging ? 100 : 0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        draggingPieceId.wrappedValue = piece.id
                        dragOffset.wrappedValue = value.translation
                    }
                    .onEnded { value in
                        let endPos = CGPoint(
                            x: piece.currentPosition.x + value.translation.width,
                            y: piece.currentPosition.y + value.translation.height
                        )
                        // スロットはボード領域ローカルなので、画面座標に変換して比較
                        let hitSlot = slots.first { s in
                            let slotMidInFull = CGPoint(x: s.frame.midX, y: boardTop + s.frame.midY)
                            return abs(endPos.x - slotMidInFull.x) < snapThreshold &&
                                abs(endPos.y - slotMidInFull.y) < snapThreshold
                        }
                        if let hit = hitSlot, hit.index == piece.slotIndex {
                            AudioManager.shared.playSuccess()
                            placePiece(piece.id, hit)
                        } else {
                            AudioManager.shared.playWrong()
                            shakingPieceId.wrappedValue = piece.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                returnPieceToTray(piece.id)
                                shakingPieceId.wrappedValue = nil
                            }
                        }
                        dragOffset.wrappedValue = .zero
                        draggingPieceId.wrappedValue = nil
                    }
            )
            .modifier(WrongShakeEffect(isActive: shakingPieceId.wrappedValue == piece.id))
    }

    private func placePiece(id: Int, at slot: PuzzleSlot) {
        guard let idx = pieces.firstIndex(where: { $0.id == id }) else { return }
        var updated = pieces
        updated[idx].isPlaced = true
        updated[idx].currentPosition = CGPoint(x: slot.frame.midX, y: slot.frame.midY)
        pieces = updated
        lastPlacedPieceId = id
        lastPlacedSlotIndex = slot.index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            lastPlacedPieceId = nil
            lastPlacedSlotIndex = nil
        }
    }

    /// 正解の枠にハマらなかったとき、下部トレイの初期位置に戻す（Yはトレイ内にクランプ）
    private func returnPieceToTray(id: Int, trayTop: CGFloat, trayBottom: CGFloat) {
        guard let idx = pieces.firstIndex(where: { $0.id == id }),
              id < initialPiecePositions.count else { return }
        let piece = pieces[idx]
        let ph = slots.first(where: { $0.index == piece.slotIndex })?.frame.height ?? pieceSize.height
        let halfH = (ph * trayPieceScale) / 2
        let margin: CGFloat = 20
        let trayMinY = trayTop + halfH + margin
        let trayMaxY = trayBottom - halfH - margin
        let clampedY = min(max(initialPiecePositions[id].y, trayMinY), trayMaxY)
        var updated = pieces
        updated[idx].currentPosition = CGPoint(x: initialPiecePositions[id].x, y: clampedY)
        pieces = updated
    }

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            FireworksView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 24) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                Text("できたね！")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Button("もういちど") {
                    showCelebration = false
                    allPlaced = false
                    slots = []
                    pieces = []
                    gameStartDate = nil
                    regenerateCount += 1
                    AudioManager.shared.playBGMGame()
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(48)
            .background(RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial))
        }
    }
}

#Preview {
    if let img = UIImage(systemName: "photo") {
        PuzzleView(image: img, pieceCount: .six, onBackToStart: {})
    }
}
