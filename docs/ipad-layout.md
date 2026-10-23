# iPad Layout — Design Document

## Current State

The app runs on iPad as a scaled-up iPhone layout. The practice screen has a single centered canvas with dead space on both sides. For v1.0, the app ships as iPhone-only. This document describes the planned iPad experience.

## Core Idea: Kanji Practice Notebook

Modeled after real Japanese practice notebooks (漢字練習帳 / カタカナ練習帳). The layout uses **vertical columns** — one character per column, written top to bottom, following the traditional Japanese writing direction.

Reference photo: katakana practice notebook (IMG_5684.jpg)

```
     山           川           火           水
  ┌──┬──┐     ┌──┬──┐     ┌──┬──┐     ┌──┬──┐
  │山│  │     │川│  │     │火│  │     │水│  │   ← header: printed ref + reading
  ├──┼──┤     ├──┼──┤     ├──┼──┤     ├──┼──┤
  │⌇│⌇│     │⌇│⌇│     │⌇│⌇│     │⌇│⌇│   ← row 1 (2 cells per row)
  ├──┼──┤     ├──┼──┤     ├──┼──┤     ├──┼──┤
  │⌇│⌇│     │⌇│⌇│     │⌇│⌇│     │⌇│⌇│   ← row 2
  ├──┼──┤     ├──┼──┤     ├──┼──┤     ├──┼──┤
  │⌇│⌇│     │⌇│⌇│     │⌇│⌇│     │⌇│⌇│   ← row 3
  ├──┼──┤     ├──┼──┤     ├──┼──┤     ├──┼──┤
  │  │  │     │  │  │     │  │  │     │  │  │   ...
  ├──┼──┤     ├──┼──┤     ├──┼──┤     ├──┼──┤
  │  │  │     │  │  │     │  │  │     │  │  │
  ├──┼──┤     ├──┼──┤     ├──┼──┤     ├──┼──┤
  │  │  │     │  │  │     │  │  │     │  │  │
  └──┴──┘     └──┴──┘     └──┴──┘     └──┴──┘
└─────────┴────┴────┴────┬────┴────┴────┴────┘
│         │    │    │    │    │    │    │    │
│   川    │ 川 │    │    │    │    │    │    │
│         │    │    │    │    │    │    │    │
```

Key properties (matching real notebooks):

- **Horizontal rows**: one character per row, user writes left to right
- **Header cell**: printed reference kanji (large) + reading beside the row
- **Two cells per column within each row**: each column position has two stacked practice cells — doubles the repetitions without making cells tiny
- **Many repetitions**: ~8-10 cells per row. The point is muscle memory through volume, not one perfect attempt.
- **No guide strokes**: unlike the current app's trace mode, the notebook is all free practice. The reference is at the left; you look at it and reproduce from memory.
- **Crosshair guidelines**: each cell has a faint cross dividing it into quadrants, helping the user center and proportion their strokes
- **Multiple rows visible**: 3-5 characters on screen at once, scrolls vertically for more
- **Scrolls horizontally** within each row if cells extend beyond the screen

This layout makes the iPad feel like writing on actual paper. Combined with Apple Pencil, it's the natural way to practice.

## Screen Layouts

### Kanji Picker (iPad)

Side-by-side master-detail:

```
┌──────────────────┬─────────────────────────────┐
│ Write            │                             │
│                  │         丹                  │
│ [All][N5]...[N1] │        タン / に             │
│ ┌──┬──┬──┬──┐   │   "rust-colored, red"       │
│ │充│冗│巳│一│   │                             │
│ ├──┼──┼──┼──┤   │      [stroke order          │
│ │万│丈│三│上│   │       animation]             │
│ ├──┼──┼──┼──┤   │                             │
│ │与│丙│丑│且│   │   Grade: 教育 (Kyōiku)       │
│ └──┴──┴──┴──┘   │   JLPT: N1                  │
│                  │   Strokes: 4                 │
│ [▶ Practice]     │   [Practice]                │
│ [⚙ Settings]    │                             │
└──────────────────┴─────────────────────────────┘
```

- Left panel: kanji grid + filters + search (persistent)
- Right panel: selected kanji detail with large preview, readings, metadata
- Tapping a kanji in the grid shows its detail; tapping "Practice" enters practice mode

### Practice — Notebook Mode (iPad only)

The flagship iPad feature.

```
          ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
  山 やま │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │  ← 10 practice cells, left to right
  サン    │  │  │  │  │  │  │  │  │  │  │
          └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
          ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
  川 かわ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │
  セン    │  │  │  │  │  │  │  │  │  │  │
          └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
          ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
  火 ひ   │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │╳ │
  カ      │  │  │  │  │  │  │  │  │  │  │
          └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
```

- ╳ = crosshair guidelines (light gray cross dividing each cell into quadrants, like real practice paper)
- **Reference label** on the left: printed kanji + kun'yomi + on'yomi, always visible
- **All cells are free practice**: no guide/trace strokes. The reference is right there — you look at it and write from memory. This is how real practice books work.
- User writes left to right, filling each row
- Completed cells keep the user's handwriting visible (like ink on paper)
- Validation runs after all strokes are drawn — subtle feedback (green/red border flash), but doesn't block progress. The notebook is about volume, not perfection.
- Scrolls vertically for more kanji rows

