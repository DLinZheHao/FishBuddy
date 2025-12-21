//
//  CaptureToolbar.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/11/19.
//

import SwiftUI

// MARK: - 底部工具列（拍照 + 最新縮圖）
struct CaptureToolbar: View {
    let lastPhoto: UIImage?
    let onCapture: () -> Void
    let onClose: () -> Void
    let zoom: CGFloat
    /// 左右兩側固定寬度，確保快門在幾何正中央
    private let sideWidth: CGFloat = 88

    var body: some View {
        HStack {
            // 左邊區塊：固定 sideWidth，按鈕靠左
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .frame(width: sideWidth, alignment: .leading)

            Spacer(minLength: 0)

            // 快門
            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 76, height: 76)
                        .overlay(
                            Circle().stroke(Color.black, lineWidth: 2)
                        )
                        .padding(4)
                        .background(
                            Circle()
                                .fill(Color.white) // 塗上想要的顏色
                        )
                        .overlay(
                            Circle().stroke(Color.black, lineWidth: 2)
                        )
                    if zoom > 1.10 {
                        Text(String(format: "%.1fx", zoom))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
            }

            Spacer(minLength: 0)

            // 右邊區塊：固定 sideWidth，縮圖靠右
            HStack {
                Spacer()
                if let image = lastPhoto {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Color.clear
                        .frame(width: 56, height: 56) // 固定 56，避免寬度變來變去
                }
            }
            .frame(width: sideWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

//#Preview {
//    CaptureToolbar()
//}
