import SwiftUI

struct SessionSummaryView: View {
    let results: [SessionState.KanjiResult]
    let kind: SessionKind
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: PracticeHistoryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("Session Complete")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            List(results.indices, id: \.self) { i in
                let result = results[i]
                HStack {
                    Text(result.kanjiData.text)
                        .font(.system(size: 28))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .frame(width: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        if let romaji = result.kanjiData.romaji {
                            Text(romaji)
                                .font(.subheadline)
                        } else if let meanings = result.kanjiData.meanings, !meanings.isEmpty {
                            Text(meanings.prefix(2).joined(separator: ", "))
                                .font(.subheadline)
                        }
                        Text("\(result.kanjiData.strokes.count) strokes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if result.attemptCount == 0 && !result.usedHint {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                            .accessibilityLabel("No retries or hints")
                    } else {
                        Text(detail(for: result))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .listStyle(.plain)

            if kind == .recall && results.contains(where: needsReview) {
                Text("Characters you needed a hint or retries for are waiting in Review.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Button {
                finish()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
    }

    private func finish() {
        let now = Date()
        let asksForReview = history.unsavedCount == 0 && ReviewPromptGate.isEligible(
            completedAt: history.records.map(\.completedAt),
            lastAttemptAt: settings.lastReviewAttemptAt,
            now: now,
            calendar: .current
        )
        if asksForReview {
            settings.lastReviewAttemptAt = now
            settings.isReviewRequestPending = true
        }
        dismiss()
    }

    private var subtitle: String {
        let count = results.count
        switch kind {
        case .practice:
            if count == 1 {
                return String(localized: "\(count) character practiced")
            }
            return String(localized: "\(count) characters practiced")
        case .recall:
            if count == 1 {
                return String(localized: "\(count) character recalled")
            }
            return String(localized: "\(count) characters recalled")
        }
    }

    private func needsReview(_ result: SessionState.KanjiResult) -> Bool {
        result.usedHint || result.attemptCount > 0
    }

    private func detail(for result: SessionState.KanjiResult) -> String {
        var parts: [String] = []
        if result.usedHint {
            parts.append(String(localized: "hint"))
        }
        if result.attemptCount > 0 {
            let count = result.attemptCount
            parts.append(count == 1 ? String(localized: "\(count) miss") : String(localized: "\(count) misses"))
        }
        return parts.joined(separator: " · ")
    }
}
