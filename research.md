# Building an iOS kanji writing trainer in Swift

**KanjiVG provides the best stroke vector data for all 2,136 jōyō kanji, parseable natively via the nicklockwood/SVGPath library into CAShapeLayer paths, while the HanziWriter algorithm (Fréchet distance + Procrustes analysis) offers a battle-tested stroke validation approach portable to Swift in roughly 200 lines of core code.** No fully featured open-source iOS kanji writing app exists in Swift today — this is a clear gap. The recommended architecture layers a custom touch-tracking drawing canvas over CAShapeLayer ghost strokes, using KanjiVG's hierarchical SVG data as the single source of truth for stroke order, shape, and component decomposition. What follows is a complete technical blueprint covering data sources, parsing, recognition, drawing APIs, and three practice modes.

---

## KanjiVG is the only viable stroke data source

**KanjiVG** (CC BY-SA 3.0) covers all jōyō kanji plus JIS Level 1 and 2 characters — roughly **6,000+ kanji total** — with each character stored as an individual SVG file named by its zero-padded hexadecimal Unicode code point (e.g., `04eee.svg` for 仮). The 109×109 pixel viewBox contains two root groups: `StrokePaths` (hierarchical stroke data) and `StrokeNumbers` (positioned text labels).

Each stroke is a `<path>` element using **exclusively cubic Bézier commands** — `M`/`m` (moveTo), `C`/`c` (curveTo), and `S`/`s` (smooth curveTo). No quadratic curves, arcs, or line commands appear anywhere in the dataset. Stroke IDs follow the pattern `kvg:{hex}-s{n}` where n is the 1-based stroke order number. Groups nest hierarchically to reflect kanji decomposition:

```xml
<g id="kvg:04eee" kvg:element="仮">
  <g id="kvg:04eee-g1" kvg:element="亻" kvg:position="left" kvg:radical="general">
    <path id="kvg:04eee-s1" kvg:type="㇒" d="M32.01,17c0.22,1.93..."/>
    <path id="kvg:04eee-s2" kvg:type="㇑" d="M25.48,37.5c0.57,..."/>
  </g>
  <g id="kvg:04eee-g2" kvg:element="反" kvg:position="right">
    ...
  </g>
</g>
```

The `kvg:` namespace attributes encode rich structural metadata: `kvg:element` (component character), `kvg:position` (left/right/top/bottom/kamae), `kvg:radical` (radical classification), `kvg:type` (CJK stroke type from U+31C0–U+31EF), and `kvg:phon` (phonetic component). This decomposition hierarchy is invaluable for teaching radical recognition alongside stroke order.

**KanjiAlive** (CC BY 4.0) covers only **1,235 kanji** — missing roughly 900 jōyō characters — and critically, its SVGs are cumulative snapshots showing the character state after each stroke, not individual vector paths. It does provide useful supplementary resources: hand-drawn MP4 stroke animations at 248×248, a REST API on RapidAPI, and CSV metadata. **AnimCJK** (Arphic PL/LGPL) offers 5,753 Japanese characters with both outline paths and median centerlines on a 1024×1024 canvas, derived from Makemeahanzi but with Japanese-specific stroke orders. Its dual-path model (outlines for rendering, medians for animation) is architecturally elegant but its licensing is more complex than KanjiVG's.

For metadata, **KANJIDIC2** (CC BY-SA 4.0) provides readings, meanings, grade levels, JLPT levels, frequency rankings, and dictionary cross-references for **13,108 kanji**. Pair it with KanjiVG for a complete data foundation. **JMdict** adds vocabulary and example words for dictionary features but contains no stroke data.

---

## Parsing KanjiVG into native Swift paths

The **nicklockwood/SVGPath** library (MIT, Swift Package Manager) is the ideal parser for this use case. It converts SVG path `d` strings directly to `CGPath` or SwiftUI `Path`, handles all standard SVG commands, and provides scale-to-fit rendering. Since KanjiVG uses only cubic Bézier commands, parsing is straightforward:

```swift
import SVGPath

let cgPath = try CGPath.from(svgPath: strokeDString)
let shapeLayer = CAShapeLayer()
shapeLayer.path = cgPath
```

A critical preprocessing step: KanjiVG files include a custom DTD declaring `kvg:` namespace attributes via `<!ATTLIST>`. Foundation's `XMLParser` can choke on this. **Strip the DOCTYPE declaration** at build time or first launch, then parse with standard `XMLParser` to extract each `<path>` element's `id`, `d` attribute, and `kvg:type`. Store the results in a lightweight struct:

```swift
struct KanjiStroke {
    let strokeNumber: Int   // Extracted from id "kvg:04eee-s3" → 3
    let pathData: String    // SVG d attribute
    let strokeType: String? // kvg:type CJK stroke classification
}
```

