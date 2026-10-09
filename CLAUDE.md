# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Kakijun - Kanji Writing Trainer

## Build & Test

```sh
# Generate Xcode project (required after changing project.yml or adding/removing files)
# WARNING: This overwrites Write.xcodeproj entirely. Never edit project settings
# in Xcode's UI — all settings must live in project.yml or they will be lost.
xcodegen generate

# Run all tests
xcodebuild test -project Write.xcodeproj -scheme Write -destination 'platform=iOS Simulator,name=iPhone 16' -resultBundlePath TestResults

# Run a single test class
xcodebuild test -project Write.xcodeproj -scheme Write -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WriteTests/StrokeValidationTests

# Preprocess KanjiVG + KANJIDIC2 data (only needed when updating the dataset)
python3 Scripts/preprocess_kanjivg.py Data/kanjivg.xml Data/kanjidic2.xml Write/Resources/kanji_strokes.json
```

Whenever `kanji_strokes.json` changes, regenerate the widget's kanji list and commit it:

```sh
python3 Scripts/build_daily_kanji.py Write/Resources/kanji_strokes.json WriteWidget/Resources/daily_kanji.json
```

## Architecture

- SwiftUI app shell with UIKit drawing views via UIViewRepresentable
- iOS 16+, Swift 6.0, XcodeGen for project generation
- SPM dependency: nicklockwood/SVGPath (1.1.4+) for parsing KanjiVG stroke paths

### Layers

1. **Engine/** - Pure geometric validation (no UI dependencies). Highly testable, 98% coverage.
   - PointSampler -> ProcrustesNormalizer -> FrechetDistance -> StrokeValidator pipeline
2. **Models/** - Codable data models and state machines (PracticeState, SessionState, NotebookState, AppSettings, PencilSettings)
3. **Services/** - KanjiDataStore loads bundled JSON, provides lookup by code point/character and search by reading/meaning
4. **Utilities/** - Standalone helpers (CatmullRomSpline, OneEuroFilter for Apple Pencil smoothing, BrushStroke, DeviceContext)
5. **Views/** - UIKit views (DrawingCanvasView, KanjiReferenceView) wrapped in SwiftUI via UIViewRepresentable
   - StrokeRenderer (in Views/) is also used by StrokeValidator to parse SVG paths and apply the KanjiVG-to-canvas scale transform; it's a shared dependency, not purely a view concern
   - **Views/iPad/** - iPad-specific views: NotebookViewController (UIKit notebook grid), iPadPracticeView, crosshair guides, notebook cells
6. **WriteWidget/** - WidgetKit extension showing a daily kanji on the Home and Lock Screen. It bundles only the generated `daily_kanji.json`, never `kanji_strokes.json` or `KanjiDataStore` (which decodes the whole dataset eagerly)
   - **Shared/** (top level) is compiled into both the app and the extension: the daily kanji model, catalog and picker, and `PracticeLink`
   - Tapping the widget opens `kakijun://practice?cp=<codePoint>`, which `ContentView` handles in `onOpenURL` on iPhone and iPad
   - On iPad the sidebar writes its selection through `ContentView.sidebarSelection`, which also clears the detail path; any other writer of the selection must set the detail path itself

### Validation pipeline

User stroke -> sample N points -> Procrustes normalize (center + scale, no rotation) -> Frechet distance against reference -> score (0-1)

Stroke identification uses centroid distance as a fast rejection filter before running the full Frechet comparison.

### KanjiVG coordinate space

KanjiVG uses a 109x109 coordinate space. StrokeRenderer applies a uniform scale transform to map this to the canvas size.

## Conventions

- One component per file
- Models are Codable structs
- PracticeState is a @MainActor ObservableObject with @Published properties
- Tests are in WriteTests/, one test file per module area
- The preprocessed kanji_strokes.json is committed; raw XML sources (Data/) are gitignored
- KanjiData has optional KANJIDIC2 fields (onYomi, kunYomi, meanings, grade, jlpt, freq) — use default nil values in tests
- AppSettings (@EnvironmentObject) holds user preferences; persisted via UserDefaults
- iPad has a separate notebook-style UI (NotebookViewController) with Apple Pencil support (OneEuroFilter for input smoothing)
- iPhone and iPad share the same Engine/Models/Services; only Views diverge
