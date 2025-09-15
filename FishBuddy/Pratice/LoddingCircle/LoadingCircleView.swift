//
//  LoadingCircleView.swift
//  FishBuddy
//
//  Created by LinZheHao on 2025/9/12.
//

import SwiftUI

struct ProgressRingView: View {
    var progress: Double
    
    var thickness: CGFloat = 30.0
    var width: CGFloat = 250.0
    var gradient = Gradient(colors: [.darkPurple, .lightYellow])
    var startAngle = -90.0
    
    private var radius: Double {
        Double(width / 2)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray6), lineWidth: thickness)
            
            // － 進度圓環
            RingShape(progress: progress, thickness: thickness)
                .fill(AngularGradient(gradient: gradient, center: .center, startAngle: .degrees(startAngle), endAngle: .degrees(360 * progress + startAngle)))
            
            // － 讓圓環的端點有個小圓點
            RingTip(progress: progress, startAngle: startAngle, ringRadius: radius)
                .frame(width: thickness, height: thickness)
                .foregroundColor(progress > 0.96 ? gradient.stops[1].color : Color.clear)
                .shadow(color: progress > 0.96 ? Color.black.opacity(0.15) : Color.clear, radius: 2, x: ringTipShadowOffset.x, y: ringTipShadowOffset.y)
        }
        .frame(width: width, height: width, alignment: .center)
        .animation(.easeInOut(duration: 3.0), value: progress)
    }
    
    private func ringTipPosition(progress: Double) -> CGPoint {
        let angle = 360 * progress + startAngle
        let angleInRadian = angle * .pi / 180
        
        return CGPoint(x: radius * cos(angleInRadian), y: radius * sin(angleInRadian))
    }
    
    private var ringTipShadowOffset: CGPoint {
        let shadowPosition = ringTipPosition(progress: progress + 0.01)
        let circlePosition = ringTipPosition(progress: progress)
        
        return CGPoint(x: shadowPosition.x - circlePosition.x, y: shadowPosition.y - circlePosition.y)
    }
}

#Preview("ProgressRingView (50%)") {
    ProgressRingView(progress: 0.5)
}

#Preview("ProgressRingView (90%)") {
    ProgressRingView(progress: 0.9)
}

#Preview("ProgressRingView (99%)") {
    ProgressRingView(progress: 0.99)
}

#Preview("ProgressRingView (Animated)") {
    struct Demo: View {
        @State private var p: Double = 0.0
        var body: some View {
            ProgressRingView(progress: p)
                .onAppear {
                        p = 1.0
                }
        }
    }
    return Demo()
}



struct RingShape: Shape {
    var progress: Double = 0.0
    var thickness: CGFloat = 30.0
    
    var startAngle: Double = -90.0
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        path.addArc(center: CGPoint(x: rect.width / 2.0, y: rect.height / 2.0),
                    radius: min(rect.width, rect.height) / 2.0,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(360 * progress + startAngle), clockwise: false)
        
        return path.strokedPath(.init(lineWidth: thickness, lineCap: .round))
    }
}

struct RingTip: Shape {
    var progress: Double = 0.0
    var startAngle: Double = -90.0
    var ringRadius: Double
    
    private var position: CGPoint {
        let angle = 360 * progress + startAngle
        let angleInRadian = angle * .pi / 180
        
        return CGPoint(x: ringRadius * cos(angleInRadian), y: ringRadius * sin(angleInRadian))
    }
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard progress > 0.0 else {
            return path
        }
                
        let frame = CGRect(x: position.x, y: position.y, width: rect.size.width, height: rect.size.height)
        
        path.addRoundedRect(in: frame, cornerSize: frame.size)
        
        return path
    }

}

extension Color {
    
    public init(red: Int, green: Int, blue: Int, opacity: Double = 1.0) {
        let redValue = Double(red) / 255.0
        let greenValue = Double(green) / 255.0
        let blueValue = Double(blue) / 255.0
        
        self.init(red: redValue, green: greenValue, blue: blueValue, opacity: opacity)
    }

    public static let lightRed = Color(red: 231, green: 76, blue: 60)
    public static let darkRed = Color(red: 192, green: 57, blue: 43)
    public static let lightGreen = Color(red: 46, green: 204, blue: 113)
    public static let darkGreen = Color(red: 39, green: 174, blue: 96)
    public static let lightPurple = Color(red: 155, green: 89, blue: 182)
    public static let darkPurple = Color(red: 142, green: 68, blue: 173)
    public static let lightBlue = Color(red: 52, green: 152, blue: 219)
    public static let darkBlue = Color(red: 41, green: 128, blue: 185)
    public static let lightYellow = Color(red: 241, green: 196, blue: 15)
    public static let darkYellow = Color(red: 243, green: 156, blue: 18)
    public static let lightOrange = Color(red: 230, green: 126, blue: 34)
    public static let darkOrange = Color(red: 211, green: 84, blue: 0)
    public static let purpleBg = Color(red: 69, green: 51, blue: 201)
}
