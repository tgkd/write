import SwiftUI

struct SentenceSessionSummaryView: View {
    let results: [SentencePracticeState.SentenceResult]
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
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal, 16)

            List(results.indices, id: \.self) { i in
                let result = results[i]
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.sentence)
                            .font(.title2)
                        Text(result.kana)
                            .font(.subheadline)
                        if let translation = result.prompt.translation {
                            Text(translation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if result.misses == 0 && result.hintsUsed == 0 {
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
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .accessibilityIdentifier("sentenceSummary")

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
            .frame(maxWidth: 640)
            .padding(.bottom, 16)
            .accessibilityIdentifier("sentence.done")
        }
    }

    private var subtitle: String {
        let count = results.count
        let written = count == 1 ? String(localized: "\(count) sentence written") : String(localized: "\(count) sentences written")
        let hinted = results.filter { $0.hintsUsed > 0 }.count
        guard hinted > 0 else {
            return written
        }
        return String(localized: "\(written) · \(hinted) needed a hint")
    }

    private func detail(for result: SentencePracticeState.SentenceResult) -> String {
        var parts: [String] = []
        if result.hintsUsed > 0 {
            parts.append(result.hintsUsed == 1 ? String(localized: "1 hint") : String(localized: "\(result.hintsUsed) hints"))
        }
        if result.misses > 0 {
            let count = result.misses
            parts.append(count == 1 ? String(localized: "\(count) miss") : String(localized: "\(count) misses"))
        }
        return parts.joined(separator: " · ")
    }
}
