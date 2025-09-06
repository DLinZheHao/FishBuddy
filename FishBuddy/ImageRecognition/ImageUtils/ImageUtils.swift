//
//  ImageUtils.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/8/24.
//

import Foundation
import UIKit
import PhotosUI

extension UIImage {
    /// 將圖片縮小到 8×8，取平均顏色 (RGB)，結果落在 0–1
    func averageRGBFeature() -> [CGFloat]? {
        // 定義縮小後的圖片尺寸為 8x8
        let size = CGSize(width: 8, height: 8)
        
        // 建立一個 UIGraphicsImageRenderer，準備繪製新的縮小圖片
        let renderer = UIGraphicsImageRenderer(size: size)
        // 使用 renderer 繪製縮小後的圖片
        let resized = renderer.image { _ in
            // 將原圖繪製到指定大小的矩形中，完成縮小
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        
        // 取得縮小後圖片的 CGImage，並取得像素資料指標
        guard let cgImage = resized.cgImage,
              let data = cgImage.dataProvider?.data,
              // ptr 是 UnsafePointer<UInt8>，指向圖片像素資料的指標。
              // 每個像素由 4 個 byte (R,G,B,A) 組成。
              // 可透過 offset 計算存取正確的像素位置。
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        // 取得圖片寬度（像素數）
        let width = cgImage.width
        // 取得圖片高度（像素數）
        let height = cgImage.height
        // 每個像素佔用 4 個位元組（bytes），分別儲存 R（紅）、G（綠）、B（藍）、A（透明度）四個通道。
        // 每個通道各佔 1 byte（範圍 0–255），所以總共 4 bytes。
        // 計算 offset 時會根據這個數字跳到正確的像素資料位置。
        let bytesPerPixel = 4
        
        // 用來累加所有像素的紅、綠、藍色值
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        
        // 逐像素遍歷圖片的每個像素，計算總 RGB 值
//        假設圖片是 8×8，bytesPerPixel=4：
//            •    像素 (0,0) → (0*8+0)*4=0 → 從第 0 個 byte 開始（第一個像素）。
//            •    像素 (1,0) → (0*8+1)*4=4 → 從第 4 個 byte 開始（第二個像素）。
//            •    像素 (0,1) → (1*8+0)*4=32 → 第二列的第一個像素（第 9 個像素）。
        for y in 0..<height {
            for x in 0..<width {
                // 計算此像素在資料陣列中的起始位移 (offset)
                let offset = (y * width + x) * bytesPerPixel
                // 讀取紅色通道值，並正規化到 0~1 範圍
                let r = CGFloat(ptr[offset])   / 255.0
                // 讀取綠色通道值，並正規化到 0~1 範圍
                let g = CGFloat(ptr[offset+1]) / 255.0
                // 讀取藍色通道值，並正規化到 0~1 範圍
                let b = CGFloat(ptr[offset+2]) / 255.0
                
                // 累加各通道值
                totalR += r
                totalG += g
                totalB += b
            }
        }
        
        // 計算總像素數量
        let count = CGFloat(width * height)
        // 計算平均 RGB 值，並以陣列形式回傳
        return [totalR/count, totalG/count, totalB/count]
    }
    
    /// 計算圖片的 24 維 RGB 直方圖特徵。
    /// - Parameter resize: 將圖片縮放到指定大小（預設 64x64）以加快計算。
    /// - Returns: 一個長度為 24 的陣列 [R0...R7, G0...G7, B0...B7]，每個值代表對應顏色 bin 的相對頻率（已正規化到 0–1）。
    ///
    /// 範例：
    /// - R 通道分為 8 個 bin（0–31, 32–63, ... , 224–255），其餘 G、B 同理。
    /// - 每個 bin 計算落入的像素數量，最後除以總像素數 → 轉換為比例。
    /// - 輸出向量長度為 24，適合做影像相似度比較。
    /// 24 維 RGB 直方圖（每通道 8 bins），回傳 [R0...R7, G0...G7, B0...B7]，每一維 ∈ [0,1]
    func rgbHistogram24Feature(resize: Int = 64) -> [CGFloat]? {
        let size = CGSize(width: resize, height: resize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let small = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cg = small.cgImage,
              let data = cg.dataProvider?.data,
              let p = CFDataGetBytePtr(data) else { return nil }
        
        let w = cg.width, h = cg.height, bpp = 4
        var rHist = [CGFloat](repeating: 0, count: 8)
        var gHist = [CGFloat](repeating: 0, count: 8)
        var bHist = [CGFloat](repeating: 0, count: 8)
        
        for y in 0..<h {
            for x in 0..<w {
                let o = (y * w + x) * bpp
                let r = Int(p[o])      // 0...255
                let g = Int(p[o + 1])
                let b = Int(p[o + 2])
                rHist[r / 32] += 1
                gHist[g / 32] += 1
                bHist[b / 32] += 1
            }
        }
        // 總像素量
        let count = CGFloat(w * h)
        // L1 normalize：轉換為每通道的頻率（加總=1） 直方圖做 L1 正規化（每通道各自除以像素數
        for i in 0..<8 { rHist[i] /= count; gHist[i] /= count; bHist[i] /= count }
        
        return rHist + gHist + bHist
    }
    
}

// MARK: - 相似度計算

/// 計算 L2：差多少
func l2Distance(_ a: [CGFloat], _ b: [CGFloat]) -> CGFloat {
    zip(a, b).map { pow($0 - $1, 2) }.reduce(0, +).squareRoot()
}

/// 計算 cos：多相似
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    let dot = zip(a, b).map { $0 * $1 }.reduce(0, +)
    let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
    let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
    return dot / (normA * normB)
}

/// 計算正規化
func normalized(_ v: [CGFloat]) -> [CGFloat] {
    let norm = sqrt(v.map { $0 * $0 }.reduce(0, +))
    guard norm > 0 else { return v }
    return v.map { $0 / norm }
}

// MARK: - Protocols
protocol FeatureExtractor {
    var name: String { get }
    func extract(from image: UIImage) -> [CGFloat]?
}

protocol SimilarityMetric {
    var name: String { get }
    /// 回傳越大越相似（若是距離，請回傳負值）
    func score(query: [CGFloat], candidate: [CGFloat]) -> CGFloat
}

// query：使用者剛選的圖片 → 抽出來的特徵向量
// candidate：資料庫裡每一張圖片的特徵向量

struct AverageColorExtractor: FeatureExtractor {
    let name = "avg3"
    func extract(from image: UIImage) -> [CGFloat]? { image.averageRGBFeature() }
}

struct RGBHistogram24Extractor: FeatureExtractor {
    let name = "hist24"
    func extract(from image: UIImage) -> [CGFloat]? { image.rgbHistogram24Feature() }
}

struct L2Metric: SimilarityMetric {
    let name = "l2"
    func score(query: [CGFloat], candidate: [CGFloat]) -> CGFloat {
        -l2Distance(query, candidate) // 距離小 → 分數高
    }
}

//struct CosineMetric: SimilarityMetric {
//    let name = "cosine"
//    func score(query: [CGFloat], candidate: [CGFloat]) -> CGFloat {
//        cosineSimilarity(query, candidate) // 越大越像
//    }
//}

struct NormL2Metric: SimilarityMetric {
    let name = "normL2"
    func score(query: [CGFloat], candidate: [CGFloat]) -> CGFloat {
        let qn = normalized(query)
        let cn = normalized(candidate)
        return -l2Distance(qn, cn)
    }
}

// MARK: - Service
struct ImageSearchService {
    let extractor: FeatureExtractor
    let metric: SimilarityMetric

