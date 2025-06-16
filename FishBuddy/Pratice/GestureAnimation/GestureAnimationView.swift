//
//  GestureAnimationView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/6.
//

import SwiftUI

struct GestureAnimationView: View {
    
    var cardViews: [CardView] = {
        var views = [CardView]()
        for index in 0..<2 {
            views.append(CardView(image: trips[index].image, title: trips[index].destination)) }
        return views
    }()
    
    var body: some View {
        VStack {
            TopBarMenu()
            
            ZStack {
                ForEach(cardViews) { cardView in
                    cardView
                        .zIndex(isTopCard(cardView: cardView) ? 1 : 0)
                }
            }
            
            Spacer(minLength: 20)
            bottomBarMenu()
        }
        
    }
    
    private func isTopCard(cardView: CardView) -> Bool {
        guard let index = cardViews.firstIndex(where: { $0.id == cardView.id })
        else { return false }
        return index == 0
    }
}

#Preview {
    GestureAnimationView()
}
