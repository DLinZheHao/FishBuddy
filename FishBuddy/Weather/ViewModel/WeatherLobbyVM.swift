//
//  WeatherLobbyVM.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import Foundation
import Combine
import SwiftUI

class WeatherLobbyVM: ObservableObject {
    // 綁訂事件
    var cancellables = Set<AnyCancellable>()

    /// 搜尋城市文字
    @Published var searchText: String = ""
    /// 今明 36 小時天氣預報資料
    @Published var weatherResponse: WeatherResponse?

}
