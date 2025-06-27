//
//  CardSliderView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/17.
//

import SwiftUI

struct CardSliderView: View {
    /// 所有卡片
    @State var cards: [Card] = testCards
    /// 每張卡片的偏移量
    private static let cardOffset: CGFloat = 50.0
    /// 卡片是否已經呈現
    @State private var isCardPresented = false
    /// 卡片是否被點擊
    @State var isCardPressed = false
    ///  選擇的卡片
    @State var selectdCard: Card?
    /// 手勢狀態 -> 初始無狀態
    @GestureState private var dragState = CardDragState.inactive
    
    @State private var draggingNewIndex: Int? = nil
    
    var body: some View {
        VStack {
            
            TopNavBar()
                .padding(.bottom)
            
            Spacer()
            
            ZStack {
                ForEach(cards) { card in
                    CardItemView(card: card)
                        .offset(offset(for: card))
                        .padding(.horizontal, 35)
                        .zIndex(zIndex(for: card))
                        // .id(...) 會 強制 SwiftUI 認為這個 View 是一個新的實例，只要裡面的值改變，就會重新建立並渲染這個 View。
                        .id(isCardPresented)
                        // 因為 .transition(...) 只在 view 的 “生命週期變化” 時觸發
                        // 所以我們需要在卡片呈現時觸發 transition
                        .transition(AnyTransition.slide.combined(with: .move(edge: .leading))
                            .combined(with: .opacity))
                        .animation(transitionAnimation(for: card), value: isCardPresented)
                        .gesture(
                            TapGesture()
                                .onEnded({ _ in
                                    withAnimation(.easeOut(duration: 0.15).delay(0.1)) {
                                        isCardPressed.toggle()
                                        selectdCard = isCardPressed ? card : nil
                                    }
                                })
                                .exclusively(before: LongPressGesture(minimumDuration: 0.05)
                                    .sequenced(before: DragGesture())
                                    .updating(self.$dragState, body: { (value, state, transaction) in
                                        switch value {
                                        case .first(true):
                                            state = .pressing(index: self.index(for: card))
                                        case .second(true, let drag):
                                            state = .dragging(index: self.index(for: card), translation: drag?.translation ?? .zero)
                                        default:
                                            break
                                        }
                                    })
                                    .onChanged { value in
                                        guard case .second(true, let drag?) = value,
                                              let draggingIndex = self.index(for: card) else { return }
                                        var newIndex = draggingIndex + Int(-drag.translation.height / Self.cardOffset)
                                        newIndex = min(max(newIndex, 0), cards.count - 1)
                                        withAnimation(.spring()) {
                                            draggingNewIndex = newIndex
                                        }
                                    }
                                    .onEnded({ (value) in
                                        guard case .second(_, let drag?) = value else { return }
                                        withAnimation(.spring()) {
                                            rearrangeCards(with: card, dragOffset: drag.translation)
                                            draggingNewIndex = nil
                                        }
                                    })
                            )
                        )
                }
            }
            .animation(.spring(), value: draggingNewIndex)
            .onAppear() {
                isCardPresented.toggle()
            }
            
            if isCardPressed {
                TransactionHistoryView(transactions: testTransactions)
                    .padding(.top, 10)
                    .transition(.move(edge: .bottom))
            }
            
            Spacer()
        }
        
    }
    
    /// 重新排序卡片序列
    private func rearrangeCards(with card: Card, dragOffset: CGSize) {
        guard let draggingCardIndex = index(for: card) else { return }
        
        var newIndex = draggingCardIndex + Int(-dragOffset.height / Self.cardOffset)
        newIndex = newIndex >= cards.count ? cards.count - 1 : newIndex
        newIndex = newIndex < 0 ? 0 : newIndex
        
        let removedCard = cards.remove(at: draggingCardIndex)
        cards.insert(removedCard, at: newIndex)
    }
    
    
    /// 卡片轉場動畫
    private func transitionAnimation(for card: Card) -> Animation {
        var delay = 0.0
        
        if let index = index(for: card) {
            delay = Double(cards.count - index) * 0.1
        }
        
        return Animation.spring(response: 0.1, dampingFraction: 0.8, blendDuration: 0.02).delay(delay)
    }
    
    /// 設定卡片偏移量
    private func offset(for card: Card) -> CGSize {
        guard let cardIndex = index(for: card) else { return .zero }
        
        if isCardPressed {
            guard let selectdCard = self.selectdCard,
                  let selectedIndex = index(for: selectdCard) else {
                return .zero
            }
            
            if cardIndex >= selectedIndex {
                return .zero
            }
            
            return CGSize(width: 0, height: 1400)
        }
        
        var pressedOffset = CGSize.zero
        var dragOffsetY: CGFloat = 0.0
        
        if let draggingIndex = dragState.index,
           let newIndex = draggingNewIndex {
            
            if cardIndex == draggingIndex {
                pressedOffset.height = dragState.isPressing ? -20 : 0
                
                switch dragState.translation.width {
                case let width where width < -10: pressedOffset.width = -20
                case let width where width > 10: pressedOffset.width = 20
                default: break
                }
                dragOffsetY = dragState.translation.height
                
                return CGSize(width: pressedOffset.width,
                              height: dragOffsetY - CardSliderView.cardOffset * CGFloat(cardIndex) + pressedOffset.height)
            } else if draggingIndex < newIndex && cardIndex > draggingIndex && cardIndex <= newIndex {
                // 拖曳卡片往下移時，中間卡片往上移一格
                return CGSize(width: 0, height: -CardSliderView.cardOffset * CGFloat(cardIndex) + CardSliderView.cardOffset)
            } else if draggingIndex > newIndex && cardIndex >= newIndex && cardIndex < draggingIndex {
                // 拖曳卡片往上移時，中間卡片往下移一格
                return CGSize(width: 0, height: -CardSliderView.cardOffset * CGFloat(cardIndex) - CardSliderView.cardOffset)
            }
        }
        
        return CGSize(width: 0, height: -CardSliderView.cardOffset * CGFloat(cardIndex))
    }
    
    /// 獲取卡片的 ZIndex 值 -> 按照順序
    private func zIndex(for card: Card) -> Double {
        // 最前面一張為 0
        guard let cardIndex = index(for: card) else {
            return 0.0
        }
        
        let defaultZIndex = -Double(cardIndex)
        // 如果是拖曳狀態的卡片
        if let draggingIndex = dragState.index,
           cardIndex == draggingIndex {
            // 根據位移的高度來計算新的 z-index：每張卡的位移會是 index * cardOffset， 所以位移的高度 / cardOffset 可以得到是否要前往下一個 index
            return defaultZIndex + Double(dragState.translation.height / Self.cardOffset)
        }
        
        // 回傳預設的 z-index
        return defaultZIndex
    }

    /// 獲取卡片的辨識碼
    private func index(for card: Card) -> Int? {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            return nil
        }
        return index
    }

}

#Preview {
    CardSliderView()
}
