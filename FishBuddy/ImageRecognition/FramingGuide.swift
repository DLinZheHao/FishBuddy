//
//  FramingGuide.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/19.
//

import SwiftUI

/**
 FramingGuide
 --------------
 目的：提供一個可拖曳與縮放的「取景框 / 裁切框」UI，支援 4:3 與 1:1 兩種比例。
 
 互動：
 - 拖曳（DragGesture）：移動框的位置。
 - 縮放（MagnificationGesture）：依比例縮放框的大小（維持 4:3 或 1:1）。
 
 尺度計算：
 - 初始大小會依容器短邊（min(W, H)）與比例預設 base（0.86 / 0.80）計算。
 - 4:3 會再乘上 4/3（約 1.33）推回寬度，並限制不超過容器寬的 90%。
 
 同步：
 - onRectChange 會回傳以 0...1 正規化的 CGRect（相對容器座標），方便同步到 CameraController。
 
 限制：
 - clamp(_:in:) 會把框限制在容器中，並保證最大尺寸不會超過容器的 98%。
*/

struct FramingGuide: View {
    enum Aspect {
        /// 4:3 寬螢幕
        case wide43
        /// 1:1 正方形
        case square
    }
    
    /// 決定框的寬高比：
    /// - .wide43：維持 4:3
    /// - .square：維持 1:1
    /// 當前瞄準框的比例設定
    var aspect: Aspect = .wide43

    // 互動狀態
    /// 目前框的即時位置與大小
    @State private var box: CGRect = .zero
    /// 手勢開始時的「初始框」
    @State private var startBox: CGRect = .zero
    /// 標記是否已完成初始設定
    @State private var didInit = false

    // 參數
    var minSide: CGFloat = 120
    /// 當前裁切框（相對 0...1 座標，原點左上）變更時回呼；可用來同步到 CameraController
    var onRectChange: ((CGRect) -> Void)? = nil
    /// 點擊框時回傳中心點（0...1 正規化；原點左上、相對容器）
    var onCenterTap: ((CGPoint, CGRect) -> Void)? = nil

    // Crosshair 動畫狀態
    @State private var crossVisible = false
    @State private var crossScale: CGFloat = 1.0
    @State private var crossOpacity: CGFloat = 0.0

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width   // 容器寬度（points）
            let H = geo.size.height  // 容器高度（points）
            let S = min(W, H)        // 取較短邊作為縮放基準，避免初始尺寸超出容器

            // 不同比例的初始視覺佔比（相對短邊的比例），讓兩種模式看起來大小接近
            let base = aspect == .wide43 ? 0.86 : 0.80
            // 依照比例（4:3 / 1:1）計算「初始框大小」。
            // - wide43：width = min(base * S * 4/3, 0.9 * W), height = width * 3/4
            // - square：side = base * S
            let initialSize: CGSize = {
                switch aspect {
                case .wide43:
                    let targetW = min(base * S * 1.33, 0.9 * W)
                    return .init(width: targetW, height: targetW * 3/4)
                case .square:
                    let side = base * S
                    return .init(width: side, height: side)
                }
            }()