**Cell behavior:**
- Tap empty cell to activate it (highlighted border)
- Draw all strokes for the kanji
- Validation runs on completion (all strokes drawn) — light feedback only
- Next cell activates automatically after completion
- Double-tap a completed cell to clear and redo it

**Grid dimensions:**
- Each cell: ~100-120pt square on 12.9" iPad, ~80-100pt on 11"
- 8-10 practice cells per row (fits landscape nicely)
- Visible rows: 3-5 depending on iPad size and orientation
- Reference label column: ~120pt wide

### Practice — Single Kanji Mode (iPad)

For focused practice of one kanji. Side-by-side layout:

```
┌─────────────────┬──────────────────────────────┐
│                 │                              │
│      山         │                              │
│                 │                              │
│   サン / やま    │      [drawing canvas]        │
│   "mountain"    │                              │
│                 │                              │
│   Strokes: 3    │                              │
│                 │                              │
│   ● ○ ○        │                              │
│   [Trace ▾]    │      [erase] [undo]          │
│                 │                              │
└─────────────────┴──────────────────────────────┘
```

- Left panel (~30%): kanji reference, readings, meanings, stroke order dots, mode selector
- Right panel (~70%): large drawing canvas
- Canvas is square, vertically centered in the right panel

## Apple Pencil Support

### Input Handling

- **Palm rejection**: Use `UIGestureRecognizer.allowedTouchTypes` to separate pencil from finger input. Pencil draws; fingers scroll/navigate.
- **Pressure sensitivity**: Map `UITouch.force` to stroke width. Light pressure = thin line, firm pressure = thick line. Range: 2-8pt (configurable).
- **Tilt**: Optional — could angle the "brush" for calligraphic feel, but start without this. Real brush calligraphy (毛筆) is a different domain.
- **Low latency rendering**: Use `UITouch.predictedTouches(for:)` to render predicted stroke positions ahead of the actual input. Eliminates perceived lag.
- **Hover preview (iPad Pro M2+)**: Show a subtle dot or crosshair at the pencil's hover position (`UIHoverGestureRecognizer`). Helps the user see where the stroke will start.

### Pencil vs Finger

| Action | Apple Pencil | Finger |
|--------|-------------|--------|
| Draw strokes | Yes | Fallback (when no Pencil) |
| Undo (two-finger tap) | — | Yes |
| Scroll notebook grid | — | Yes |
| Select cell | — | Yes (tap) |
| Erase last stroke | Double-tap Pencil (2nd gen) | Undo button |

- When Apple Pencil is detected, disable finger drawing by default (prevent accidental marks from palm rejection misses)
- Settings toggle: "Allow finger drawing" for users without Pencil
- Detect Pencil availability via `UIPencilInteraction`

### Double-Tap Action (Apple Pencil 2nd gen)

Register `UIPencilInteraction` and handle `UIPencilInteraction.preferredTapAction`:
- Default mapping: undo last stroke
- Could also offer: switch between trace/free mode, toggle reference visibility

### Squeeze Action (Apple Pencil Pro)

`UIPencilInteraction.preferredSqueezeAction`:
- Map to: clear canvas / start next cell
- Or: toggle guide strokes visibility

### Ink Feel

- Default: clean uniform-width line (current behavior) — good for stroke validation
- Optional "brush" mode: variable width based on pressure + velocity. Thicker at slow/pressed, thinner at fast/light. Purely cosmetic — validation still uses centerline path.
- Smoothing: current Catmull-Rom spline interpolation works well, keep it

## Settings (iPad additions)

| Setting | Options | Default |
|---------|---------|---------|
| Cells per row | 6 / 8 / 10 | 8 |
| Pressure sensitivity | Off / Low / Medium / High | Medium |
| Allow finger drawing | On / Off | Off (when Pencil paired) |
| Pencil double-tap action | Undo / Clear cell / Next cell | Undo |
| Show crosshair guidelines | On / Off | On |

## Implementation Notes

- Use `UIDevice.current.userInterfaceIdiom == .pad` to switch layouts
- Notebook grid: `UICollectionView` with compositional layout, not SwiftUI `LazyVGrid` — need precise cell sizing and scroll behavior
- Each practice cell is a miniature `DrawingCanvasView` instance — reuse the existing engine, just scaled down
- Validation pipeline is unchanged — same Procrustes + Frechet scoring at any canvas size
- KanjiVG 109x109 coordinate space scales uniformly to any cell size via existing `StrokeRenderer` transform
- Multi-cell state: new `NotebookPracticeState` that tracks per-cell completion, current active cell, and session progress
- Pencil input: modify `DrawingCanvasView` to accept `UITouch.TouchType` filtering and force/azimuth data

## Open Questions

- Should notebook mode support landscape only, or also portrait? Portrait gives fewer cells per row (~5-6) but more visible rows — still usable.
- Undo granularity in notebook mode: undo last stroke in current cell, or clear entire cell?
- Should the notebook be exportable as an image/PDF? (Nice for sharing progress, but scope creep for v1)
- How strict should validation be in notebook mode? Real notebooks have zero validation — it's pure practice. Maybe validation is opt-in here.