Scale paths from KanjiVG's 109×109 coordinate space to your canvas. SVG and UIKit share the same Y-down coordinate convention, so **no Y-axis flip is needed** when rendering via CAShapeLayer. Apply a uniform scale transform: `canvasWidth / 109.0`. For production, consider a build-time script that converts all KanjiVG SVGs into a bundled JSON or SQLite database keyed by Unicode code point, eliminating runtime XML parsing overhead. The nicklockwood/SVGPath library also supports iterating raw commands for custom processing, which is useful for point sampling along reference curves.

Alternative libraries include **PocketSVG** (parses full SVG files into CGPath arrays) and **SwiftSVG** (provides `UIBezierPath(pathString:)` convenience), but SVGPath's lightweight focus on path string parsing is the best fit.

---

## Stroke validation demands a geometric approach, not OCR

Apple's Vision framework (`VNRecognizeTextRequest`) supports Japanese text recognition as of iOS 16, but it performs OCR on images — it cannot process individual strokes or provide per-stroke feedback. The private Scribble engine is not exposed through public APIs. **Vision is the wrong tool for this use case.**

Three viable recognition approaches exist, serving different purposes:

**For per-stroke validation (primary need)**, port the **HanziWriter / curve-matcher algorithm** to Swift. This is the most battle-tested approach, used in production by HanziWriter (4,600+ GitHub stars). The algorithm works in five steps: (1) sample N equally-spaced points along both the user's stroke and each reference stroke (default: 50 points); (2) apply Procrustes normalization — translate curves to the origin and normalize scale; (3) try multiple rotations to find optimal alignment; (4) compute the **discrete Fréchet distance** between normalized curves; (5) convert to a 0–1 similarity score against a configurable leniency threshold. The Fréchet distance is superior to Hausdorff distance because it respects curve direction — a stroke drawn backwards will score poorly, which is exactly the behavior needed for stroke order practice. The entire core algorithm is roughly **200 lines of code** and ports cleanly to Swift since it's pure geometry.

For stroke identification (determining *which* reference stroke the user is attempting), compute the centroid distance between the user's stroke and each unmatched reference stroke as a fast rejection filter, then run Fréchet comparison against candidates. For **stroke order validation**, simply check whether the matched reference stroke number equals the expected next stroke number.

**For whole-character recognition (secondary)**, **Google ML Kit Digital Ink Recognition** is production-quality, supports Japanese, runs on-device (~20MB model download), and is available via CocoaPods. It processes sequences of strokes (not images) and returns recognized characters — the same engine powering Gboard handwriting. Alternatively, **Zinnia** (BSD license, SVM-based) has proven iOS ports: `shinjukunian/zinnia-swift` provides a Swift wrapper, and `tuanna-hsp/kanji-handwriting-swift` demonstrates full integration. Zinnia is lightweight and fast (~50-100 characters/sec) but effectively unmaintained since ~2011.

**For ML-based recognition**, CoreML models trained on the ETL9G dataset (3,036 kanji classes, 607,200 samples) achieve **99%+ accuracy** with deep CNNs. The conversion pipeline — Keras/PyTorch → coremltools → .mlmodel — is well-established. Several open-source projects demonstrate this, including Nippon2019/Handwritten-Japanese-Recognition. However, ML recognition identifies the final character, not individual stroke correctness, so it complements rather than replaces geometric validation.

Practical thresholds based on HanziWriter defaults: **leniency multiplier of 1.0** (adjustable), shape similarity threshold around 0.3–0.4, direction tolerance of ±45° for strict mode or ±90° for lenient, and centroid position tolerance within ~30% of canvas dimension.

---

## Custom touch tracking beats PencilKit for this use case

**PencilKit** (`PKCanvasView`) supports finger drawing via `drawingPolicy = .anyInput` and provides rich stroke data through `PKStroke` → `PKStrokePath` → `PKStrokePoint` (location, timeOffset, force, azimuth). Individual strokes are accessible from `PKDrawing.strokes`, and `canvasViewDrawingDidChange` fires after each stroke completes. However, PencilKit has critical limitations for a kanji trainer: no real-time mid-stroke point access, opaque rendering that prevents dynamic color changes for feedback, and unwanted tool picker UI that must be suppressed.

**A custom drawing view using `touchesBegan`/`touchesMoved`/`touchesEnded`** is the recommended approach. It provides immediate access to every touch point during drawing, enables mid-stroke validation and visual feedback, and produces `[CGPoint]` arrays directly comparable to reference stroke data:

```swift
override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let point = touch.location(in: self)
    currentStrokePoints.append(point)
    onPointAdded?(point, currentStrokePoints) // Real-time validation hook
}

override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    strokes.append(currentStrokePoints)
    onStrokeCompleted?(currentStrokePoints)   // Trigger validation
}
```

Smooth raw touch points into clean curves using **Catmull-Rom spline interpolation** (alpha 0.5, centripetal variant), which passes through all original control points and produces natural-looking brush strokes. Render each completed user stroke as a `CAShapeLayer` for GPU-composited performance.

