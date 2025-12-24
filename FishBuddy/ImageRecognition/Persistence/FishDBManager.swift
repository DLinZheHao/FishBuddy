//
//  FishDBManager.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/9/5.
//

import SQLite
import Foundation
import Accelerate

final class FishDB {
    /// SQLite.swift connection
    private let db: Connection

    ///
    var decoder = JSONDecoder()
    
    /// If this is a brand-new DB (no required tables), run DDL to create schema.
    private func bootstrapIfEmpty() throws {
        let sql = createRequiredTables()

        // Count required tables in the database
        let count = try db.scalar(sql) as! Int64

        // If the tables do not exist, use schemaDDL to create them
        if count == 0 {
            // SQLite.swift `db.run` does not support executing multiple statements at once; execute one-by-one.
            let statements = createSchemaDDL()
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for sql in statements {
                try db.run(sql)
            }

            let newCount = try db.scalar(sql) as! Int64
            print("✅ 已執行 bootstrap DDL，建表完成（表數=\(newCount)）")
        }
    }

    /// SQL string to get tables count
    private func createRequiredTables() -> String {
        let requiredTables = [
            "species",
            "raw_species_json",
            "photos",
            "wiki_photos",
            "distribution_layers",
            "photo_embeddings"
        ]

        let tableList = requiredTables
            .map { "'\($0)'" }
            .joined(separator: ",")

        let sql = """
        SELECT COUNT(*)
        FROM sqlite_master
        WHERE type = 'table'
          AND name IN (\(tableList));
        """

        return sql
    }

    /// Generate schema DDL for required tables
    private func createSchemaDDL() -> String {
        // SQL statements to execute (in order)
        var statements: [String] = []

        // WAL
        statements.append("PRAGMA journal_mode=WAL;")

        // Sync policy (performance/safety tradeoff)
        statements.append("PRAGMA synchronous=NORMAL;")

        // Foreign keys
        statements.append("PRAGMA foreign_keys=ON;")

        // Begin transaction
        statements.append("BEGIN IMMEDIATE;")

        // 1) species
        let speciesTableSQL = """
        CREATE TABLE IF NOT EXISTS species (
          taxon_id            INTEGER PRIMARY KEY,
          scientific_name     TEXT NOT NULL,
          common_name_zh      TEXT,
          common_name_en_json TEXT,
          taxonomy_json       TEXT,
          basic_info_json     TEXT,
          morphology_json     TEXT,
          diet_and_behavior_json TEXT,
          ecology_and_behavior_json TEXT,
          habitat_and_distribution_json TEXT,
          environment_and_depth_json TEXT,
          reproduction_json   TEXT,
          growth_and_life_history_json TEXT,
          conservation_and_human_uses_json TEXT,
          benefits_and_uses_json TEXT,
          taiwan_and_regional_notes_json TEXT,
          distribution_json   TEXT,
          embedding_meta_json TEXT
        );
        """
        statements.append(speciesTableSQL)

        // 2) raw_species_json (store the full raw JSON without losing any fields)
        let rawSpeciesTableSQL = """
        CREATE TABLE IF NOT EXISTS raw_species_json (
          taxon_id  INTEGER PRIMARY KEY,
          raw_json  TEXT NOT NULL,
          FOREIGN KEY (taxon_id) REFERENCES species(taxon_id) ON DELETE CASCADE
        );
        """
        statements.append(rawSpeciesTableSQL)

        // 3) photos
        let photosTableSQL = """
        CREATE TABLE IF NOT EXISTS photos (
          taxon_id      INTEGER NOT NULL,
          idx           INTEGER NOT NULL,
          url           TEXT NOT NULL,
          license_code  TEXT,
          attribution   TEXT,
          source        TEXT,
          PRIMARY KEY (taxon_id, idx),
          FOREIGN KEY (taxon_id) REFERENCES species(taxon_id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_photos_taxon ON photos(taxon_id);
        CREATE INDEX IF NOT EXISTS idx_photos_url   ON photos(url);
        """
        statements.append(photosTableSQL)

        // 4) wiki_photos
        let wikiPhotosTableSQL = """
        CREATE TABLE IF NOT EXISTS wiki_photos (
          taxon_id          INTEGER NOT NULL,
          idx               INTEGER NOT NULL,
          url               TEXT NOT NULL,
          license_code      TEXT,
          license           TEXT,
          source            TEXT,
          attribution_html  TEXT,
          PRIMARY KEY (taxon_id, idx),
          FOREIGN KEY (taxon_id) REFERENCES species(taxon_id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_wiki_photos_taxon ON wiki_photos(taxon_id);
        CREATE INDEX IF NOT EXISTS idx_wiki_photos_url   ON wiki_photos(url);
        """
        statements.append(wikiPhotosTableSQL)

        // 5) distribution_layers
        let distributionLayersTableSQL = """
        CREATE TABLE IF NOT EXISTS distribution_layers (
          taxon_id  INTEGER NOT NULL,
          idx       INTEGER NOT NULL,
          layer_key TEXT NOT NULL,
          type      TEXT,
          url       TEXT,
          minzoom   INTEGER,
          maxzoom   INTEGER,
          PRIMARY KEY (taxon_id, idx),
          FOREIGN KEY (taxon_id) REFERENCES species(taxon_id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_layers_taxon ON distribution_layers(taxon_id);
        CREATE INDEX IF NOT EXISTS idx_layers_key   ON distribution_layers(layer_key);
        """
        statements.append(distributionLayersTableSQL)

        // 6) photo_embeddings
        let photoEmbeddingsTableSQL = """
        CREATE TABLE IF NOT EXISTS photo_embeddings (
          taxon_id     INTEGER NOT NULL,
          idx          INTEGER NOT NULL,
          dtype        TEXT NOT NULL,
          vector_blob  BLOB NOT NULL,
          PRIMARY KEY (taxon_id, idx),
          FOREIGN KEY (taxon_id) REFERENCES species(taxon_id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_pe_taxon ON photo_embeddings(taxon_id);
        """
        statements.append(photoEmbeddingsTableSQL)

        // Commit transaction
        statements.append("COMMIT;")

        return statements.joined(separator: "\n")
    }

