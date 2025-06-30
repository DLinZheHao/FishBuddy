//
//  GestureAnimationView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/6.
//

import SwiftUI

struct GestureAnimationView: View {
    
    /// 當前拖曳狀態
    @GestureState private var dragState = DragState.inactive
    /// 拖曳的界線值
    private let dragThreshold: CGFloat = 80.0
    
    /// 介面顯示用卡片資料
    @State var cardViews: [CardView] = {
        var views = [CardView]()
        for index in 0..<2 {
            views.append(CardView(image: trips[index].image, title: trips[index].destination)) }
        return views
    }()
    
    /// 使用的最後一張卡片索引 -> 初始值為第二張
    @State private var lastIndex = 1
    
    /// 移除轉場
    @State private var removalTransition = AnyTransition.trailingBottom
    
    var body: some View {
        VStack {
            // 頂部菜單
            TopBarMenu()
            
            // 景點卡片
            ZStack {
                ForEach(cardViews) { cardView in
                    cardView
                        .zIndex(isTopCard(cardView: cardView) ? 1 : 0)
                        .overlay {
                            ZStack {
                                // 往左滑
                                Image(systemName: "x.circle")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 100))
                                    .opacity(dragState.translation.width < -dragThreshold && isTopCard(cardView: cardView) ? 1.0 : 0.0)
                                // 往右滑
                                Image(systemName: "heart.circle")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 100))
                                    .opacity(dragState.translation.width > dragThreshold && isTopCard(cardView: cardView) ? 1.0 : 0.0)
                            }
                        }
                        // 卡片位移
                        .offset(x: isTopCard(cardView: cardView) ? dragState.translation.width : 0,
                                y: isTopCard(cardView: cardView) ? dragState.translation.height : 0)
                        // 放大、縮小效果
                        .scaleEffect(dragState.isDragging && isTopCard(cardView: cardView) ? 0.95 : 1.0)
                        // 把數值縮小，讓旋轉角度不要太誇張（例如拖 100 點時只轉 10 度），讓動畫比較自然
                        .rotationEffect(Angle(degrees: isTopCard(cardView: cardView) ? Double(dragState.translation.width / 10) : 0))
                        // 彈簧動畫 stiffness 控制彈性，damping 控制阻尼 -> 讓卡片可以回彈
                        .animation(.interpolatingSpring(stiffness: 180, damping: 100),
                                   value: dragState.isDragging)
                        .transition(removalTransition) // 移除卡片的轉場效果
                        .gesture(LongPressGesture(minimumDuration: 0.01)   // 第一階段：先完成長按（LongPressGesture）
                            .sequenced(before: DragGesture()) // 第二階段：才能開始拖曳（DragGesture）
                            .updating($dragState, body: { (value, state, transaction) in // 分辨階段
                                switch value {
                                case .first(true):
                                    state = .pressing
                                case .second(true, let drag):
                                    state = .dragging(translation: drag?.translation ?? .zero)
                                default:
                                    break
                                }
                            })
                            .onChanged({ value in
                                guard case .second(true, let drag?) = value else { return }
                                
                                if drag.translation.width < -dragThreshold {
                                    removalTransition = .leadingBottom // 往左滑時的移除轉場
                                }
                                
                                if drag.translation.width > dragThreshold {
                                    removalTransition = .trailingBottom // 往右滑時的移除轉場
                                }
                            })
                            .onEnded { value in // 手勢結束時的處理
                                guard case .second(true, let drag?) = value else { return }

                                if abs(drag.translation.width) > dragThreshold {
                                    withAnimation {
                                        removalTransition = drag.translation.width > 0 ? .trailingBottom : .leadingBottom
                                    }

                                    DispatchQueue.main.async { // 這樣才有動畫效果
                                        withAnimation {
                                            moveCard()
                                        }
                                    }
                                }
                            }
                        )
                        
                }
            }
            
            Spacer(minLength: 20)
            
            // 底部菜單
            bottomBarMenu()
                .opacity(dragState.isPressing ? 0.0 : 1.0)
                .animation(.default, value: dragState.isDragging)
        }
        
    }
    
    /// 是否是最上層的卡片
    private func isTopCard(cardView: CardView) -> Bool {
        guard let index = cardViews.firstIndex(where: { $0.id == cardView.id })
        else { return false }
        return index == 0
    }
    
    /// 刪除及插入卡片 view
    private func moveCard() {
        cardViews.removeFirst()
        
        lastIndex += 1
        let trip = trips[lastIndex % trips.count]
        let newCardView = CardView(image: trip.image, title: trip.destination)
        
        cardViews.append(newCardView)
    }
    
}

#Preview {
    GestureAnimationView()
}

extension AnyTransition {
    static var trailingBottom: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .identity, // .identity：表示「插入新視圖」時不套用任何動畫（靜止出現）。
            removal: AnyTransition.move(edge: .trailing).combined(with: .move(edge: .bottom))
            /* removal: 部分則是：
            •    .move(edge: .trailing)：視圖會從右邊往外移出。
            •    .move(edge: .bottom)：視圖也會同時向下移出。
            •    這兩個 .move() 被 .combined 合併起來，形成一個「往右下角移出的效果」。
             */
        )
    }
    // 同上，只是左下移出
    static var leadingBottom: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .identity,
            removal: AnyTransition.move(edge: .leading).combined(with: .move(edge: .bottom))
        )
    }
}
