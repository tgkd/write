---

# iOS Kanji Writing Trainer

## Overview

Build an iOS kanji writing trainer in Swift using KanjiVG stroke vector data, a custom touch-tracking canvas, and geometric stroke validation (Frechet distance + Procrustes analysis). Three practice modes (Trace, Stroke-by-stroke reveal, Free draw) share a single validation engine. The app targets joyo kanji with KANJIDIC2 metadata for progression.

## Context

- Files involved: Greenfield project - all files are new
- Data sources: KanjiVG (stroke SVGs, CC BY-SA 3.0), KANJIDIC2 (metadata, CC BY-SA 4.0)
- Dependencies: nicklockwood/SVGPath (MIT, SPM) for SVG path parsing
- Related patterns: HanziWriter's curve-matcher algorithm (Frechet + Procrustes) as validation reference
- Architecture: SwiftUI app shell with UIKit drawing views (CAShapeLayer + custom touch tracking via UIViewRepresentable)

## Development Approach

- **Testing approach**: TDD for the geometric validation engine (pure math, highly testable); regular for UI layers
- Complete each task fully before moving to the next
- Each task builds on the previous - the dependency chain is strictly linear
- **CRITICAL: every task MUST include new/updated tests**
- **CRITICAL: all tests must pass before starting next task**

## Implementation Steps

### Task 1: Project scaffolding and KanjiVG data pipeline

**Files:**
- Create: Xcode project (Write.xcodeproj or similar)
- Create: `Scripts/preprocess_kanjivg.swift` - build-time script to convert KanjiVG SVGs to bundled JSON
- Create: `Models/KanjiStroke.swift` - stroke data model
- Create: `Models/KanjiData.swift` - full kanji data model (strokes + metadata)
- Create: `Services/KanjiDataStore.swift` - loads and queries bundled kanji data
- Bundled: `Resources/kanji_strokes.json` - preprocessed KanjiVG data

- [x] Create new Xcode project (iOS App, SwiftUI lifecycle, minimum deployment iOS 16)
- [x] Add nicklockwood/SVGPath as SPM dependency
- [x] Download KanjiVG dataset and add to project as raw resource (or git submodule)
- [x] Write preprocessing script: parse KanjiVG XML files, strip DOCTYPE, extract stroke paths (d attribute), stroke IDs, kvg:type, and component hierarchy (kvg:element, kvg:position, kvg:radical) per kanji
- [x] Output preprocessed data as JSON keyed by Unicode code point (e.g., "4eee" -> {element, strokes: [{strokeNumber, pathData, strokeType}], components: [{element, position, strokes}]})
- [x] Create KanjiStroke and KanjiData Swift models with Codable conformance
- [x] Create KanjiDataStore that loads the bundled JSON and provides lookup by Unicode code point and by character
- [x] Write tests: preprocessing output correctness for a known kanji (e.g., 仮), KanjiDataStore lookup, stroke ordering
- [x] Run project test suite - must pass before task 2

### Task 2: Stroke rendering and animation

**Files:**
- Create: `Views/StrokeRenderer.swift` - CAShapeLayer-based stroke rendering
- Create: `Views/KanjiReferenceView.swift` - UIView that displays ghost strokes for a kanji

- [x] Create StrokeRenderer: converts SVGPath-parsed CGPaths to CAShapeLayers, applies uniform scale transform from 109x109 KanjiVG coordinate space to canvas size
- [x] Implement ghost stroke rendering: configurable stroke color, alpha, and line width per stroke
- [x] Implement stroke-drawing animation using CABasicAnimation on strokeEnd (0 to 1), with configurable duration and sequential chaining via beginTime offsets
- [x] Create KanjiReferenceView (UIView) that takes a KanjiData and renders all strokes as ghost CAShapeLayers
- [x] Support per-stroke visibility control (show/hide/highlight individual strokes) and color changes (gray -> green for accepted, red flash for rejected)
- [x] Write tests: scale transform correctness (109 -> canvas size), stroke count matches KanjiData, animation parameters
- [x] Run project test suite - must pass before task 3

### Task 3: Drawing canvas with touch tracking and curve smoothing

**Files:**
- Create: `Views/DrawingCanvasView.swift` - custom UIView for touch-based stroke input
- Create: `Utilities/CatmullRomSpline.swift` - centripetal Catmull-Rom interpolation
- Create: `Views/DrawingCanvasRepresentable.swift` - UIViewRepresentable wrapper

