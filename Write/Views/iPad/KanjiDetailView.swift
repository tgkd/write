import SwiftUI

struct KanjiDetailView: View {
    let kanji: KanjiData
    let onPractice: () -> Void
    let onNotebook: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(String(kanji.character))
                .font(.system(size: 120))

            readingsBlock

            metadataBlock

            Spacer()

            VStack(spacing: 12) {
                Button(action: onPractice) {
                    Label("Practice", systemImage: "pencil.tip")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onNotebook) {
                    Label("Notebook", systemImage: "book")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var readingsBlock: some View {
        VStack(spacing: 4) {
            if let on = kanji.onYomi, !on.isEmpty {
                Text(on.joined(separator: "、 "))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if let kun = kanji.kunYomi, !kun.isEmpty {
                Text(kun.joined(separator: "、 "))
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            if let meanings = kanji.meanings, !meanings.isEmpty {
                Text(meanings.prefix(4).joined(separator: ", "))
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
    }

    private var metadataBlock: some View {
        HStack(spacing: 24) {
            if let grade = kanji.grade {
                metadataItem(label: "Grade", value: "\(grade)")
            }
            if let jlpt = kanji.jlpt {
                metadataItem(label: "JLPT", value: "N\(jlpt)")
            }
            metadataItem(label: "Strokes", value: "\(kanji.strokes.count)")
            if let freq = kanji.freq {
                metadataItem(label: "Freq", value: "#\(freq)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func metadataItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.medium))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
