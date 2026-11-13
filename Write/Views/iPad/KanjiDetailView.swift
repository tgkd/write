import SwiftUI

struct KanjiDetailView: View {
    let kanji: KanjiData
    let onPractice: () -> Void
    let onNotebook: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                content
                    .padding(.vertical, 24)
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(kanji.text)
                .font(.system(size: 120))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(width: kanji.text.count > 1 ? 120 : nil)
                .accessibilityAddTraits(.isHeader)

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
            if let romaji = kanji.romaji {
                Text(romaji)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) { metadataItems }
            VStack(spacing: 12) { metadataItems }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var metadataItems: some View {
        if let grade = kanji.grade {
            metadataItem(label: "Grade", value: "\(grade)")
        }
        if let jlpt = kanji.jlpt {
            metadataItem(label: "JLPT", value: "N\(jlpt)")
        }
        metadataItem(label: "Strokes", value: "\(kanji.strokes.count)")
        if let freq = kanji.freq {
            metadataItem(label: "Freq", value: "#\(freq)")
                .accessibilityLabel("Frequency rank")
        }
    }

    private func metadataItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.medium))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}
