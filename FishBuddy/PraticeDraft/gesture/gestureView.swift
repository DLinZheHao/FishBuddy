//
//  gestureView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/5/19.
//

import SwiftUI

struct gestureView: View {
    
    @State private var isPressed = false
    
    /// 手勢結束會自動回歸初始值
    @GestureState private var longPressTap = false
    
    var body: some View {
        Image(systemName: "star.circle.fill")
            .font(.system(size: 200))
            .opacity(longPressTap ? 0.4 : 1.0)
            .scaleEffect(isPressed ? 0.5 : 1.0)
            .animation(.easeInOut, value: isPressed)
            .foregroundStyle(.green)
            .gesture(
                LongPressGesture(minimumDuration: 1.0)
                    .updating($longPressTap, body: { (curState, state, transaction) in
                        print(curState)
                        state = curState
                        
                    })
                    .onEnded({ _ in
                        self.isPressed.toggle()
                    })
            )
    }
    
}

#Preview {
    gestureView()
}


/* 簡單點擊 TapGesture() 範例
 struct gestureView: View {
     var body: some View {
         Image(systemName: "star.circle.fill")
             .font(.system(size: 200))
             .foregroundStyle(.green)
             .gesture(
                 TapGesture()
                     .onEnded({
                         print("Tapped!")
                     })
             )
     }
 }
 */


/* 點擊 TapGesture 動畫範例
 struct gestureView: View {
     
     @State private var isPressed = false
     
     var body: some View {
         Image(systemName: "star.circle.fill")
             .font(.system(size: 200))
             .scaleEffect(isPressed ? 0.5 : 1.0)
             .animation(.easeOut, value: isPressed)
             .foregroundStyle(.green)
             .onTapGesture {
                 withAnimation {
                     isPressed = true
                 }
                 
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                     withAnimation {
                         isPressed = false
                     }
                 }
             }
 //            .gesture(
 //                TapGesture()
 //                    .onEnded({
 //                        print("Tapped!")
 //                        self.isPressed.toggle()
 //                    })
 //            )
     }
 }
 */

 
/* 長點擊同時有點擊的效果
 struct gestureView: View {
     
     @State private var isPressed = false
     
     /// 手勢結束會自動回歸初始值
     @GestureState private var longPressTap = false
     
     var body: some View {
         Image(systemName: "star.circle.fill")
             .font(.system(size: 200))
             .opacity(longPressTap ? 0.4 : 1.0)
             .scaleEffect(isPressed ? 0.5 : 1.0)
             .animation(.easeInOut, value: isPressed)
             .foregroundStyle(.green)
             .gesture(
                 LongPressGesture(minimumDuration: 1.0)
                     .updating($longPressTap, body: { (curState, state, transaction) in
                         print(curState)
                         state = curState
                         
                     })
                     .onEnded({ _ in
                         self.isPressed.toggle()
                     })
             )
     }
     
 }
 */
