# Write - Kanji Writing Trainer

## Build & Test

```sh
# Generate Xcode project (required after changing project.yml or adding/removing files)
xcodegen generate

# Run all tests
xcodebuild test -project Write.xcodeproj -scheme Write -destination 'platform=iOS Simulator,name=iPhone 16' -resultBundlePath TestResults

# Run a single test class
xcodebuild test -project Write.xcodeproj -scheme Write -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WriteTests/StrokeValidationTests

# Preprocess KanjiVG data (only needed when updating the dataset)
python3 Scripts/preprocess_kanjivg.py Data/kanjivg.xml Write/Resources/kanji_strokes.json
```

## Architecture

- SwiftUI app shell with UIKit drawing views via UIViewRepresentable
- iOS 16+, Swift 6.0, XcodeGen for project generation
- SPM dependency: nicklockwood/SVGPath (1.1.4+) for parsing KanjiVG stroke paths

### Layers

1. **Engine/** - Pure geometric validation (no UI dependencies). Highly testable, 98% coverage.
   - PointSampler -> ProcrustesNormalizer -> FrechetDistance -> StrokeValidator pipeline
2. **Models/** - Codable data models and state machines
3. **Services/** - KanjiDataStore loads bundled JSON, provides lookup by code point or character
4. **Views/** - UIKit views (DrawingCanvasView, KanjiReferenceView) wrapped in SwiftUI via UIViewRepresentable

### Validation pipeline

User stroke -> sample N points -> Procrustes normalize -> Frechet distance against reference -> score (0-1)

Stroke identification uses centroid distance as a fast rejection filter before running the full Frechet comparison.

### KanjiVG coordinate space

KanjiVG uses a 109x109 coordinate space. StrokeRenderer applies a uniform scale transform to map this to the canvas size.

## Conventions

- One component per file
- Models are Codable structs
- PracticeState is an ObservableObject with @Published properties
- Tests are in WriteTests/, one test file per module area
- The preprocessed kanji_strokes.json is committed; raw KanjiVG XML (Data/) is gitignored
