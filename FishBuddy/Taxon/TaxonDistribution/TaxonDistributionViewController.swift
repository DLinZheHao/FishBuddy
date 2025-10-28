//
//  TaxonDistributionViewController.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/10/20.
//

import UIKit
import MapKit
import SwiftUI

struct TaxonDistributionView: View {
    let taxonId: Int
    var body: some View {
        TaxonDistribution(taxonId: taxonId)
            .ignoresSafeArea()
    }
}

// MARK: - SwiftUI 包裝 UIKit Map 視圖
struct TaxonDistribution: UIViewControllerRepresentable {
    let taxonId: Int
    func makeUIViewController(context: Context) -> TaxonDistributionViewController {
        TaxonDistributionViewController(taxonId: taxonId)
    }
    func updateUIViewController(_ uiViewController: TaxonDistributionViewController, context: Context) {}
}

final class TaxonDistributionViewController: UIViewController, MKMapViewDelegate {
    /// 層級類別：用來標識不同類型的地圖覆蓋層，便於建立、快取與顯示順序控制
    enum LayerKey: String {
        /// 物種分布範圍（向量多邊形；建議以 GeoJSON→Polygon 呈現）
        case range
        /// 地點/行政區等輔助底圖（向量；用於輔助理解範圍與定位）
        case places
        /// 熱度圖（瓦片；用於遠景顯示密度，通常限制較低的最大縮放層級）
        case heatmap
        /// 觀測點（向量點；由自訂 Renderer `ObservationDotsRenderer` 繪製）
        case points
    }

    // MARK: - Config
    /// iNaturalist taxon id（先寫死，之後可由外部注入）
    private let taxonId: Int

    /// 縮放門檻：多邊形 / 方塊網格 / 向量點
    private let rangeMaxZoom: Int = 8       // z ≤ 8 顯示範圍多邊形瓦片
    private let gridMinZoom: Int  = 0       // 0 ≤ z ≤ 19 顯示方塊網格
    private let gridMaxZoom: Int  = 19

    /// 地圖元件
    private let mapView = MKMapView()
    /// 覆蓋物件
    private var overlays: [LayerKey: MKTileOverlay] = [:]

    /// 地圖視野（region）變更時用的「防抖」任務。
    private var regionDebounceTask: Task<Void, Never>?

    // MARK: 物種點位物件（因功能取消，暫時不使用）
    /// 是否正在抓取觀測點資料中的旗標。
    /// - 用途：避免在同一個視角/短時間內重複送出 API 請求（節流），降低網路與繪製負擔。
    private var isFetchingObservations = false

    /// 目前顯示中的「觀測點」向量覆蓋層。
    /// - 用途：每次查詢新視窗範圍後會重建並替換，以顯示該視角內的點資料。
    private var observationOverlay: ObservationDotsOverlay?
    
    /// 顯示「觀測點」所需的最小縮放層級（小於此層級不顯示）。
    /// - 理由：在較遠的視角顯示過多點會造成視覺雜訊與效能開銷；先以熱度圖或範圍圖層呈現較合適。
    private let observationMinZoom = 12

    /// 觀測點在螢幕上的目標半徑（pt）。
    /// - 說明：實際繪製時會依 `zoomScale` 自動調整，讓視覺大小在不同縮放下維持一致。
    private var observationDotRadius: CGFloat = 3.0
    
    deinit {
        regionDebounceTask?.cancel()
    }

