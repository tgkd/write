import SwiftUI

struct SessionSummaryView: View {
    let results: [SessionState.KanjiResult]
    let kind: SessionKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Session Complete")
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            List(results.indices, id: \.self) { i in
                let result = results[i]
                HStack {
                    Text(String(result.kanjiData.character))
                        .font(.system(size: 28))
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
                    } else {
                        Text(detail(for: result))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                dismiss()
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
