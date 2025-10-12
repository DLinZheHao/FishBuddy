//
//  ImageInspectorView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/10.
//

import Foundation
import SwiftUI
import Kingfisher

struct ImageInspectorView: View {
    @State private var currentID: Int? = 0
    @State private var viewerState: ViewerState? = nil
    
    var images: [ImageData]
    
    var body: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width
            ZStack {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(images.indices, id: \.self) { i in
                            ImageCardView(
                                desc: images[i].description ?? "",
                                imageURL: images[i].image,
                                isShowDetails: .constant(false)
                            )
                            .frame(width: pageWidth, height: proxy.size.height)
                            .id(i)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewerState = ViewerState(index: i)
                            }
                        }
                    }
                    .frame(height: proxy.size.height)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentID)

                // 指示點
                VStack {
                    Spacer()
                    PageDots(count: images.count, current: currentID ?? 0)
                        .padding(.bottom, 12)
                }
            }
            // 全螢幕圖片檢視器
            .fullScreenCover(item: $viewerState) { state in
                ImageViewer(images: images.map { $0.image }, startIndex: state.index)
            }
        }
    }
}

// 簡單的頁面指示點（dots）
struct PageDots: View {
    let count: Int
    let current: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .frame(width: i == current ? 8 : 6, height: i == current ? 8 : 6)
                    .opacity(i == current ? 1.0 : 0.3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// 可滑動分頁的圖片檢視器
struct ImageViewer: View {
    let images: [URL]
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(images: [URL], startIndex: Int) {
        self.images = images
        self._index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(images.indices, id: \.self) { i in
                    ZoomableImage(imageURL: images[i])
                        .tag(i)
                        .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page)

            // 關閉按鈕
            VStack {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .padding(12)
                        .tint(.white)
                }
                Spacer()
            }
        }
    }
}

// 可縮放的單張圖片頁面（支援 pinch 與雙擊放大/還原）
private struct ZoomableImage: View {
    let imageURL: URL
    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { _ in
            KFImage(imageURL)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
                    .onEnded { value in
                        // 放手時做個合理的夾取，避免過大或過小
                        scale = min(max(value, 1.0), 4.0)
                    }
                )
                .onTapGesture(count: 2) {
                    // 雙擊在 1x 與 2x 之間切換
                    withAnimation(.easeInOut) {
                        scale = (abs(scale - 1.0) < 0.01) ? 2.0 : 1.0
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}

struct ImageCardView: View {
    let desc: String
    let imageURL: URL
    
    @Binding var isShowDetails: Bool
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                KFImage(imageURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }
    }
}

//#Preview {
//    ImageInspectorView(images: <#[ImageData]#>)
//}