    init(taxonId: Int) {
        self.taxonId = taxonId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
        view.addSubview(mapView)

        // 初始視角：台灣
        mapView.setRegion(.init(center: .init(latitude: 23.7, longitude: 121.0),
                                span: .init(latitudeDelta: 7, longitudeDelta: 7)), animated: false)

        // 建立 overlay（range/places 向量、points 改自畫，保留 heatmap）
        // iNaturalist range (taxon_ranges) 與 grid（方塊計數）瓦片
        let rangeTemplate = "https://api.inaturalist.org/v1/taxon_ranges/\(taxonId)/{z}/{x}/{y}.png"
        let gridTemplate  = "https://tiles.inaturalist.org/v1/grid/{z}/{x}/{y}.png?taxon_id=\(taxonId)&verifiable=true"

        overlays[.range] = makeTileOverlay(rangeTemplate)
        overlays[.heatmap] = makeTileOverlay(gridTemplate) // 這裡用 heatmap key 代表「方塊網格」層

        // 依當前縮放層級（初始 region）決定顯示哪些底層
        ensureBaseOverlaysAdded(z: currentZoomLevel())
    }

    /// 建立通用 XYZ 瓦片 overlay（使用系統 URLCache 緩存）
    private func makeTileOverlay(_ urlTemplate: String) -> MKTileOverlay {
        let o = MKTileOverlay(urlTemplate: urlTemplate)
        o.canReplaceMapContent = false // 避免蓋掉原生地圖上面的物件
        o.minimumZ = 0
        o.maximumZ = 19
        o.tileSize = CGSize(width: 256, height: 256)
        return o
    }

    /// 計算近似 zoom（Web Mercator）
    private func currentZoomLevel() -> Int {
        let width = mapView.bounds.size.width
        let zoomScale = width / mapView.visibleMapRect.size.width
        let z = 20 + log2(zoomScale) // 0~20
        return max(0, min(20, Int(z.rounded())))
    }

