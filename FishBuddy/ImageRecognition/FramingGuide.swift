//
//  FramingGuide.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/19.
//

import SwiftUI

struct FramingGuide: View {
    enum Aspect { case wide43, square }
    var aspect: Aspect = .wide43

    // 互動狀態
    @State private var box: CGRect = .zero
    @State private var startBox: CGRect = .zero
    @State private var didInit = false

    // 參數
    var minSide: CGFloat = 120
    /// 當前裁切框（相對 0...1 座標，原點左上）變更時回呼；可用來同步到 CameraController
    var onRectChange: ((CGRect) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let S = min(W, H)

            // 初始大小（沿用你原本邏輯）
            let base = aspect == .wide43 ? 0.86 : 0.80
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

                // 角括號式框線（根據 box 大小繪製）
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
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(container: geo.size))
            .simultaneousGesture(magnifyGesture(container: geo.size))
            .onAppear {
                if !didInit {
                    let size = initialSize
                    let origin = CGPoint(x: (W - size.width)/2, y: (H - size.height)/2)
                    box = CGRect(origin: origin, size: size)
                    startBox = box
                    didInit = true
                    // 輸出一次初始 normalized rect
                    let norm = CGRect(x: origin.x / W, y: origin.y / H,
                                      width: size.width / W, height: size.height / H)
                    onRectChange?(norm)
                }
            }
            .onChange(of: box, initial: false) { _, new in
                let norm = CGRect(x: new.origin.x / W, y: new.origin.y / H,
                                  width: new.size.width / W, height: new.size.height / H)
                onRectChange?(norm)
            }
        }
        .compositingGroup()
    }

    // MARK: - 手勢
    private func dragGesture(container: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { val in
                var r = startBox
                r.origin.x += val.translation.width
                r.origin.y += val.translation.height
                box = clamp(r, in: container)
            }
            .onEnded { _ in
                startBox = box
            }
    }

    private func magnifyGesture(container: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let center = CGPoint(x: startBox.midX, y: startBox.midY)
                var newSize: CGSize
                switch aspect {
                case .square:
                    let side = max(minSide, startBox.width * scale)
                    newSize = .init(width: side, height: side)
                case .wide43:
                    let w = max(minSide, startBox.width * scale)
                    newSize = .init(width: w, height: w * 3 / 4)
                }
                var r = CGRect(origin: .zero, size: newSize)
                r.origin = CGPoint(x: center.x - newSize.width/2, y: center.y - newSize.height/2)
                box = clamp(r, in: container)
            }
            .onEnded { _ in
                startBox = box
            }
    }

    // MARK: - 工具
    private func clamp(_ r: CGRect, in container: CGSize) -> CGRect {
        var rr = r

        // 限制最大尺寸（不超出容器）
        let maxW = container.width * 0.98
        let maxH = container.height * 0.98
        if rr.width > maxW {
            rr.size.width = maxW
            rr.size.height = aspect == .wide43 ? maxW * 3/4 : maxW
        }
        if rr.height > maxH {
            rr.size.height = maxH
            rr.size.width = aspect == .wide43 ? maxH * 4/3 : maxH
        }

        // 位置夾限：保持框完整在容器內
        rr.origin.x = max(0, min(rr.origin.x, container.width - rr.width))
        rr.origin.y = max(0, min(rr.origin.y, container.height - rr.height))
        return rr
    }
}


struct CornerBracketShape: Shape {
    var lineLength: CGFloat = 40
    var cornerRadius: CGFloat = 12

    func path(in r: CGRect) -> Path {
        var p = Path()

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

// 使用方式
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
#Preview {
    FramingGuide()
}
