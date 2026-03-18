# Write - iOS Kanji Writing Trainer

An iOS app for practicing kanji handwriting using stroke-level validation. The app uses KanjiVG vector data and geometric analysis (Frechet distance + Procrustes alignment) to verify each stroke as you draw.

## Features

- Three practice modes:
  - **Trace** - all ghost strokes visible, draw over them with per-stroke validation
  - **Guided** - only the next expected stroke is shown, auto-hint after 3 misses
  - **Free** - no guides, validates stroke shape from memory (any stroke order accepted)
- Real-time stroke validation using discrete Frechet distance and Procrustes normalization
- Catmull-Rom spline smoothing for natural-feeling input
- KanjiVG-based stroke data for CJK Unified Ideographs

## Requirements

- Xcode 16.3+
- iOS 16.0+
- Swift 6.0
- Python 3 (for preprocessing)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

### 1. Download KanjiVG data

Download the KanjiVG combined XML file and place it at `Data/kanjivg.xml`:

```sh
mkdir -p Data
curl -L "https://github.com/KanjiVG/kanjivg/releases/latest/download/kanjivg-20240807.xml.gz" | gunzip > Data/kanjivg.xml
```

### 2. Preprocess stroke data

Convert the raw XML into the bundled JSON format:

```sh
python3 Scripts/preprocess_kanjivg.py Data/kanjivg.xml Write/Resources/kanji_strokes.json
```

This produces `Write/Resources/kanji_strokes.json`, which is committed to the repo. You only need to re-run this if updating the KanjiVG dataset.

### 3. Generate Xcode project

```sh
xcodegen generate
```

### 4. Build and run

Open `Write.xcodeproj` in Xcode, select an iOS simulator, and run.

## Running tests

```sh
xcodegen generate
xcodebuild test \
  -project Write.xcodeproj \
  -scheme Write \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath TestResults
```

## Project structure

```
Write/
  App/            App entry point (WriteApp, ContentView)
  Engine/         Stroke validation core
    PointSampler          Sample equally-spaced points along paths
    ProcrustesNormalizer  Translate, scale, and rotate curves for comparison
    FrechetDistance        Discrete Frechet distance computation
    StrokeValidator       Orchestrates the validation pipeline
  Models/         Data models
    KanjiStroke           Single stroke (path data, type, number)
    KanjiData             Full kanji (strokes + components)
    PracticeMode          Three mode configurations
    PracticeState         State machine for stroke progression
  Services/       Data loading
    KanjiDataStore        Loads and queries bundled kanji JSON
  Utilities/      Helpers
    CatmullRomSpline      Centripetal Catmull-Rom curve smoothing
  Views/          UI layer
    StrokeRenderer              CAShapeLayer-based stroke rendering
    KanjiReferenceView          Ghost stroke display (UIView)
    DrawingCanvasView           Touch-tracking canvas (UIView)
    DrawingCanvasRepresentable  SwiftUI wrapper for DrawingCanvasView
    FeedbackOverlayView         Green/red stroke feedback
    KanjiPickerView             Kanji selection grid
    PracticeView                Main practice screen
  Resources/
    kanji_strokes.json    Preprocessed KanjiVG data

Scripts/
  preprocess_kanjivg.py   Python preprocessing script
  preprocess_kanjivg.swift Swift preprocessing script

WriteTests/               Unit tests (139 tests, 98% Engine coverage)
```

## Data sources

- [KanjiVG](https://kanjivg.tagaini.net/) - Stroke vector data (CC BY-SA 3.0)
- SVG path parsing via [nicklockwood/SVGPath](https://github.com/nicklockwood/SVGPath) (MIT)

## License

KanjiVG data is licensed under CC BY-SA 3.0. See the KanjiVG project for details.
