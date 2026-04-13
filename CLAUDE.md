# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FishBuddy is an iOS app for real-time fish species identification using on-device CoreML inference (BioCLIP model) + vector similarity search against a local SQLite database (~85 MB). Recognition is fully offline after install.

**Requirements:** Xcode 15+, iOS 17+, Swift 5.9+

## Build & CI

**Local build:** Open `FishBuddy.xcodeproj` in Xcode. Before building locally, you must have the large binary assets available (they are NOT in the repo):
- `BioCLIP_iNat_Embed.mlpackage` — CoreML embedding model
- `catalog_Bio.sqlite` — Fish taxonomy + embeddings database

Both are downloaded during CI from GitHub Releases tag `v0.1.0`. To replicate locally:
```bash
gh release download v0.1.0 -R DLinZheHao/FishBuddy --pattern "*.zip" --pattern "*.sqlite"
```

**CI pipeline:** `.github/workflows/ios-ci.yml` — resolves SPM deps, downloads assets, builds for iPhone 16 Simulator, runs tests, posts status to PR head SHA.

**Running tests:**
```bash
xcodebuild test -project FishBuddy.xcodeproj -scheme FishBuddy -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

The app uses **MVVM + Coordinator** with a **hybrid UIKit/SwiftUI UI layer** and **Swift actor model** for concurrency-safe data stores.

### Recognition Pipeline
```
AVCaptureSession (CameraController)
  → CoreML inference (BioCLIPEmbeddingExtractor) → Float32[512] embedding
  → EmbeddingStore.search() [actor] → InMemoryVectorIndex (Accelerate SIMD cosine similarity)
  → FishDB.loadTaxonItems() [SQLite] → TaxonDetailView (SwiftUI)
```

- `CameraStreamVM` manages the AsyncStream of embeddings and UI state
- `EmbeddingStore` (shared actor) owns both the in-memory vector index and the SQLite reader; the index is loaded once at startup from `photo_embeddings` table
- Results are threshold-filtered and ranked; configurable threshold (0–100 scale) and gap delta

### Data Layer
Two SQLite databases:
- **`catalog_Bio.sqlite`** (read-only, bundled) — species taxonomy, photos, embeddings, distribution layers. Heavy use of JSON columns decoded via `@Default<T>` property wrapper.
- **`user.sqlite`** (app support dir, read-write) — recognition sessions, taxon view history, favorites; all access via `UserStore` actor.

### Network Layer
Moya-based singleton (`APIService.shareManager()`). All endpoints defined as enums conforming to `WeatherAPITargetType`. Uses Combine publishers (`requestDataCombine`). Base URL defaults to `http://127.0.0.1:3000`; production is `https://fishbuddy-app-api.onrender.com`.

### Navigation
- Entry point: `SceneDelegate` → `LobbyViewController` (UITabBarController)
- `AppCoordinator` handles deep links (`fishbuddy://taxon/{id}`)
- UIKit shell (Lobby, Weather) wraps SwiftUI views via `UIHostingController`

## Key Source Locations

| Concern | Path |
|---|---|
| Camera + ML inference | `FishBuddy/ImageRecognition/` |
| Vector search + DB | `FishBuddy/ImageRecognition/Persistence/` |
| User data persistence | `FishBuddy/History/Persistence/UserStore.swift` |
| Network layer | `FishBuddy/APIService/` |
| Species detail UI | `FishBuddy/Taxon/TaxonDetail/TaxonDetailView.swift` |
| User home UI | `FishBuddy/User/UserHomeView.swift` |
| Weather/tide UI | `FishBuddy/Weather/` |
| Reusable components | `FishBuddy/Componet/` |
| Codable helpers | `FishBuddy/Common/Codable/CodableExtension.swift` |
| App entry & coordinator | `FishBuddy/AppDelegate.swift`, `FishBuddy/AppCoordinator.swift` |

## SPM Dependencies

- **Moya** — HTTP networking
- **SQLite.swift** — SQLite ORM
- **Kingfisher** — Remote image loading/caching
- **Toast-Swift** — Toast notifications
- **FoundationModels** — Apple Intelligence API (iOS 26+ only; gracefully degraded otherwise)

## Important Patterns

**`@Default<T>` property wrapper** (`Common/Codable/CodableExtension.swift`): used throughout `TaxonItem` to provide fallback values when JSON fields are missing or mistyped. Add this to any new Codable model fields that may be absent in API responses.

**Actor-based stores**: `EmbeddingStore` and `UserStore` are Swift actors accessed via `.shared`. All mutations and reads go through `await` — never access their internals directly.

**JSON column decoding**: Species data is stored as JSON blobs in SQLite. `FishDB` decodes these via `JSONDecoder` into nested `TaxonItem` structs. When adding new species fields, update both the SQLite query and the corresponding `Codable` struct.

**FoundationModels (AI summary)**: `SpeciesDigestGenerator` requires iOS 26.0+ and Apple Intelligence enabled. Always guard with availability checks; the rest of the app must function without it.