- [x] Create DrawingCanvasView (UIView) with touchesBegan/touchesMoved/touchesEnded capturing CGPoint sequences per stroke
- [x] Expose callbacks: onPointAdded (real-time during drawing), onStrokeCompleted (after touchesEnded)
- [x] Render user strokes as CAShapeLayers with configurable stroke color and width
- [x] Implement centripetal Catmull-Rom spline interpolation (alpha 0.5) to smooth raw touch points into clean curves
- [x] Support clearing individual strokes or all strokes
- [x] Create UIViewRepresentable wrapper for use in SwiftUI
- [x] Write tests: point capture accuracy, Catmull-Rom output passes through original control points, stroke count tracking
- [x] Run project test suite - must pass before task 4

### Task 4: Stroke validation engine (Frechet distance + Procrustes analysis)

**Files:**
- Create: `Engine/PointSampler.swift` - sample N equally-spaced points along a CGPath or point array
- Create: `Engine/ProcrustesNormalizer.swift` - translate to origin, normalize scale, optimal rotation
- Create: `Engine/FrechetDistance.swift` - discrete Frechet distance computation
- Create: `Engine/StrokeValidator.swift` - orchestrates sampling, normalization, comparison, and scoring

- [ ] Implement point sampling: walk along a CGPath (reference strokes) or point array (user strokes) and emit N equally-spaced points (default N=50)
- [ ] Implement Procrustes normalization: translate curve centroid to origin, scale to unit size, try multiple rotations to find optimal alignment
- [ ] Implement discrete Frechet distance between two normalized point sequences (respects curve direction - backwards strokes score poorly)
- [ ] Create StrokeValidator that orchestrates the pipeline: sample -> normalize -> compare -> score (0-1 similarity)
- [ ] Implement stroke identification: given a user stroke and list of unmatched reference strokes, find the best match using centroid distance as fast rejection filter then Frechet comparison
- [ ] Implement stroke order validation: check if matched stroke number equals expected next stroke number
- [ ] Configurable thresholds: leniency multiplier (default 1.0), shape similarity threshold (~0.3-0.4), direction tolerance, centroid position tolerance (~30% of canvas)
- [ ] Write comprehensive tests: known stroke pairs with expected scores, backwards stroke scores lower than forward, correct stroke identification among candidates, threshold edge cases, Procrustes invariance to translation/scale/rotation
- [ ] Run project test suite - must pass before task 5

### Task 5: Three practice modes and kanji selection UI

**Files:**
- Create: `Views/PracticeView.swift` - SwiftUI view composing reference + canvas + feedback layers
- Create: `Views/FeedbackOverlayView.swift` - visual feedback for validation results
- Create: `Models/PracticeMode.swift` - enum/config for mode-specific behavior
- Create: `Models/PracticeState.swift` - state machine for stroke progression
- Create: `Views/KanjiPickerView.swift` - simple kanji selection grid
- Create: `Views/ContentView.swift` - root navigation

- [ ] Create PracticeState: state machine tracking stroke progression (waitingForInput -> userDrawing -> validating -> strokeAccepted/strokeRejected -> waitingForInput), current stroke index, attempt count
- [ ] Create FeedbackOverlayView: green rendering for accepted strokes, red flash + clear for rejected strokes
- [ ] Create PracticeMode enum with three cases, each configuring ghost stroke visibility, validation timing, and feedback behavior
- [ ] Mode A (Trace): all ghost strokes visible at alpha 0.3, current expected stroke at alpha 0.5, per-stroke validation on completion
- [ ] Mode B (Stroke-by-stroke): only next expected ghost stroke visible, animated in via strokeEnd, auto-hint after N consecutive misses (default 3)
- [ ] Mode C (Free draw): no ghost strokes, per-stroke sequential matching with bounding-box normalization
- [ ] Create PracticeView (SwiftUI): compose KanjiReferenceView + DrawingCanvasView + FeedbackOverlayView via UIViewRepresentable, wire up validation callbacks, mode selector
- [ ] Create KanjiPickerView: grid of kanji characters, tapping one navigates to PracticeView
- [ ] Create root ContentView with navigation from picker to practice
- [ ] Write tests: state machine transitions, mode-specific ghost visibility configuration, stroke acceptance/rejection flow
- [ ] Run project test suite - must pass before task 6

### Task 6: Verify acceptance criteria

- [ ] Manual test: select a kanji from the picker, draw it in Trace mode, verify ghost strokes visible and stroke validation works (green for correct, red flash for incorrect)
- [ ] Manual test: Stroke-by-stroke mode reveals one stroke at a time, auto-hint triggers after 3 misses
- [ ] Manual test: Free draw mode shows no ghosts, validates each stroke against expected order
- [ ] Run full test suite
- [ ] Run linter (swiftlint if configured)
- [ ] Verify test coverage meets 80%+ for Engine/ (validation core)

### Task 7: Update documentation

- [ ] Update README.md with project overview, setup instructions (how to preprocess KanjiVG data), and build instructions
- [ ] Add CLAUDE.md with project conventions, architecture overview, and key patterns
- [ ] Move this plan to `docs/plans/completed/`
