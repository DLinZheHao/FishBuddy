//
//  GestureAnimationSubViews.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/6.
//

import Foundation
import SwiftUI


struct CardView: View, Identifiable {
    let id = UUID()
    let image: String
    let title: String
    
    @State var isVisible: Bool = true  
    
    var body: some View {
        Image(image)
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .cornerRadius(10)
            .overlay(alignment: .bottom) {
                VStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(.white)
                        .cornerRadius(5)
                }
                .padding(.bottom, 10)
            }
            .padding(15)
    }

}

struct TopBarMenu: View {
    var body: some View {
        HStack {
            Image(systemName: "line.horizontal.3")
                            .font(.system(size: 30))
            Spacer()
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 35))
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 30))
        }
        .padding()
    }
}

struct bottomBarMenu: View {
    var body: some View {
        HStack {
            Image(systemName: "xmark")
                .font(.system(size: 30))
                .foregroundStyle(.black)
            
            Button {
                // 執行動作
            } label: {
                Text("立即訂購")
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 35)
                    .padding(.vertical, 15)
                    .background(.black)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            
            Image(systemName: "heart")
                .font(.system(size: 30))
                .foregroundStyle(.black)
        }
    }
    
}

#Preview {
    CardView(image: "yosemite-usa", title: "Yosemite, USA")
}

#Preview("TopBarMenu") {
    TopBarMenu()
}

#Preview("bottomBarMenu") {
    bottomBarMenu()
}