For stroke-by-stroke kanji animation (the "demo" or "hint" feature), **CAShapeLayer's `strokeEnd` property** is the native equivalent of the CSS `stroke-dashoffset` technique used by every web-based kanji animator. Animate `strokeEnd` from 0 to 1 with `CABasicAnimation` to create a smooth drawing effect, then chain strokes sequentially using completion handlers or `beginTime` offsets. Each KanjiVG stroke maps to one CAShapeLayer — even complex kanji with 20+ strokes are trivial for the GPU since each stroke contains only 1–4 cubic Bézier segments.

---

## Three practice modes share one validation engine

The view hierarchy for all modes consists of three layers: a `KanjiReferenceView` containing CAShapeLayer ghost strokes, a transparent `DrawingCanvasView` for user input, and a `FeedbackOverlayView` for validation indicators. The modes differ only in ghost stroke visibility and validation timing.

**Mode A (Trace — full ghost visible):** All reference strokes render as light gray CAShapeLayers with `strokeEnd = 1.0` and alpha ~0.3. The current expected stroke highlights slightly brighter (alpha ~0.5). When the user completes a stroke, the validation engine compares it against the expected reference. Accepted strokes render in green; rejected strokes flash red and clear. This mode is the gentlest introduction and works well for beginners.

**Mode B (Stroke-by-stroke reveal):** Only the next expected stroke appears as a ghost guide, animated into view using `strokeEnd` animation over 0.5 seconds. A simple state machine tracks progression: `waitingForInput` → `userDrawing` → `validating` → `strokeAccepted`/`strokeRejected` → back to `waitingForInput`. After validation accepts a stroke, the ghost transforms from gray to green (confirmed), and the next ghost animates in. After N consecutive misses (configurable, default 3), auto-animate the correct stroke as a hint — matching HanziWriter's proven UX pattern.

**Mode C (Free draw from memory):** No ghost strokes visible. Two sub-strategies: (1) **per-stroke sequential matching**, which assumes the user draws in correct order and validates each stroke against the expected reference after normalizing both to a common bounding box; (2) **post-completion matching**, which lets the user draw all strokes, then uses bipartite graph matching (Hungarian algorithm) to find optimal stroke correspondences and scores overall accuracy. Normalization is critical in this mode — translate and scale both user and reference strokes to a unit square before comparison. The CCR project's minimum-weight bipartite matching algorithm provides a reference implementation for stroke-order-invariant matching.

---

## Existing projects validate this architecture

**No fully featured open-source iOS Swift kanji writing app exists**, confirming this as a meaningful gap. The closest projects are:

- **Kanji Dojo** (Kotlin Multiplatform, 628 stars, GPL): The most complete open-source kanji practice app, with writing validation, SRS, JLPT progression, and 6,000+ characters using KanjiVG + KANJIDIC. iOS support is in preparation. Its architecture — parsing KanjiVG SVGs, stroke-by-stroke validation, spaced repetition integration — maps almost directly to the Swift implementation described here.

- **HanziWriter** (JavaScript, 4,600 stars, MIT): The gold standard for web-based stroke quiz UI. Its `curve-matcher` algorithm (Fréchet distance + Procrustes) is the single most portable validation approach. The `react-native-hanzi-writer` port demonstrates how this maps to a mobile component model with `Character`, `QuizStrokes`, and `MistakeHighlighter` components.

- **CCR** (C/SDL): Implements stroke-order-invariant recognition via minimum-weight bipartite graph matching — valuable for building a forgiving free-draw mode.

- **KanjiCanvas** (JavaScript, MIT): Implements the Wakahara et al. (1996) algorithm for stroke-number and stroke-order free recognition, achieving recognition even with partially incorrect stroke counts.

Commercial apps provide UX guidance: **Skritter** validates at the stroke level with adjustable leniency and is known to struggle with hook strokes — a useful edge case to plan for. **KanjiQ** uses KanjiVG data with a trace-or-hide paradigm. **iKanji touch** implements connect-the-dots stroke order tests and a 5-group SRS system.

---

## Conclusion: the implementation roadmap

The recommended stack is **KanjiVG** (stroke vectors) + **KANJIDIC2** (metadata) + **nicklockwood/SVGPath** (parsing) + **custom touch-tracking canvas** (input) + **Fréchet/Procrustes validation** (ported from HanziWriter's curve-matcher). Pre-process KanjiVG files at build time into a bundled JSON database, stripping the DOCTYPE and extracting stroke paths, types, and component hierarchy. Implement the three practice modes as thin configuration layers over a shared validation engine, varying only ghost stroke visibility and validation timing.

The critical path is: (1) bundle and parse KanjiVG data, (2) render strokes as CAShapeLayers with animation, (3) build the custom drawing canvas with Catmull-Rom smoothing, (4) implement point sampling along both reference and user curves, (5) port the Fréchet + Procrustes algorithm to Swift, and (6) wire up the three modes with their respective ghost/feedback behaviors. Google ML Kit Digital Ink Recognition can serve as a secondary whole-character validation layer, and KANJIDIC2 metadata enables JLPT-level and grade-level progression systems. The entire stroke validation core — the piece that doesn't exist in any Swift library today — is roughly 200–300 lines of pure Swift geometry code, making this a tractable project with a clear technical path.