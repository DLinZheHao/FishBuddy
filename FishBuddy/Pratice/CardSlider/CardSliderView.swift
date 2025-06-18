//
//  CardSliderView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/17.
//

import SwiftUI

struct CardSliderView: View {
    /// 所有卡片
    var cards: [Card] = testCards
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
                                // 這是一種讓 點擊與拖動不衝突 的處理方式。若不這樣寫，可能會導致手勢失敗或誤觸。
                                .exclusively(before: DragGesture(minimumDistance: 0.05))
                                // 辨識手勢順序用
                                .sequenced(before: DragGesture())
                                .updating(self.$dragState, body: { (value, state, transaction) in
                                    switch value {
                                    case .first(_):
                                        state = .pressing(index: self.index(for: card))
                                    case .second(_, let drag):
                                        state = .dragging(index: self.index(for: card),
                                                          translation: drag?.translation ?? .zero)
                                    }
                                })
                                .onEnded({ (value) in
                                    guard case .second(_, let drag) = value else { return }
                                    // 重新排列卡片
                                })
                                    
                        )
                }
            }
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
        guard let cardIndex = index(for: card) else {
            return CGSize.zero
        }
        
        // 點擊卡片時，將選擇的卡片往上移動
        if isCardPressed {
            guard let selectdCard = self.selectdCard,
                  let selectedIndex = index(for: selectdCard) else {
                return CGSize.zero
            }
            
            // index 比目前選擇卡片還大的，就疊在選擇卡片底下
            if cardIndex >= selectedIndex {
                return .zero
            }
            
            // index 比目前選擇卡片小的，就往下移出畫面
            let offset = CGSize(width: 0, height: 1400)
            return offset
        }
        
        // 處理拖曳手勢的情況
        var pressedOffset = CGSize.zero
        var dragOffsetY: CGFloat = 0.0
        
        if let draggingIndex = dragState.index,
           cardIndex == draggingIndex {
            pressedOffset.height = dragState.isPressing ? -20 : 0
            
            switch dragState.translation.width {
            case let width where width < -10: pressedOffset.width = -20
            case let width where width > 10: pressedOffset.width = 20
            default: break
            }
            
            dragOffsetY = dragState.translation.height
        }
        
        return CGSize(width: 0 + pressedOffset.width,
                      height: -CardSliderView.cardOffset * CGFloat(cardIndex) + pressedOffset.height + dragOffsetY)
    }
    
    /// 獲取卡片的 ZIndex 值 -> 按照順序
    private func zIndex(for card: Card) -> Double {
        guard let cardIndex = index(for: card) else {
            return 0.0
        }
        return -Double(cardIndex)
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
