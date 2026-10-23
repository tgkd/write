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
xcodebuild test -project Write.xcodeproj -scheme Write -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -parallel-testing-enabled NO -resultBundlePath TestResults

# Run a single test class
xcodebuild test -project Write.xcodeproj -scheme Write -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -parallel-testing-enabled NO -only-testing:WriteTests/StrokeValidationTests

# UI tests live in their own scheme so the unit-test command stays fast
xcodebuild test -project Write.xcodeproj -scheme WriteUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -parallel-testing-enabled NO

# Preprocess KanjiVG + KANJIDIC2 data (only needed when updating the dataset)
python3 Scripts/preprocess_kanjivg.py Data/kanjivg.xml Data/kanjidic2.xml Write/Resources/kanji_strokes.json
```

Whenever `kanji_strokes.json` changes, regenerate the widget's kanji list and commit it:

```sh
python3 Scripts/build_daily_kanji.py Write/Resources/kanji_strokes.json WriteWidget/Resources/daily_kanji.json
```

`word_prompts.json` is generated from the Tanaka/Tatoeba corpus and JMdict in the sibling `jisho-data` checkout; never hand-edit it. The script's usage line has the arguments, and its hand-excluded sentence list is part of the dataset:

```sh
python3 Scripts/build_word_prompts.py <examples.utf> <jpn_transcriptions.tsv> <JMdict_e> Write/Resources/kanji_strokes.json Write/Resources/word_prompts.json
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
   - The iPad sidebar starts visible beside the detail (`columnVisibility = .all`, `.navigationSplitViewStyle(.balanced)`). With `.automatic`, portrait launched into an empty "Select a kanji" screen. The app owns the sidebar toggle (`SidebarToggleToolbar` on the detail root and the drawing screens) and removes the system one from the sidebar column. The system toggle vanishes on pushed drawing screens, and next to the custom one it showed twice whenever the sidebar was hidden. UI tests written for the iPhone push flow (`RecallUITests`) don't apply to this layout

### Practice, Recall and practice history

- The Home screen (`KanjiPickerView`) starts three session kinds for the current filter: Practice, Recall and Review (a Recall session over `PracticeStats.reviewItems`). Tapping a character in the grid, a widget link and the iPad detail view always open plain practice
- The Words session card shows only when the Experimental setting `AppSettings.showWordPractice` is on (off by default). Its routes, prompts and `WordHistoryStore` exist regardless. UI tests pass `-showWordPractice YES|NO` explicitly, because the stored value survives between launches
- Word prompts keep the original `w..` ids and their hashed fields (`WordPrompt.revision`) unchanged forever, because word history refers to them; generated prompts use `t<tatoebaId>`. The answer must be unambiguous from the kana sentence plus the gloss, which the generator enforces against JMdict
- iPad also offers Sentences behind the same setting: the whole written sentence, one block per token, every character with stroke data written in Recall; characters without stroke data (small kana, punctuation) fill in automatically. A sentence is stored as one `WordRecord` in `WordHistoryStore`, never in `PracticeHistoryStore`
- `PracticeMode` is only the guide level (Trace, Guided, Copy). The picker writes `AppSettings.practiceMode`, which every new practice screen and the next session character start from. `copy` keeps the raw value `freeDraw` so old history and settings still decode
- `AppSettings.recallCueOrder` only reorders the cue; both orders show the same information, so `RecallEligibility` is order-independent (a test enforces it). A cue profile that hides information must revisit eligibility. Spoken readings go through `SpokenReading`, never raw dictionary notation
- Recall is not a mode: `PracticeState(isRecall: true)` pins the mode to Guided, so the strokes hint reveals one stroke at a time, and hides the answer until hints. `hint` steps through `RecallHint` (character, then strokes); `hidesCharacter` swaps the header glyph for a placeholder and `hidesGuide` hides the whole `KanjiReferenceView` rather than individual strokes, because accepted-stroke marking and the initial ghost would each leak it
- Recall only exists inside sessions, so a character the user just tapped in the grid is never treated as unseen. Recall queues contain only `RecallEligibility`-eligible characters (`KanjiDataStore.randomCharacters(forRecall:)` and `queue(for:)`); ineligible ones (identical readings, meanings and stroke count, or no cue) are dropped, never shown with the answer
- Stroke order is enforced in every mode
- `PracticeState` emits one `PracticeRecord` per run through `onRunCompleted`; undo/recomplete never emits again, reset or a mode change starts a new run. Session results hang off the same event
- Recall runs are stored with `mode` set to `PracticeRecord.recallMode` (`"study"`, the pre-rename value). `revealed` means a hint was used; `exposed` is false only for Recall runs and stays in the format because older Study runs could be exposed. Review only reads unexposed Recall runs
- `PracticeHistoryStore` writes monthly versioned JSON files under Application Support; a file it can't decode is moved aside, and a month it can't move aside is never written to. UI tests pass `-uiTestingFreshHistory` for a throwaway store and `-practiceMode trace` so a saved guide level from an earlier run doesn't leak in
- Practice history (not word history or settings) syncs through a CloudKit private zone: one immutable record per `PracticeRecord`, carrying the store's own JSON encoding, merged as a union by id. There are no deletes and no push; sync runs on foreground and shortly after a local record. `-uiTestingFreshHistory` turns sync off. A new CloudKit field or record type works in Development only until the schema is deployed to Production
- Records grow only by optional fields, so old files keep loading. An older build ignores the new keys and drops them when it rewrites a month. Analysis fields include:
  - session and origin, passed in as `RunContext` when the screen creates its `PracticeState`;
  - hint level, undos, input kind, canvas size, device, timing, interruption and config changes;
  - per-stroke `StrokeStat` counters.
  New counter types decode missing keys as zero and leave zeros out when encoding. Never store a non-finite Double: `JSONEncoder` throws, and the record stays unsaved forever
- Only completed runs are recorded. A word record nests each slot's full `PracticeRecord` (`WordSlotRecord`). Slot runs never enter `PracticeHistoryStore`, so word success can't clear a standalone Review item

### Validation pipeline

User stroke -> sample N points -> Procrustes normalize (center + scale, no rotation) -> Frechet distance against reference -> score (0-1)

Stroke identification uses centroid distance as a fast rejection filter before running the full Frechet comparison.

Position is checked in canvas coordinates only while a guide is drawn (Trace, Guided). In Copy and Recall it is checked relative to the user's own accepted strokes (`StrokeAnchor`, `StrokeValidator.placementOffset`), with a start marker for stroke 1 (`PracticeState.startMarker`) and a looser first-stroke tolerance. The offset is clamped so the shifted reference stays inside the canvas, and `applyPlacement` shifts the reference layer by the same offset so accepted strokes and later hints line up with the user's ink. An expected stroke that passes always wins over a better-scoring lookalike.

Every mode applies the box rule: a stroke is rejected (`StrokeRejection.outOfFrame`) when its centerline leaves the canvas by more than `ValidationConfig.boundaryTolerance`.
- The check runs on the points validation already receives (fixed filter, hook-trimmed), so a trimmed lift-off hook never trips it.
- `geometryAccepted` keeps the verdict from before the box check, so a geometric match to a later stroke still counts as order evidence.
- Run-level and per-stroke miss counts both go through `MissEvidence.record`. The notice shown and the counts are decided independently.

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