    /// 根據縮放層級新增/移除基礎瓦片層（range 與 grid）
    private func ensureBaseOverlaysAdded(z: Int) {
        // Range layer：z ≤ rangeMaxZoom 顯示
        if let range = overlays[.range] {
            if !mapView.overlays.contains(where: { $0 === range }) {
                mapView.addOverlay(range, level: .aboveRoads)
            }
        } else {
            if let range = overlays[.range], mapView.overlays.contains(where: { $0 === range }) {
                mapView.removeOverlay(range)
            }
        }

        // Grid layer：gridMinZoom … gridMaxZoom 顯示, 在限定範圍加上
        if z >= gridMinZoom && z <= gridMaxZoom, let grid = overlays[.heatmap] {
            if !mapView.overlays.contains(where: { $0 === grid }) {
                mapView.addOverlay(grid, level: .aboveRoads)
            }
        } else {
            if let grid = overlays[.heatmap], mapView.overlays.contains(where: { $0 === grid }) {
                mapView.removeOverlay(grid)
            }
        }
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        regionDebounceTask?.cancel()

        // Start a new debounced task (150ms)
        regionDebounceTask = Task { [weak self] in
            // Sleep is cancellable; if another region change happens, this task is cancelled
            try? await Task.sleep(nanoseconds: 150_000_000)

            // Bail out if cancelled or self is gone
            guard !Task.isCancelled, let self else { return }

            // UI/MapKit work must run on the main actor
            await MainActor.run {
                let z = self.currentZoomLevel()
                self.ensureBaseOverlaysAdded(z: z)
//                if z >= self.observationMinZoom {
//                    self.updateObservationDots()
//                } else {
//                    // remove dots when zoomed out
//                    if let overlay = self.observationOverlay {
//                        self.mapView.removeOverlay(overlay)
//                        self.observationOverlay = nil
//                    }
//                }
            }
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // 瓦片
        if let tile = overlay as? MKTileOverlay {
            let r = MKTileOverlayRenderer(tileOverlay: tile)
            r.alpha = 0.9
            return r
        }
        // 多邊形
        if let polygon = overlay as? MKPolygon {
            let r = MKPolygonRenderer(polygon: polygon)
            r.fillColor = UIColor.systemTeal.withAlphaComponent(0.25)
            r.strokeColor = UIColor.systemTeal.withAlphaComponent(0.8)
            r.lineWidth = 1.5
            return r
        }
        // 多重多邊形
        if let multi = overlay as? MKMultiPolygon {
            let r = MKMultiPolygonRenderer(multiPolygon: multi)
            r.fillColor = UIColor.systemTeal.withAlphaComponent(0.25)
            r.strokeColor = UIColor.systemTeal.withAlphaComponent(0.8)
            r.lineWidth = 1.5
            return r
        }
        // 點位
        if overlay is ObservationDotsOverlay {
            let r = ObservationDotsRenderer(overlay: overlay)
            r.dotRadius = observationDotRadius
            r.dotFillColor = UIColor.systemRed.withAlphaComponent(0.85)
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    // MARK: - iNaturalist observations → vector dots
    private func updateObservationDots() {
        guard !isFetchingObservations else { return }
        let rect = mapView.visibleMapRect.intersection(.world)
        guard !rect.isNull else { return }

        // north + east
        let ne = MKMapPoint(x: rect.maxX, y: rect.minY).coordinate
        // south + west
        let sw = MKMapPoint(x: rect.minX, y: rect.maxY).coordinate

        // Construct a lightweight bbox query; limit results to reduce load
        var comps = URLComponents(string: "https://api.inaturalist.org/v1/observations")!
        comps.queryItems = [
            .init(name: "taxon_id", value: String(taxonId)),
            .init(name: "verifiable", value: "true"),
            .init(name: "nelat", value: String(ne.latitude)),
            .init(name: "nelng", value: String(ne.longitude)),
            .init(name: "swlat", value: String(sw.latitude)),
            .init(name: "swlng", value: String(sw.longitude)),
            .init(name: "order_by", value: "observed_on"),
            .init(name: "per_page", value: "200"), // cap to 200 points per viewport
            .init(name: "page", value: "1"),
            .init(name: "fields", value: "id,geojson,location,latitude,longitude")
        ]

        guard let url = comps.url else { return }
        isFetchingObservations = true
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            defer { self.isFetchingObservations = false }
            guard error == nil, let data else { return }
            do {
                // Parse minimal JSON (latitude/longitude)
                struct Root: Decodable { let results: [Item] }
                struct Item: Decodable { let latitude: Double?; let longitude: Double?; let location: String? }
                
                let root = try JSONDecoder().decode(Root.self, from: data)
                let coords: [CLLocationCoordinate2D] = root.results.compactMap { r in
                    if let lat = r.latitude, let lng = r.longitude { return .init(latitude: lat, longitude: lng) }
                    if let loc = r.location, let comma = loc.firstIndex(of: ",") {
                        let lat = Double(loc[..<comma].trimmingCharacters(in: .whitespaces))
                        let lng = Double(loc[loc.index(after: comma)...].trimmingCharacters(in: .whitespaces))
                        if let lat, let lng { return .init(latitude: lat, longitude: lng) }
                    }
                    return nil
                }
                let mps = coords.map { MKMapPoint($0) }
                DispatchQueue.main.async {
                    // Replace old overlay with new one
                    if let old = self.observationOverlay { self.mapView.removeOverlay(old) }
                    let overlay = ObservationDotsOverlay(points: mps)
                    self.observationOverlay = overlay
                    self.mapView.addOverlay(overlay, level: .aboveRoads)
                    // force redraw
                    if let renderer = self.mapView.renderer(for: overlay) as? ObservationDotsRenderer {
                        renderer.dotRadius = self.observationDotRadius
                        renderer.invalidatePath()
                    }
                }
            } catch {
                // ignore parse errors silently for now
            }
        }
        task.resume()
    }
    
    public func setObservationDotRadius(_ radius: CGFloat) {
        observationDotRadius = max(1, min(12, radius))
        if let overlay = observationOverlay, let r = mapView.renderer(for: overlay) as? ObservationDotsRenderer {
            r.dotRadius = observationDotRadius
            r.invalidatePath()
            r.setNeedsDisplay(mapView.visibleMapRect)
        }
    }
}