    /// Initializes FishDB and ensures the database file and required schema exist.
    init(path: String) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            print("⚠️ 指定路徑尚無 DB 檔，將建立空白資料庫並以 DDL 建立 schema: \(path)")
        }
        db = try Connection(path)
        try bootstrapIfEmpty()
    }

    // MARK: - Float array <-> Data(BLOB)

    /// [Float32] -> SQLite.Blob
    private func floatsToBlob(_ v: [Float32]) -> SQLite.Blob {
        v.withUnsafeBufferPointer { buf in
            let raw = UnsafeRawBufferPointer(buf)
            return SQLite.Blob(bytes: Array(raw))
        }
    }

    /// SQLite.Blob -> [Float32]
    private func blobToFloats(_ b: SQLite.Blob) -> [Float32] {
        b.bytes.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
    }

    /// A single photo embedding row (matches `photo_embeddings` schema).
    struct PhotoEmbeddingLite: Sendable {
        let idx: Int
        let vector: [Float]
    }

    /// Load ALL photo embeddings from `photo_embeddings`.
    /// - Returns: Map of `taxon_id -> [(idx, vector)]`.
    func loadAllEmbeddings() throws -> [Int: [PhotoEmbeddingLite]] {
        let peT = Table("photo_embeddings")
        let pe_taxon = SQLite.Expression<Int>("taxon_id")
        let pe_idx   = SQLite.Expression<Int>("idx")
        let pe_blob  = SQLite.Expression<SQLite.Blob>("vector_blob")

        var out: [Int: [PhotoEmbeddingLite]] = [:]

        let q = peT
            .select(pe_taxon, pe_idx, pe_blob)
            .order(pe_taxon.asc, pe_idx.asc)

        for r in try db.prepare(q) {
            let tid = r[pe_taxon]
            let idx = r[pe_idx]

            // Stored as raw Float32 bytes
            let vec32: [Float32] = blobToFloats(r[pe_blob])
            let vec = vec32.map { Float($0) }

            out[tid, default: []].append(PhotoEmbeddingLite(idx: idx, vector: vec))
        }

        return out
    }
}

extension FishDB {