            ZStack {
                // 暗化背景
                Color.black.opacity(0.35).ignoresSafeArea()

                // 以「角括號」樣式描出取景框邊界（非實心矩形，減少對畫面內容的遮擋）
                CornerBracketShape(
                    lineLength: 0.12 * min(box.width == 0 ? initialSize.width : box.width,
                                            box.height == 0 ? initialSize.height : box.height),
                    cornerRadius: 10
                )
                .stroke(.white, lineWidth: 6)
                .frame(width: box.width == 0 ? initialSize.width : box.width,
                       height: box.height == 0 ? initialSize.height : box.height)
                .position(x: box.midX == 0 ? W/2 : box.midX,
                          y: box.midY == 0 ? H/2 : box.midY)
                
                // 中心十字準星（點擊時出現，縮小後淡出）
                if crossVisible {
                    CrosshairShape()
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(
                            width: (box.width == 0 ? initialSize.width : box.width) * 0.35,
                            height: (box.height == 0 ? initialSize.height : box.height) * 0.35
                        )
                        .scaleEffect(crossScale)
                        .opacity(crossOpacity)
                        .position(x: box.midX == 0 ? W/2 : box.midX,
                                  y: box.midY == 0 ? H/2 : box.midY)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(container: geo.size))                // 單指拖動：移動框位置
            .simultaneousGesture(magnifyGesture(container: geo.size)) // 雙指縮放：等比縮放框尺寸
            .simultaneousGesture(tapGesture(container: geo.size))
            .onAppear {
                if !didInit {
                    let size = initialSize // 計算出的初始尺寸
                    let origin = CGPoint(x: (W - size.width)/2, y: (H - size.height)/2) // 置中放置
                    box = CGRect(origin: origin, size: size)   // 設定目前框
                    startBox = box                             // 記錄手勢起點框（供拖曳/縮放參考）
                    didInit = true
                    // 輸出一次正規化座標（相對 0...1 的矩形）供外部同步
                    let norm = CGRect(x: origin.x / W, y: origin.y / H,
                                      width: size.width / W, height: size.height / H)
                    onRectChange?(norm)
                }
            }
            .onChange(of: box, initial: false) { _, new in
                // 每次框變動即回傳正規化矩形（位置/大小）
                let norm = CGRect(x: new.origin.x / W, y: new.origin.y / H,
                                  width: new.size.width / W, height: new.size.height / H)
                onRectChange?(norm)
            }
        }
        .compositingGroup()
    }

    // MARK: - 手勢
    
    /// 點擊手勢：回傳目前框的中心點（0...1 正規化）
    private func tapGesture(container: CGSize) -> some Gesture {
        TapGesture(count: 1).onEnded {
            // 目前框中心（若尚未初始化則取容器中心）
            let cx = (box.midX == 0 ? container.width  / 2 : box.midX)
            let cy = (box.midY == 0 ? container.height / 2 : box.midY)
            let pointInView = CGPoint(x: cx, y: cy)
            // box 是你現在畫白框用的那個 CGRect（在 container 座標系裡）
            let normRect = CGRect(
                x: box.minX / container.width,
                y: box.minY / container.height,
                width: box.width / container.width,
                height: box.height / container.height
            )
            onCenterTap?(pointInView, normRect)

            // 觸發十字準星縮小 + 淡出動畫
            crossVisible = true
            crossScale = 1.2
            crossOpacity = 1.0
            withAnimation(.easeOut(duration: 0.28)) {
                crossScale = 0.45
            }
            withAnimation(.easeOut(duration: 0.20).delay(0.28)) {
                crossOpacity = 0.0
            }
            // 動畫結束後關閉可見狀態（避免殘留 hitTest）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                crossVisible = false
            }
        }
    }
    
    /// 拖曳手勢：以手勢開始時的 `startBox` 為基準，
    /// 持續加上 translation 並以 `clamp` 夾限於容器內。
    private func dragGesture(container: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { val in
                var r = startBox // 以起點框為基礎
                r.origin.x += val.translation.width // 加上水平位移
                r.origin.y += val.translation.height // 加上垂直位移
                box = clamp(r, in: container) // 夾限在容器範圍內
            }
            .onEnded { _ in
                startBox = box // 更新為新的起點框
            }
    }

    /// 縮放手勢：以 `startBox` 的中心為錨點，
    /// 依比例維持 4:3 或 1:1 進行等比縮放，並以 `clamp` 夾限。
    private func magnifyGesture(container: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let center = CGPoint(x: startBox.midX, y: startBox.midY) // 以起點框中心為縮放錨點
                var newSize: CGSize
                switch aspect {
                case .square:
                    let side = max(minSide, startBox.width * scale) // 維持正方形，限制最小邊長
                    newSize = .init(width: side, height: side)
                case .wide43:
                    let w = max(minSide, startBox.width * scale)    // 以寬為基礎並維持 4:3
                    newSize = .init(width: w, height: w * 3 / 4)
                }
                var r = CGRect(origin: .zero, size: newSize) // 先建立新尺寸的框
                r.origin = CGPoint(x: center.x - newSize.width/2, y: center.y - newSize.height/2) // 以中心回推新原點
                box = clamp(r, in: container) // 夾限於容器
            }
            .onEnded { _ in
                startBox = box // 更新為新的起點框
            }
    }
    
    // MARK: - 工具
    /// 把矩形 `r` 夾限在 `container` 尺寸內，
    /// 並限制最大寬高不超過容器的 98%（同時維持比例一致）。
    private func clamp(_ r: CGRect, in container: CGSize) -> CGRect {
        var rr = r // 可變拷貝

        // 限制最大尺寸（避免超出容器，並留下一點邊界視覺呼吸）
        let maxW = container.width * 0.98
        let maxH = container.height * 0.98
        if rr.width > maxW {
            rr.size.width = maxW                               // 夾限寬度
            rr.size.height = aspect == .wide43 ? maxW * 3/4 : maxW // 維持比例
        }
        if rr.height > maxH {
            rr.size.height = maxH                              // 夾限高度
            rr.size.width  = aspect == .wide43 ? maxH * 4/3 : maxH // 維持比例
        }

        // 位置夾限：確保整個框完整位於容器內
        rr.origin.x = max(0, min(rr.origin.x, container.width - rr.width))
        rr.origin.y = max(0, min(rr.origin.y, container.height - rr.height))
        return rr
    }
}

