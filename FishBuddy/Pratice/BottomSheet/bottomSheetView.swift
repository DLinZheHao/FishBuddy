//
//  bottomSheetView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/6/6.
//

import SwiftUI

struct bottomSheetView: View {
    
    @State private var showSheet = false
    
    @State private var selectedRestaurant: Restaurant?
    
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(restaurants) { restaurant in
                    BasicImageRow(restaurant: restaurant)
                        .onTapGesture {
                            selectedRestaurant = restaurant
                        }
                }
            }
            .listStyle(.plain)
            
            .navigationTitle("Restaurants")
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantDetailView(restaurant: restaurant)
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }
}

#Preview {
    bottomSheetView()
}

// 通過 presentationDetents （內建修飾器）調整 bottomSheet 大小
// .medium .large .height .fraction

/*
 var body: some View {
     VStack {
         Button("Show Bottom Sheet") {
             showSheet.toggle()
         }
         .buttonStyle(.borderedProminent)
         .sheet(isPresented: $showSheet) {
             Text(" This is the bottom sheet content")
                 .presentationDetents([.medium, .large]) // 調整 bottomSheet 大小
         }
         
         Spacer()
     }
 }
 */