    func loadTaxonItems(taxonIds: [Int]) throws -> [TaxonItem] {
        guard !taxonIds.isEmpty else { return [] }

        // ---- species ----
        let sT = Table("species")
        let s_taxon = SQLite.Expression<Int>("taxon_id")
        let s_scientific = SQLite.Expression<String>("scientific_name")
        let s_commonZh = SQLite.Expression<String?>("common_name_zh")

        let s_taxonomy = SQLite.Expression<String?>("taxonomy_json")
        let s_basic = SQLite.Expression<String?>("basic_info_json")
        let s_morph = SQLite.Expression<String?>("morphology_json")
        let s_diet = SQLite.Expression<String?>("diet_and_behavior_json")
        let s_ecology = SQLite.Expression<String?>("ecology_and_behavior_json")
        let s_habitat = SQLite.Expression<String?>("habitat_and_distribution_json")
        let s_envDepth = SQLite.Expression<String?>("environment_and_depth_json")
        let s_repro = SQLite.Expression<String?>("reproduction_json")
        let s_growth = SQLite.Expression<String?>("growth_and_life_history_json")
        let s_conservation = SQLite.Expression<String?>("conservation_and_human_uses_json")
        let s_benefits = SQLite.Expression<String?>("benefits_and_uses_json")
        let s_taiwanNotes = SQLite.Expression<String?>("taiwan_and_regional_notes_json")
        let s_distribution = SQLite.Expression<String?>("distribution_json")
        let s_embeddingMeta = SQLite.Expression<String?>("embedding_meta_json")

        var out: [Int: TaxonItem] = [:]

        for r in try db.prepare(sT.filter(taxonIds.contains(s_taxon))) {
            let tid = r[s_taxon]

            // JSON decode（有值才 decode；格式壞就 throw，方便你抓資料問題）
            let taxonomy = try JSONHelper.decode(r[s_taxonomy], as: Taxonomy.self, decoder: decoder)
            let basicInfo = try JSONHelper.decode(r[s_basic], as: BasicInfo.self, decoder: decoder)
            let morphology = try JSONHelper.decode(r[s_morph], as: Morphology.self, decoder: decoder)
            let dietAndBehavior = try JSONHelper.decode(r[s_diet], as: DietAndBehavior.self, decoder: decoder)
            let ecologyAndBehavior = try JSONHelper.decode(r[s_ecology], as: EcologyAndBehavior.self, decoder: decoder)
            let habitatAndDistribution = try JSONHelper.decode(r[s_habitat], as: HabitatAndDistribution.self, decoder: decoder)
            let environmentAndDepth = try JSONHelper.decode(r[s_envDepth], as: EnvironmentAndDepth.self, decoder: decoder)
            let reproduction = try JSONHelper.decode(r[s_repro], as: Reproduction.self, decoder: decoder)
            let growthAndLifeHistory = try JSONHelper.decode(r[s_growth], as: GrowthAndLifeHistory.self, decoder: decoder)
            let conservationAndHumanUses = try JSONHelper.decode(r[s_conservation], as: ConservationAndHumanUses.self, decoder: decoder)
            let benefitsAndUses = try JSONHelper.decode(r[s_benefits], as: BenefitsAndUses.self, decoder: decoder)
            let taiwanAndRegionalNotes = try JSONHelper.decode(r[s_taiwanNotes], as: TaiwanAndRegionalNotes.self, decoder: decoder)
            let distribution = try JSONHelper.decode(r[s_distribution], as: Distribution.self, decoder: decoder)
            let embeddingMeta = try JSONHelper.decode(r[s_embeddingMeta], as: EmbeddingMeta.self, decoder: decoder)

            // 組 TaxonItem（photos/wiki/layers 先空，後面 fan-out 再塞）
            let item = TaxonItem(
                taxonId: tid,
                scientificName: r[s_scientific],
                commonNameZh: r[s_commonZh],
                taxonomy: taxonomy,
                basicInfo: basicInfo,
                morphology: morphology,
                dietAndBehavior: dietAndBehavior,
                ecologyAndBehavior: ecologyAndBehavior,
                habitatAndDistribution: habitatAndDistribution,
                environmentAndDepth: environmentAndDepth,
                reproduction: reproduction,
                conservationAndHumanUses: conservationAndHumanUses,
                benefitsAndUses: benefitsAndUses,
                taiwanAndRegionalNotesJSON: taiwanAndRegionalNotes,
                distribution: distribution,
                embeddingMeta: embeddingMeta,
                growthAndLifeHistory: growthAndLifeHistory,
                photos: [],
                wikiPhotos: [],
                distributionLayers: []
            )

            out[tid] = item
        }

        if out.isEmpty { return [] }

        // ---- photos ----
        let pT = Table("photos")
        let p_taxon = SQLite.Expression<Int>("taxon_id")
        let p_idx = SQLite.Expression<Int>("idx")
        let p_url = SQLite.Expression<String>("url")
        let p_license = SQLite.Expression<String?>("license_code")
        let p_attr = SQLite.Expression<String?>("attribution")
        let p_source = SQLite.Expression<String?>("source")

        for r in try db.prepare(pT.filter(taxonIds.contains(p_taxon)).order(p_taxon.asc, p_idx.asc)) {
            let tid = r[p_taxon]
            guard var t = out[tid] else { continue }
            t.photos.append(.init(
                idx: r[p_idx],
                url: r[p_url],
                licenseCode: r[p_license],
                attribution: r[p_attr],
                source: r[p_source]
            ))
            out[tid] = t
        }

        // ---- wiki_photos ----
        let wT = Table("wiki_photos")
        let w_taxon = SQLite.Expression<Int>("taxon_id")
        let w_idx = SQLite.Expression<Int>("idx")
        let w_url = SQLite.Expression<String>("url")
        let w_licenseCode = SQLite.Expression<String?>("license_code")
        let w_license = SQLite.Expression<String?>("license")
        let w_source = SQLite.Expression<String?>("source")
        let w_attrHTML = SQLite.Expression<String?>("attribution_html")

        for r in try db.prepare(wT.filter(taxonIds.contains(w_taxon)).order(w_taxon.asc, w_idx.asc)) {
            let tid = r[w_taxon]
            guard var t = out[tid] else { continue }
            t.wikiPhotos.append(.init(
                idx: r[w_idx],
                url: r[w_url],
                licenseCode: r[w_licenseCode],
                license: r[w_license],
                source: r[w_source],
                attributionHTML: r[w_attrHTML]
            ))
            out[tid] = t
        }

        // ---- distribution_layers ----
        let dT = Table("distribution_layers")
        let d_taxon = SQLite.Expression<Int>("taxon_id")
        let d_idx = SQLite.Expression<Int>("idx")
        let d_key = SQLite.Expression<String>("layer_key")
        let d_type = SQLite.Expression<String?>("type")
        let d_url = SQLite.Expression<String?>("url")
        let d_min = SQLite.Expression<Int?>("minzoom")
        let d_max = SQLite.Expression<Int?>("maxzoom")

        for r in try db.prepare(dT.filter(taxonIds.contains(d_taxon)).order(d_taxon.asc, d_idx.asc)) {
            let tid = r[d_taxon]
            guard var t = out[tid] else { continue }
            t.distributionLayers.append(.init(
                idx: r[d_idx],
                layerKey: r[d_key],
                type: r[d_type],
                url: r[d_url],
                minZoom: r[d_min],
                maxZoom: r[d_max]
            ))
            out[tid] = t
        }

        return taxonIds.compactMap { out[$0] }
    }
}