/// 角括號樣式的框線形狀。
/// 只繪製四角的短邊與圓角連接，避免遮擋內容，同時帶出相機取景器的視覺語彙。
struct CornerBracketShape: Shape {
    var lineLength: CGFloat = 40
    var cornerRadius: CGFloat = 12

    func path(in r: CGRect) -> Path {
        var p = Path()

        // 參數別名：易讀（L = 邊長, R = 角半徑）
        let L = lineLength
        let R = cornerRadius

        // 把矩形四個角座標先取出（便於閱讀）
        let tl = CGPoint(x: r.minX, y: r.minY) // top-left (0,0)
        let tr = CGPoint(x: r.maxX, y: r.minY) // top-right (300,0)
        let br = CGPoint(x: r.maxX, y: r.maxY) // bottom-right (300,300)
        let bl = CGPoint(x: r.minX, y: r.maxY) // bottom-left (0,300)

        // ── 左上角 ─────────────────────────────
        p.move(to: CGPoint(x: tl.x, y: tl.y + L))           // A (0,40)
        p.addLine(to: CGPoint(x: tl.x, y: tl.y + R))        // B (0,12)
        p.addQuadCurve(to: CGPoint(x: tl.x + R, y: tl.y),   // C (12,0)
                       control: CGPoint(x: tl.x, y: tl.y))  // P (0,0)
        p.addLine(to: CGPoint(x: tl.x + L, y: tl.y))        // D (40,0)

        // ── 右上角 ─────────────────────────────
        p.move(to: CGPoint(x: tr.x, y: tr.y + L))           // (300,40)
        p.addLine(to: CGPoint(x: tr.x, y: tr.y + R))        // (300,12)
        p.addQuadCurve(to: CGPoint(x: tr.x - R, y: tr.y),   // (288,0)
                       control: CGPoint(x: tr.x, y: tr.y))  // (300,0)
        p.addLine(to: CGPoint(x: tr.x - L, y: tr.y))        // (260,0)

        // ── 右下角 ─────────────────────────────
        p.move(to: CGPoint(x: br.x, y: br.y - L))           // (300,260)
        p.addLine(to: CGPoint(x: br.x, y: br.y - R))        // (300,288)
        p.addQuadCurve(to: CGPoint(x: br.x - R, y: br.y),   // (288,300)
                       control: CGPoint(x: br.x, y: br.y))  // (300,300)
        p.addLine(to: CGPoint(x: br.x - L, y: br.y))        // (260,300)

        // ── 左下角 ─────────────────────────────
        p.move(to: CGPoint(x: bl.x + L, y: bl.y))           // (40,300)
        p.addLine(to: CGPoint(x: bl.x + R, y: bl.y))        // (12,300)
        p.addQuadCurve(to: CGPoint(x: bl.x, y: bl.y - R),   // (0,288)
                       control: CGPoint(x: bl.x, y: bl.y))  // (0,300)
        p.addLine(to: CGPoint(x: bl.x, y: bl.y - L))        // (0,260)

        return p
    }
}

/// 中心十字準星（等臂十字）
struct CrosshairShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        // 垂直線
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        // 水平線
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

// 展示 CornerBracketShape 的簡易示範用法
struct DemoView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CornerBracketShape(lineLength: 40, cornerRadius: 12)
                .stroke(.white, lineWidth: 6)
                .frame(width: 300, height: 300)
        }
    }
}

//// 預覽：顯示 FramingGuide 元件，並示範接收中心點回呼
//#Preview {
//    FramingGuide(onCenterTap: { pt in
//        print("Center (normalized):", pt)
//    })
//}