    func buildDB(from images: [(name: String, image: UIImage)]) -> [ImageItem] {
        images.compactMap { pair in
            guard let f = extractor.extract(from: pair.image) else { return nil }
            return ImageItem(name: pair.name, image: pair.image, feature: f)
        }
    }

    func topK(queryImage: UIImage, db: [ImageItem], k: Int = 3) -> [(item: ImageItem, score: CGFloat)] {
        guard let qf = extractor.extract(from: queryImage), !db.isEmpty else { return [] }
        return db.map { ($0, metric.score(query: qf, candidate: $0.feature)) }
                 .sorted { $0.1 > $1.1 }
                 .prefix(k).map { $0 }
    }
}

// 準備 extractor / metric
//let extractor = RGBHistogram24Extractor()      // 或 AverageColorExtractor()
//let metric = CosineMetric()                    // 或 L2Metric() / NormL2Metric()
//
//// 建資料庫（用你的 assets）
//let images: [(String, UIImage)] = [
//    ("forest", UIImage(named: "forest")!),
//    ("beach",  UIImage(named: "beach")!),
//    ("sea",    UIImage(named: "sea")!),
//    ("city",   UIImage(named: "city")!)
//]
//let service = ImageSearchService(extractor: extractor, metric: metric)
//let db2 = service.buildDB(from: images)
//
//// 查詢
//if let query = UIImage(named: "sea") {
//    let top = service.topK(queryImage: query, db: db2, k: 3)
//    print("[\(extractor.name)+\(metric.name)] Top-3:", top.map { "\($0.item.name) (\($0.score))" })
//}

/// 建立顏色
extension UIColor {
    convenience init(rgbFeature: [CGFloat]) {
        let r = rgbFeature.indices.contains(0) ? rgbFeature[0] : 0
        let g = rgbFeature.indices.contains(1) ? rgbFeature[1] : 0
        let b = rgbFeature.indices.contains(2) ? rgbFeature[2] : 0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - 圖片資料結構
struct ImageItem {
    let name: String
    let image: UIImage
    let feature: [CGFloat]
}

// MARK: - 搜尋
//func searchSimilar(queryImage: UIImage, in db: [ImageItem], topK: Int = 3, useCosine: Bool = false) -> [ImageItem] {
//    guard let queryFeature = queryImage.averageRGBFeature() else { return [] }
//    
//    let scored = db.map { item -> (ImageItem, CGFloat) in
//        let score: CGFloat
//        if useCosine {
//            score = cosineSimilarity(queryFeature, item.feature) // 越大越相似
//        } else {
//            score = -l2Distance(queryFeature, item.feature) // 越小越相似 → 取負號
//        }
//        return (item, score)
//    }
//    
//    return scored.sorted { $0.1 > $1.1 }.prefix(topK).map { $0.0 }
//}

// MARK: - 相似度與距離
enum Metric {
    case l2
    case cosine
    case normL2
}

// MARK: - 特徵快取
private func cacheURL() -> URL {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return dir.appendingPathComponent("avgcolor_cache.json")
}

private func loadFeatureCache() -> [String: [CGFloat]] {
    let url = cacheURL()
    guard let data = try? Data(contentsOf: url),
          let raw = try? JSONDecoder().decode([String: [Double]].self, from: data) else {
        return [:]
    }
    var out: [String: [CGFloat]] = [:]
    for (k, v) in raw { out[k] = v.map { CGFloat($0) } }
    return out
}

private func saveFeatureCache(_ dict: [String: [CGFloat]]) {
    let url = cacheURL()
    let raw = dict.mapValues { $0.map { Double($0) } }
    if let data = try? JSONEncoder().encode(raw) {
        try? data.write(to: url)
    }
}

// MARK: - 主畫面
final class ViewController: UIViewController {

    // UI
    private let queryImageView = UIImageView()
    private let pickButton = UIButton(type: .system)
    private let metricControl = UISegmentedControl(items: ["L2", "Cosine", "Norm L2"])
    private let tableView = UITableView()
    private let headerLabel = UILabel()

    // Data
    private var database: [ImageItem] = []
    private var results: [(item: ImageItem, score: CGFloat)] = []
    private var currentMetric: Metric = .l2
    private var currentQuery: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Image Search (Avg Color)"
        view.backgroundColor = .systemBackground
        setupUI()
        loadDatabase()
    }

    // 建立資料庫：從 Assets 載入圖片並抽特徵
    private func loadDatabase() {
        let names = ["forest", "beach", "sea", "city"]
        var cache = loadFeatureCache()
        database = names.compactMap { name in
            guard let img = UIImage(named: name) else { return nil }
            let feat: [CGFloat]
            if let cached = cache[name] {
                feat = cached
            } else {
                feat = img.averageRGBFeature() ?? []
                cache[name] = feat
            }
            return ImageItem(name: name, image: img, feature: feat)
        }
        saveFeatureCache(cache)
        tableView.reloadData()
    }

    private func setupUI() {
        // Query 預覽
        queryImageView.contentMode = .scaleAspectFill
        queryImageView.clipsToBounds = true
        queryImageView.backgroundColor = .secondarySystemBackground
        queryImageView.layer.cornerRadius = 8

        // 選取圖片按鈕
        pickButton.setTitle("選取查詢圖片", for: .normal)
        pickButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)

        // 指標切換
        metricControl.selectedSegmentIndex = 0
        metricControl.addTarget(self, action: #selector(metricChanged), for: .valueChanged)

        // 標題
        headerLabel.text = "結果（Top 3）"
        headerLabel.font = .boldSystemFont(ofSize: 16)

        // 表格
        tableView.register(ResultCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.rowHeight = 72

        // 版面
        let stack = UIStackView(arrangedSubviews: [queryImageView, pickButton, metricControl, headerLabel, tableView])
        stack.axis = .vertical
        stack.spacing = 12
        view.addSubview(stack)

        // Auto Layout
        stack.translatesAutoresizingMaskIntoConstraints = false
        queryImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            queryImageView.heightAnchor.constraint(equalToConstant: 180)
        ])
    }

