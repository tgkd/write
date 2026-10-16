import SwiftUI

struct WordSessionSummaryView: View {
    let results: [WordPracticeState.WordResult]
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
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal, 16)

            List(results.indices, id: \.self) { i in
                let result = results[i]
                HStack(spacing: 12) {
                    Text(result.prompt.answer)
                        .font(.system(size: 28))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.prompt.reading)
                            .font(.subheadline)
                        Text(result.prompt.gloss)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if result.misses == 0 && result.hintsUsed == 0 {
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
            .accessibilityIdentifier("wordSummary")

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
            .accessibilityIdentifier("word.done")
        }
    }

    private var subtitle: String {
        let count = results.count
        let written = count == 1 ? String(localized: "\(count) word written") : String(localized: "\(count) words written")
        let hinted = results.filter { $0.hintsUsed > 0 }.count
        guard hinted > 0 else {
            return written
        }
        return String(localized: "\(written) · \(hinted) needed a hint")
    }

    private func detail(for result: WordPracticeState.WordResult) -> String {
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
