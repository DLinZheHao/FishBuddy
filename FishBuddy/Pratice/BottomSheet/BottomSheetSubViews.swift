//
//  BottomSheetSubViews.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/6.
//

import Foundation
import SwiftUI

struct BasicImageRow: View {
    var restaurant: Restaurant
    
    var body: some View {
        HStack {
            Image(restaurant.image)
                .resizable()
                .frame(width: 40, height: 40)
                .cornerRadius(5)
            Text(restaurant.name)
        }
    }
}

/// 橫列
struct HandleBar: View {
    
    var body: some View {
        Rectangle()
            .frame(width: 50, height: 5)
            .foregroundStyle(Color(.systemGray5))
            .cornerRadius(10)
    }
}

/// 標題列
struct TitleBar: View {
    
    var body: some View {
        HStack {
            Text("Restaurant Detail")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding()
    }
}

/// 標題容器
struct HeaderView: View {
    let restaurant: Restaurant
    
    var body: some View {
        Image(restaurant.image)
            .resizable()
            .scaledToFit()
            .frame(height: 300)
            .clipped()
            .overlay(
                HStack {
                    VStack(alignment: .leading) {
                        Spacer()
                        Text(restaurant.name)
                            .foregroundStyle(.white)
                            .font(.system(.largeTitle, design: .rounded))
//                            .bold()
                        
                        Text(restaurant.type)
                            .font(.system(.headline, design: .rounded))
                            .padding(5)
                            .foregroundStyle(.white)
                            .background(Color.red)
                            .cornerRadius(5)
                        
                    }
                    Spacer()
                }
                    .padding(20)
            )
    }
}

/// 細節資訊視圖
struct DetailInfoView: View {
    let icon: String?
    let info: String
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .padding(.trailing, 10)
            }
            Text(info)
                .font(.system(.body, design: .rounded))
                
            Spacer()
        }
        .padding(.horizontal)
    }
}

/// 組合整個元件視圖
struct RestaurantDetailView: View {
    let restaurant: Restaurant
    
    var body: some View {
        VStack {
            Spacer()
            
            HandleBar()
            
            ScrollView(.vertical) {
                TitleBar()
                
                HeaderView(restaurant: restaurant)
                
                DetailInfoView(icon: "map", info: restaurant.location)
                    .padding(.top)
                DetailInfoView(icon: "phone", info: restaurant.phone)
                DetailInfoView(icon: nil, info: restaurant.description)
                    .padding(.top)
            }
        }
        .background(.white)
        .cornerRadius(10 ,antialiased: true)
    }
}



#Preview {
    RestaurantDetailView(restaurant: restaurants[0])
}