    @objc private func pickImage() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func metricChanged() {
        switch metricControl.selectedSegmentIndex {
        case 0: currentMetric = .l2
        case 1: currentMetric = .cosine
        case 2: currentMetric = .normL2
        default: currentMetric = .l2
        }
        runSearchIfPossible()
    }

    private func runSearchIfPossible() {
//        guard let query = currentQuery, let qFeat = query.averageRGBFeature(), !database.isEmpty else {
//            results = []
//            tableView.reloadData()
//            return
//        }

//        // 計分：Cosine 越大越好；L2 越小越好（取負號讓分數大者在前）
//        results = database.map { item in
//            switch currentMetric {
//            case .l2:
//                let d = l2Distance(qFeat, item.feature)
//                return (item, -d)
//            case .cosine:
//                let s = cosineSimilarity(qFeat, item.feature)
//                return (item, s)
//            case .normL2:
//                let qn = normalized(qFeat)
//                let fn = normalized(item.feature)
//                let d = l2Distance(qn, fn)
//                return (item, -d)
//            }
//        }
//        .sorted { $0.score > $1.score }
//        .prefix(3)
//        .map { $0 }
//
//        tableView.reloadData()
    }
}

// MARK: - 表格 Cell
final class ResultCell: UITableViewCell {
    private let thumb = UIImageView()
    private let nameLabel = UILabel()
    private let scoreLabel = UILabel()
    private let colorBox = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = 6
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        scoreLabel.font = .systemFont(ofSize: 13)
        scoreLabel.textColor = .secondaryLabel

