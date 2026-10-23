# App Store Release Report — Write (Kanji Writing Trainer)

## Blockers (must fix)

| # | Issue | Details |
|---|-------|---------|
| 1 | **Privacy Manifest missing** | No `PrivacyInfo.xcprivacy` file exists. Required since Spring 2024. Since the app collects zero data and makes no network requests, this is just a declaration of "none" — but Apple will reject without it. |
| 2 | **`ITSAppUsesNonExemptEncryption` missing** | Not set in Info.plist. Without it, you'll be asked about export compliance on every TestFlight/submission upload. Set to `false` (app doesn't use custom encryption). |
| 3 | **Privacy Policy** | App Store Connect requires a privacy policy URL. Even for a fully offline app. You'll need to host one somewhere (GitHub Pages, a simple webpage). |
| 4 | **Code Signing / Team** | No `DEVELOPMENT_TEAM` in project.yml. You'll need an Apple Developer account enrolled in the paid program ($99/yr) and to set the team before archiving. |

## Should fix

| # | Issue | Details |
|---|-------|---------|
| 5 | **App icon** | You have a single 1024x1024 universal icon — this works with modern Xcode (iOS 17+ asset catalogs auto-slice from a single 1024 image). Since deployment target is iOS 16, verify it generates all sizes correctly when you archive. If not, you'll need to add explicit sizes. |
| 6 | **Launch screen** | Currently `UILaunchScreen: {}` — plain white/black screen. Functional but feels unfinished. A simple branded launch screen (app name + background color) would be better. |
| 7 | **App Store screenshots** | 7 PNGs in `Screenshots/` — good content coverage. But App Store Connect needs specific device frame sizes (6.7" for iPhone 15 Pro Max, 6.1" for iPhone 15 Pro, optionally 5.5" for older). Verify screenshots match the required resolutions. |
| 8 | **Data attribution** | KanjiVG is CC BY-SA 3.0, KANJIDIC2 is CC BY-SA 4.0. Both require attribution. Add an "About" or "Acknowledgments" section in the app (or at minimum in the App Store description). Apple reviewers occasionally check for this. |

## Nice to have

| # | Item | Notes |
|---|------|-------|
| 9 | App Store description & keywords | Write compelling copy. "Kanji", "Japanese", "writing", "JLPT", "stroke order" are obvious keywords. |
| 10 | App preview video | A 15-30s screen recording of someone tracing a kanji would sell the app far better than static screenshots. |
| 11 | Support URL | Required field in App Store Connect. Can be a simple GitHub repo issues page or a one-page site. |

## What's already solid

- **Code quality**: Zero TODOs/FIXMEs, clean codebase, 98% engine test coverage
- **Feature set**: Complete — kanji grid, JLPT filtering, search, 3 practice modes, session practice, settings, completion feedback
- **Dependencies**: Single stable dependency (SVGPath, MIT licensed) — no review risk
- **No network/tracking**: Makes App Review straightforward — no privacy questionnaire complications
- **Bundle ID & versioning**: Properly configured at 1.0.0 (build 1)

## Recommended action order

1. Create Apple Developer account (if not done) and set `DEVELOPMENT_TEAM`
2. Add `PrivacyInfo.xcprivacy` (declare no data collection)
3. Add `ITSAppUsesNonExemptEncryption: false` to Info.plist
4. Host a privacy policy and prepare a support URL
5. Add attribution screen in-app for KanjiVG/KANJIDIC2
6. Verify screenshots match required App Store dimensions
7. Create App Store Connect listing, upload build via Xcode, submit
