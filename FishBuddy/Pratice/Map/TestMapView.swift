//
//  TestMapView.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/26.
//

import SwiftUI
import MapKit
import UIKit

struct MapView: View {
    var body: some View {
        INatPlaceMap()
            .ignoresSafeArea()
    }
}

// MARK: - SwiftUI 包裝 UIKit Map 視圖
struct INatPlaceMap: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MapViewController {
        MapViewController()
    }
    func updateUIViewController(_ uiViewController: MapViewController, context: Context) {}
}

// MARK: - UIKit 實作（沿用先前邏輯，完整可跑）

final class MapViewController: UIViewController, MKMapViewDelegate {
    private let mapView = MKMapView(frame: .zero)
    private let placeID = 97391 // Taiwan

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .includingAll
        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        fetchAndRenderPlace(id: placeID)
    }

    // MARK: - Networking
    private func fetchAndRenderPlace(id: Int) {
        var comps = URLComponents(string: "https://api.inaturalist.org/v1/places/\(id)")!
        comps.queryItems = [.init(name: "locale", value: "zh-TW")]
        let url = comps.url!
        print("➡️ Fetching:", url.absoluteString)

        URLSession.shared.dataTask(with: url) { data, resp, err in
            if let err = err {
                print("❌ Network error:", err); return
            }
            if let http = resp as? HTTPURLResponse {
                print("ℹ️ HTTP Status:", http.statusCode)
            }
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                print("❌ Bad HTTP response"); return
            }
            guard let data = data else { return }

            do {
                let decoded = try JSONDecoder().decode(PlacesResponse.self, from: data)
                guard let place = decoded.results.first else {
                    print("⚠️ No results"); return
                }
                print("✅ Decoded place ID:", place.id)
                print("   name:", place.name ?? "-", "display:", place.display_name ?? "-")
                if let g = place.geometry_geojson {
                    print("   geometry type:", g.type)
                    switch g.type {
                    case "Polygon":
                        print("   polygon rings:", g.polygon?.count ?? 0, "first ring points:", g.polygon?.first?.count ?? 0)
                    case "MultiPolygon":
                        print("   multiPolygon count:", g.multiPolygon?.count ?? 0)
                    default:
                        print("   geometry not handled")
                    }
                } else {
                    print("   geometry_geojson: nil")
                }
                if let bbox = place.bounding_box_geojson {
                    print("   bbox type:", bbox.type)
                } else {
                    print("   bounding_box_geojson: nil")
                }
                DispatchQueue.main.async { self.render(place: place) }
            } catch {
                print("❌ Decode error:", error)
                if let raw = String(data: data, encoding: .utf8) { print("Raw:\n", raw) }
                print("   raw length:", data.count)
            }
        }.resume()
    }

    // MARK: - Render
    private func render(place: Place) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        print("🧭 Rendering place", place.id)

        if let loc = place.location {
            let ann = MKPointAnnotation()
            ann.coordinate = .init(latitude: loc.latitude, longitude: loc.longitude)
            ann.title = place.display_name ?? place.name ?? "Place \(place.id)"
            mapView.addAnnotation(ann)
            print("   center pin at:", loc.latitude, loc.longitude)
        }

        var overlays: [MKOverlay] = []
        if let g = place.geometry_geojson {
            overlays.append(contentsOf: overlaysFrom(geometry: g))
        } else if let bbox = place.bounding_box_geojson {
            overlays.append(contentsOf: overlaysFrom(geometry: bbox))
        }
        print("   overlays count:", overlays.count)

        mapView.addOverlays(overlays)

        if let union = overlays.map(\.boundingMapRect).reduce(nil, { $0?.union($1) ?? $1 }) {
            print("   union rect:", union)
            mapView.setVisibleMapRect(
                union,
                edgePadding: .init(top: 48, left: 28, bottom: 48, right: 28),
                animated: true
            )
        } else if let loc = place.location {
            let region = MKCoordinateRegion(
                center: .init(latitude: loc.latitude, longitude: loc.longitude),
                latitudinalMeters: 500_000,
                longitudinalMeters: 500_000
            )
            mapView.setRegion(region, animated: true)
        } else {
            print("   no overlays and no center; setting world region")
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 80)
            )
            mapView.setRegion(region, animated: true)
        }
    }

    // MARK: - GeoJSON → MapKit
    private func overlaysFrom(geometry: GeoJSONGeometry) -> [MKOverlay] {
        print("🔶 overlaysFrom type:", geometry.type)
        switch geometry.type {
        case "Polygon":
            guard let rings = geometry.polygon else { return [] }
            if let poly = mkPolygon(fromRings: rings) { return [poly] }
            return []
        case "MultiPolygon":
            guard let polys = geometry.multiPolygon else { return [] }
            return polys.compactMap { mkPolygon(fromRings: $0) }
        default:
            return []
        }
    }

    /// rings: 第一個 ring = 外環；其後為洞（holes）；點為 [lon, lat]
    private func mkPolygon(fromRings rings: [[[Double]]]) -> MKPolygon? {
        print("   mkPolygon rings:", rings.count, "outer points:", rings.first?.count ?? 0)
        guard let outer = rings.first, !outer.isEmpty else { return nil }

        func coords(from ring: [[Double]]) -> [CLLocationCoordinate2D] {
            ring.compactMap { pair in
                guard pair.count >= 2 else { return nil }
                return .init(latitude: pair[1], longitude: pair[0]) // GeoJSON: [lon, lat]
            }
        }

        let outerCoords = coords(from: outer)
        let holes: [MKPolygon] = rings.dropFirst().compactMap {
            let cs = coords(from: $0)
            return cs.isEmpty ? nil : MKPolygon(coordinates: cs, count: cs.count)
        }

        return MKPolygon(coordinates: outerCoords, count: outerCoords.count, interiorPolygons: holes)
    }

    // MARK: - MKMapViewDelegate
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let p = overlay as? MKPolygon {
            let r = MKPolygonRenderer(polygon: p)
            r.fillColor = UIColor.systemTeal.withAlphaComponent(0.25)
            r.strokeColor = UIColor.systemTeal
            r.lineWidth = 2
            print("   rendering polygon points:", p.pointCount)
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - Models

struct PlacesResponse: Codable {
    let total_results: Int
    let page: Int
    let per_page: Int
    let results: [Place]
}

struct Place: Codable {
    let id: Int
    let name: String?
    let display_name: String?
    let admin_level: Int?
    let place_type: Int?
    let location: LatLng?
    let geometry_geojson: GeoJSONGeometry?
    let bounding_box_geojson: GeoJSONGeometry?
}

struct LatLng: Codable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    private struct Obj: Codable { let latitude: Double; let longitude: Double }

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()

        // 1) Try string formats: "lat,lon" or WKT: "POINT(lon lat)"
        if let s = try? single.decode(String.self) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            // WKT: POINT(lon lat)
            if trimmed.uppercased().hasPrefix("POINT(") && trimmed.hasSuffix(")") {
                let inner = trimmed.dropFirst("POINT(".count).dropLast()
                let parts = inner.split(whereSeparator: { $0 == " " || $0 == "," })
                if parts.count >= 2,
                   let lon = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let lat = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    self.latitude = lat
                    self.longitude = lon
                    return
                }
            }
            // CSV: lat,lon
            let parts = trimmed.split(separator: ",")
            if parts.count == 2,
               let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                self.latitude = lat
                self.longitude = lon
                return
            }
            throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unrecognized location string format: \(s)")
        }

        // 2) Try object: {"latitude": ..., "longitude": ...}
        if let obj = try? Obj(from: decoder) {
            self.latitude = obj.latitude
            self.longitude = obj.longitude
            return
        }

        // 3) Try array: [lat, lon]
        if let arr = try? single.decode([Double].self), arr.count >= 2 {
            self.latitude = arr[0]
            self.longitude = arr[1]
            return
        }

        throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unsupported location payload")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
    }

    enum CodingKeys: String, CodingKey { case latitude, longitude }
}

/// 支援 Polygon / MultiPolygon；其餘類型可依需求擴充
struct GeoJSONGeometry: Codable {
    let type: String
    let polygon: [[[Double]]]?         // Polygon -> [rings][points][lon/lat]
    let multiPolygon: [[[[Double]]]]?  // MultiPolygon -> [polygons][rings][points][lon/lat]

    enum CodingKeys: String, CodingKey { case type, coordinates }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        switch type {
        case "Polygon":
            polygon = try c.decode([[[Double]]].self, forKey: .coordinates)
            multiPolygon = nil
        case "MultiPolygon":
            multiPolygon = try c.decode([[[[Double]]]].self, forKey: .coordinates)
            polygon = nil
        default:
            polygon = nil
            multiPolygon = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        switch type {
        case "Polygon":
            if let polygon {
                try c.encode(polygon, forKey: .coordinates)
            } else {
                try c.encodeNil(forKey: .coordinates)
            }
        case "MultiPolygon":
            if let multiPolygon {
                try c.encode(multiPolygon, forKey: .coordinates)
            } else {
                try c.encodeNil(forKey: .coordinates)
            }
        default:
            try c.encodeNil(forKey: .coordinates)
        }
    }
}
