//
//  LocationService.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2026/4/13.
//

import Foundation
import CoreLocation
import Combine

/// 封裝 CLLocationManager，提供 Combine publisher 與 async/await 介面
final class LocationService: NSObject {

    static let shared = LocationService()

    // MARK: - Published state

    /// 目前授權狀態（可直接 sink 觀察）
    private let authStatusSubject: CurrentValueSubject<CLAuthorizationStatus, Never>

    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authStatusSubject.eraseToAnyPublisher()
    }

    var authorizationStatus: CLAuthorizationStatus {
        authStatusSubject.value
    }

    // MARK: - Private

    private let manager: CLLocationManager
    /// 等待一次性位置結果的 continuation
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        let mgr = CLLocationManager()
        self.manager = mgr
        self.authStatusSubject = CurrentValueSubject(mgr.authorizationStatus)
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public API

    /// 請求裝置目前位置（async）。
    /// - 若尚未授權，會先彈出授權對話框再取位置。
    /// - 若授權被拒，丟出 `LocationError.permissionDenied`。
    func requestLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            // 若已有等待中的 continuation，直接取消舊的再換新的
            if let pending = locationContinuation {
                pending.resume(throwing: LocationError.locationUnavailable)
            }
            locationContinuation = continuation

            switch manager.authorizationStatus {
            case .notDetermined:
                // 授權對話框關閉後由 locationManagerDidChangeAuthorization 繼續處理
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                locationContinuation = nil
                continuation.resume(throwing: LocationError.permissionDenied)
            @unknown default:
                locationContinuation = nil
                continuation.resume(throwing: LocationError.permissionDenied)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authStatusSubject.send(status)

        guard locationContinuation != nil else { return }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            let c = locationContinuation
            locationContinuation = nil
            c?.resume(throwing: LocationError.permissionDenied)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        let c = locationContinuation
        locationContinuation = nil
        c?.resume(returning: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let c = locationContinuation
        locationContinuation = nil
        c?.resume(throwing: error)
    }
}

// MARK: - Error types

extension LocationService {
    enum LocationError: LocalizedError {
        case permissionDenied
        case locationUnavailable

        var errorDescription: String? {
            switch self {
            case .permissionDenied:    return "未授予位置權限，無法取得目前位置"
            case .locationUnavailable: return "無法取得裝置位置，請稍後再試"
            }
        }
    }
}
