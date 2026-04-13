//
//  WeatherLobbyVM.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/15.
//

import Foundation
import Combine
import CoreLocation
import Moya

// MARK: - Loading state

enum WeatherLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - ViewModel

class WeatherLobbyVM: ObservableObject {

    // MARK: Combine
    var cancellables = Set<AnyCancellable>()

    // MARK: Search
    /// 搜尋城市文字
    @Published var searchText: String = ""

    // MARK: Weather list
    /// 今明 36 小時天氣預報資料
    @Published var weatherResponse: WeatherResponse?
    /// 列表載入狀態
    @Published var listLoadingState: WeatherLoadingState = .idle

    // MARK: Detail page
    /// 點擊城市後取得的完整地點詳細資料，有值時觸發導航
    @Published var locationDetail: MarineFishingDetailResponse? = nil
    /// 是否正在載入地點詳細資料
    @Published var isFetchingDetail: Bool = false

    // MARK: Location & city selection
    /// CoreLocation 授權狀態
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    /// 目前是否以裝置位置為主
    @Published var isUsingDeviceLocation: Bool = true
    /// 使用者手動選取的城市（nil 代表跟隨裝置位置）
    @Published var selectedCity: String? = nil

    // MARK: Persistence (UserDefaults)
    private enum PersistKey {
        static let city               = "WeatherSelectedCity"
        static let usesDeviceLocation = "WeatherUsesDeviceLocation"
    }

    private var persistedCity: String {
        get { UserDefaults.standard.string(forKey: PersistKey.city) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: PersistKey.city) }
    }

    private var persistedUsesDeviceLocation: Bool {
        get {
            // object(forKey:) 回傳 nil 代表從未設定，預設 true（跟隨裝置位置）
            UserDefaults.standard.object(forKey: PersistKey.usesDeviceLocation) as? Bool ?? true
        }
        set { UserDefaults.standard.set(newValue, forKey: PersistKey.usesDeviceLocation) }
    }

    // MARK: Init

    init() {
        // 監聽 LocationService 授權狀態
        LocationService.shared.authorizationStatusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$locationStatus)

        // 從持久化恢復上次選擇
        isUsingDeviceLocation = persistedUsesDeviceLocation
        let saved = persistedCity
        if !persistedUsesDeviceLocation && !saved.isEmpty {
            selectedCity = saved
        }
    }

    // MARK: - Launch entry point

    /// 進入天氣頁時呼叫，依持久化設定選擇正確的 API 呼叫方式
    func loadWeatherOnLaunch() {
        if isUsingDeviceLocation {
            fetchWeatherForCurrentLocation()
        } else if let city = selectedCity, !city.isEmpty {
            fetchWeatherForCityList(city)
        } else {
            fetchWeatherAll()
        }
    }

    // MARK: - Fetch list: by device location

    /// 取得裝置位置後呼叫 `/forecast/36-hour?lat=&lon=`
    func fetchWeatherForCurrentLocation() {
        listLoadingState = .loading
        Task { @MainActor in
            do {
                let location = try await LocationService.shared.requestLocation()
                let params: [String: Any] = [
                    "lat": location.coordinate.latitude,
                    "lon": location.coordinate.longitude
                ]
                self.fetchWeatherList(params: params)
            } catch {
                // 位置取得失敗：降級到上次選取的城市，或全城市列表
                if let city = self.selectedCity, !city.isEmpty {
                    self.fetchWeatherList(params: ["city": city])
                } else {
                    self.fetchWeatherList(params: [:])
                }
            }
        }
    }

    // MARK: - Fetch list: by city (user selected)

    /// 使用者手動選城市 → `/forecast/36-hour?city=`
    /// 選擇後不會自動切回裝置位置，除非明確呼叫 `useDeviceLocation()`
    func fetchWeatherForCityList(_ city: String) {
        selectedCity = city
        isUsingDeviceLocation = false
        persistedCity = city
        persistedUsesDeviceLocation = false

        listLoadingState = .loading
        fetchWeatherList(params: ["city": city])
    }

    // MARK: - Fetch list: all cities

    /// 呼叫 `/forecast/36-hour`（無參數），取得完整城市列表
    func fetchWeatherAll() {
        listLoadingState = .loading
        fetchWeatherList(params: [:])
    }

    // MARK: - Use device location (explicit user action)

    /// 使用者主動點擊「使用目前位置」
    func useDeviceLocation() {
        selectedCity = nil
        isUsingDeviceLocation = true
        persistedUsesDeviceLocation = true
        persistedCity = ""
        fetchWeatherForCurrentLocation()
    }

    // MARK: - Fetch detail page

    /// 進入城市詳細頁時呼叫 `/forecast/tidy_info?location=`
    func fetchLocationDetail(city: String) {
        isFetchingDetail = true
        let target = WeatherAPIService.tideForecast(params: ["location": city])

        requestAndDecode(target: target, as: MarineFishingDetailResponse.self)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isFetchingDetail = false
                    if case .failure(let error) = completion {
                        print("fetchLocationDetail failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] model in
                    self?.isFetchingDetail = false
                    self?.locationDetail = model
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Private helpers

    private func fetchWeatherList(params: [String: Any]) {
        let target = WeatherAPIService.weatherAll36(params: params)
        requestAndDecode(target: target, as: WeatherResponse.self)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.listLoadingState = .error(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.weatherResponse = response
                    self?.listLoadingState = .loaded
                }
            )
            .store(in: &cancellables)
    }

    /// 通用 API 呼叫 + JSON decode pipeline
    private func requestAndDecode<T: Decodable>(
        target: any TargetType,
        as type: T.Type
    ) -> AnyPublisher<T, Error> {
        APIService.shareManager()
            .requestDataCombine(target: target)
            .tryMap { data -> Data in
                guard let data = data as? Data else {
                    throw NSError(domain: "WeatherLobbyVM.InvalidData", code: 0)
                }
                return data
            }
            .decode(type: type, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