        colorBox.layer.cornerRadius = 4
        colorBox.clipsToBounds = true
        colorBox.widthAnchor.constraint(equalToConstant: 16).isActive = true
        colorBox.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let nameRow = UIStackView(arrangedSubviews: [nameLabel, colorBox])
        nameRow.axis = .horizontal
        nameRow.alignment = .center
        nameRow.spacing = 8

        let right = UIStackView(arrangedSubviews: [nameRow, scoreLabel])
        right.axis = .vertical
        right.alignment = .leading
        right.spacing = 4

        let row = UIStackView(arrangedSubviews: [thumb, right])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12

        contentView.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        thumb.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            thumb.widthAnchor.constraint(equalToConstant: 56),
            thumb.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: ImageItem, score: CGFloat, metric: Metric) {
        thumb.image = item.image
        nameLabel.text = item.name
        switch metric {
        case .l2:
            scoreLabel.text = String(format: "L2 距離：%.4f（越小越相似）", -score) // 分數保存的是負距離
        case .cosine:
            scoreLabel.text = String(format: "Cosine 相似度：%.4f（越大越相似）", score)
        case .normL2:
            scoreLabel.text = String(format: "Norm L2 距離：%.4f（越小越相似）", -score)
        }
        colorBox.backgroundColor = UIColor(rgbFeature: item.feature)
    }
}

// MARK: - 表格資料源
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { results.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ResultCell
        let (item, score) = results[indexPath.row]
        let metric: Metric = (metricControl.selectedSegmentIndex == 0) ? .l2 : (metricControl.selectedSegmentIndex == 1 ? .cosine : .normL2)
        cell.configure(with: item, score: score, metric: metric)
        return cell
    }
}

// MARK: - PHPicker 代理
extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // 關閉照片挑選器
        dismiss(animated: true)

        // 確認使用者至少選到一個檔案，並且這個檔案能轉成 UIImage
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        // 嘗試把檔案轉換成 UIImage（非同步載入）
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let self, let img = obj as? UIImage else { return }

            // 回到主執行緒更新 UI
            DispatchQueue.main.async {
                // 把選取的圖片存到 currentQuery 方便之後比對
                self.currentQuery = img
                // 同時更新畫面上的預覽 ImageView
                self.queryImageView.image = img
                // 執行一次搜尋，找出相似圖片
                self.runSearchIfPossible()
            }
        }
    }
}