/// Dense in-memory index for fast similarity search.
///
/// Design notes:
/// - We keep ALL vectors packed in one contiguous `matrix` (row-major) to maximize cache locality.
/// - Query uses `vDSP_mmul` (GEMV) to compute N dot-products efficiently.
/// - We do NOT keep species/photo metadata here; only `(taxonId, photoIdx)` keys.
final class InMemoryVectorIndex {
    /// Identifies exactly which embedding row matched.
    /// - `taxonId`: species primary key
    /// - `photoIdx`: photo/embedding index (matches `photos.idx` and `photo_embeddings.idx`)
    struct EmbeddingKey: Hashable, Sendable {
        let taxonId: Int
        let photoIdx: Int
    }

    /// Vector dimension (D)
    let dim: Int

    /// Row keys aligned with `matrix` rows.
    /// `keys[i]` corresponds to the i-th row in `matrix`.
    private(set) var keys: [EmbeddingKey] = []

    /// Packed row-major matrix (N × D) stored in a single contiguous buffer.
    private(set) var matrix: [Float] = []

    /// Create an index by packing all photo embeddings into a contiguous matrix.
    /// - Important: For cosine similarity, both stored vectors and `query` should be L2-normalized.
    /// - Ordering: deterministic (taxonId asc, photoIdx asc) for stable results.
    init(embeddingsByTaxonId: [Int: [FishDB.PhotoEmbeddingLite]], dim: Int) {
        self.dim = dim

        // Flatten to a deterministic row list: (key, vector)
        var rows: [(EmbeddingKey, [Float])] = []
        rows.reserveCapacity(embeddingsByTaxonId.values.reduce(0) { $0 + $1.count })

        for taxonId in embeddingsByTaxonId.keys.sorted() {
            guard let list = embeddingsByTaxonId[taxonId] else { continue }
            for e in list.sorted(by: { $0.idx < $1.idx }) {
                rows.append((EmbeddingKey(taxonId: taxonId, photoIdx: e.idx), e.vector))
            }
        }

        self.keys = rows.map { $0.0 }
        self.matrix = [Float](repeating: 0, count: rows.count * dim)

        // Pack vectors into row-major matrix.
        for (i, row) in rows.enumerated() {
            let v = row.1
            precondition(v.count == dim,
                         "Embedding dimension mismatch: expected=\(dim), actual=\(v.count), key=\(row.0)")
            matrix.replaceSubrange(i * dim..<(i + 1) * dim, with: v)
        }
    }

