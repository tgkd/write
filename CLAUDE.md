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
   - The iPad detail column has one owner: every detail screen is a route in `iPadNavigationPath`. Sidebar controls open routes through `KanjiPickerView.openRoute`, which replaces the path, never through a value `NavigationLink`. A sidebar link covers the detail stack with a screen that has no back button and that clearing the path can't remove, so letter taps stop doing anything
   - The iPad sidebar starts visible beside the detail (`columnVisibility = .all`, `.navigationSplitViewStyle(.balanced)`). With `.automatic`, portrait launched into an empty "Select a kanji" screen. The app owns the sidebar toggle (`SidebarToggleToolbar` on the detail root and every route) and removes the system one from the sidebar column. The system toggle vanishes on pushed drawing screens, and next to the custom one it showed twice whenever the sidebar was hidden. UI tests written for the iPhone push flow (`RecallUITests`) don't apply to this layout
   - Regular width always gets the split shell. On iPad it also stays in a compact-width window while the detail path holds a route (`ContentView.usesSplitShell`), so narrowing the window doesn't drop an open session: the two shells keep separate navigation state, and swapping shells would throw the detail stack away. A compact window with an empty path still gets the iPhone shell. Keeping the detail column in front in compact width needs a split-view API that only exists from iOS 17, so on earlier versions a compact window always switches to the iPhone shell and the session is lost
   - The `-uiTestingSizeClassToggle` launch argument adds a test-only button (`UITestingSizeClassToggle`) that flips the window's horizontal size class, on the same iOS versions as the rule above. That is how UI tests exercise compact width

### Practice, Recall and practice history

- The Home screen (`KanjiPickerView`) starts three session kinds for the current filter: Practice, Recall and Review (a Recall session over `PracticeStats.reviewItems`). Tapping a character in the grid, a widget link and the iPad detail view always open plain practice
- Home cards are buttons that call `openRoute` in both shells and build their random queue when tapped, never in `body`, which runs on every selection and filter change. The count on a card comes from the filter's pool size, kept in view state
- The Experimental setting `AppSettings.showWordPractice` gates the Writing card in the iPad shell and the Words card in the compact/iPhone shell. Their routes, prompts and `WordHistoryStore` exist regardless. UI tests pass `-showWordPractice YES|NO` explicitly, because the stored value survives between launches
- Word prompts keep the original `w..` ids and their hashed fields (`WordPrompt.revision`) unchanged forever, because word history refers to them; generated prompts use `t<tatoebaId>`. The answer must be unambiguous from the kana sentence plus the gloss, which the generator enforces against JMdict
- iPad Writing replaces the former Words and Sentences entry points. A sentence is one page (`WritingView`): the sentence header stays pinned, and beneath it each generated token-index phrase is a row with its reading above it; long phrases wrap inside their row. In the graded modes `WritingSession` moves the active cell through the whole sentence without stopping at phrase ends, keeping sentence character indices in `WordSlotRecord.segmentIndex`. Punctuation is unboxed; characters without stroke data prefill
- The Writing row being written is centred and is the only one that takes touches; the others stay dimmed until the sentence is complete. The row list can't be scrolled by hand, so a resting hand never moves the page or draws in the wrong row. In the graded modes focus follows the active cell. In Free, and once a graded sentence is complete, row buttons in the controls bar move it
- Writing has its own persisted Free/Trace/Empty choice, separate from `practiceMode`. Free never grades or records history. Trace uses non-Recall `PracticeState` and exposed slots; Empty uses Recall and its hints. Only generated spelling-reviewed prompts can enter Empty
- A Writing mode change queues for the next sentence, or can apply when the first phrase is explicitly restarted. Later phrase restarts preserve the sentence's mode. In Free, restart clears the whole sentence and applies a queued mode, and Next goes straight to the next sentence. Sentence progress counts completed prompts and the eligible remainder, excluding skipped prompts
- Completed graded sentences emit one `WordRecord` with nested slot records into `WordHistoryStore`, never standalone practice history. Restart discards only the current phrase's attempts. Finished cells retain the user's ink, and a single screen-level Pencil interaction targets the active graded cell or the last-used free cell
- In Writing the rejection text is shown once in the controls bar (`WritingRejectionNotice`) and clears itself after a few seconds, never inside a cell, where it would cover the next stroke's mask. Standalone practice keeps the pill on its large canvas
- Presentation metadata is optional for decoding older prompts. Unknown versions or invalid partitions are excluded from Writing. The generator checks non-target kanji against JMdict for spelling alternatives, homophones and unresolved analyses; flagged prompts remain usable in Free and Trace
- `PracticeMode` is only the guide level (Trace, Guided, Copy). The picker writes `AppSettings.practiceMode`, which every new practice screen and the next session character start from. `copy` keeps the raw value `freeDraw` so old history and settings still decode
- `AppSettings.recallCueOrder` only reorders the cue; both orders show the same information, so `RecallEligibility` is order-independent (a test enforces it). A cue profile that hides information must revisit eligibility. Spoken readings go through `SpokenReading`, never raw dictionary notation
- Recall is not a mode: `PracticeState(isRecall: true)` pins the mode to Guided, so the strokes hint reveals one stroke at a time, and hides the answer until hints. `hint` steps through `RecallHint` (character, then strokes); `hidesCharacter` swaps the header glyph for a placeholder and `hidesGuide` hides the whole `KanjiReferenceView` rather than individual strokes, because accepted-stroke marking and the initial ghost would each leak it
- Recall only exists inside sessions, so a character the user just tapped in the grid is never treated as unseen. Recall queues contain only `RecallEligibility`-eligible characters (`KanjiDataStore.randomCharacters(forRecall:)` and `queue(for:)`); ineligible ones (identical readings, meanings and stroke count, or no cue) are dropped, never shown with the answer
- Kana that share a Hepburn romaji get a distinct cue text (`RecallCue.cueRomaji`), and `RecallEligibility` compares that same cue text, so what the cue shows and what counts as ambiguous can't disagree. The dataset's romaji stays Hepburn, because search matches on it
- Stroke order is enforced in every graded mode
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

