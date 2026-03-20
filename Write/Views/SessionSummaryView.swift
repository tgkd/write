import SwiftUI

struct SessionSummaryView: View {
    let results: [SessionState.KanjiResult]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Session Complete")
                    .font(.title2.weight(.semibold))
                Text("\(results.count) kanji practiced")
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
                        if let meanings = result.kanjiData.meanings, !meanings.isEmpty {
                            Text(meanings.prefix(2).joined(separator: ", "))
                                .font(.subheadline)
                        }
                        Text("\(result.kanjiData.strokes.count) strokes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if result.attemptCount == 0 {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    } else {
                        Text("\(result.attemptCount) miss\(result.attemptCount == 1 ? "" : "es")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)

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
}