    /// Search top-K by cosine (dot product) similarity.
    /// - If all vectors are L2-normalized, dot product == cosine similarity.
    /// - Returns: top-K `(EmbeddingKey, score)` pairs where score is mapped to 0~100.
    func search(query: [Float], topK: Int) -> [(key: EmbeddingKey, score: Float)] {
        precondition(query.count == dim, "Query dimension mismatch: expected=\(dim), actual=\(query.count)")
        let n = keys.count
        guard n > 0, topK > 0 else { return [] }

        // scores = matrix(N×D) × query(D×1) => N scores
        var scores = [Float](repeating: 0, count: n)
        var q = query
        vDSP_mmul(matrix, 1, &q, 1, &scores, 1, vDSP_Length(n), 1, vDSP_Length(dim))

        // Convert cosine similarity to a UI-friendly score.
        // Cosine similarity is in [-1, 1] (math space):
        //   -1 = opposite direction (very dissimilar)
        //    0 = orthogonal (unrelated)
        //    1 = same direction (most similar)
        //
        // For UI, we linearly map it to [0, 100]:
        //   score = (cosine + 1) * 50
        // So:
        //   -1 -> 0, 0 -> 50, 1 -> 100
        //
        // Clamp is applied to guard against floating-point drift.
        for i in 0..<scores.count {
            let clamped = max(-1, min(1, scores[i]))
            scores[i] = (clamped + 1) * 50
        }

        let k = min(topK, n)
        let idxs = (0..<n).sorted { scores[$0] > scores[$1] }.prefix(k)
        return idxs.map { (keys[$0], scores[$0]) }
    }
}

/*
設計補充：
- Cosine 與內積：若每個向量都做 L2 normalize（‖v‖=1），cosine(v,q)=v·q，
  因此可以直接用矩陣乘法拿到 cosine 分數；若只對 query 正規化，分數會受每列向量的長度影響。
- 為什麼一次做矩陣×向量（GEMV）比逐列 dot product 快：
  1) 連續記憶體存取可大幅提高 cache 命中率
  2) vDSP/BLAS 會用 SIMD 指令（例如單指令多資料）與最佳化迴圈展開
  3) 可能利用多核心把工作拆段並行
- 後續擴展：
  - 若 N 很大且記憶體吃緊，可考慮分塊（blocking）或改為磁碟／記憶體對映（mmap）。
  - 需要更快的近似最近鄰（ANN）時，再引入 HNSW/IVF/PQ 等索引；但在 N 中小時，密集 GEMV 常常已足夠且最簡單。
*/

/*
做什麼：
1) 把 N 條「魚的向量」排成一個連續的大表格（N×D），攤平成一條 [Float]。
2) 查詢時，一次做 matrix × query（矩陣×向量），得到每條魚的相似度分數。
3) 依分數挑出前 K 名，回傳 (taxonId, photoIdx, score)。
為什麼這樣做比較快：
- 連續記憶體：把資料攤平 → CPU 讀取連續、快取命中高，比 [[Float]] 這種多層陣列更有效率。
- 一次算完：用 vDSP_mmul（底層 BLAS/SIMD/可能多核心）做 GEMV，比逐筆 for 迴圈做 dot product 快很多。
- L2 normalize 後：cosine(v,q) == v·q（內積），所以直接用「矩陣×向量」就能拿到所有 cosine 分數。
*/