Position is always checked against the fixed reference in canvas coordinates; the reference never moves to follow the user's ink. With a guide drawn (Trace, Guided) the tolerance is `positionTolerance`; in Copy and Recall it is the looser `guidelessPositionTolerance` for every stroke, and stroke 1 gets a start marker (`PracticeState.startMarker`). A character drawn shifted or at another size is reported as position errors. The proportion check (enforced only on Strict, and only without a guide) compares each stroke's size with the reference stroke itself. An expected stroke that passes always wins over a better-scoring lookalike.

Every graded mode applies the box rule: a stroke is rejected (`StrokeRejection.outOfFrame`) when its centerline leaves the canvas by more than `ValidationConfig.boundaryTolerance`.
- The check runs on the points validation already receives (fixed filter, hook-trimmed), so a trimmed lift-off hook never trips it.
- `geometryAccepted` keeps the verdict from before the box check, so a geometric match to a later stroke still counts as order evidence.
- Run-level and per-stroke miss counts both go through `MissEvidence.record`. The notice shown and the counts are decided independently.

Yōon catalog entries are composed by the preprocessor from two KanjiVG glyphs and keyed by two hyphen-separated code points. Small kana have no entries of their own. Yōon combinations are not writable units in Writing or Words.

A rejection reports why the expected stroke failed (`StrokeValidationResult.expectedEvidence`), not the best-scoring candidate. `AppSettings.showRejectionReasons` hides all rejection text, and the text clears when the next stroke begins.

Closed reference strokes, which today means only the handakuten circle, go through `ClosedStrokeMatcher`: any start, either direction and imperfect closure pass, and Strict uses Normal's shape limit for them. Size and position stay at the configured strictness. Which strokes count as closed is geometric, so a dataset update can change the set; a test pins it. Open strokes stay sensitive to start and direction.

KanjiVG draws some short kana strokes with a back-flick the printed glyph doesn't have. `KanaStrokeVariants` lists them by hand, because geometry alone also catches real parts of kanji strokes such as the ㇕ of a small 口. In every mode a listed stroke is also compared against variants with no flick, a shorter one or a longer one, because the flick's length is what rejected hand-drawn strokes lying on the guide. Each variant is a complete candidate: its own shape, centroid and extent all have to pass.

### Practice grid and model

Every practice canvas draws `PracticeGridView` under the reference (`AppSettings.showPracticeGrid`), in the same transform as the strokes. Copy and Recall show `PracticeModelView`, drawn from the KanjiVG strokes on the same grid, because the system font's glyph has different extents and forms from what is graded: its う dash has no curl. Never crop the model to its ink or give it the mask's line width. In Recall the model follows `hidesCharacter`. Turning the grid off removes only the lines, not the model. Elsewhere the font stays: compact labels, the character card, word and sentence hints.

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
