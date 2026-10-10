import SwiftUI

struct PracticeProgressView: View {
    let dataStore: KanjiDataStore

    @EnvironmentObject private var history: PracticeHistoryStore
    @EnvironmentObject private var settings: AppSettings

    private static let dayCount = 35

    var body: some View {
        let stats = PracticeStats(
            records: history.records,
            today: Date(),
            calendar: .current,
            dayCount: Self.dayCount
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if history.unsavedCount > 0 {
                    unsavedBanner
                }
                countsRow(stats)
                recentSection(stats)
                reviewSection(stats)
            }
            .padding()
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var unsavedBanner: some View {
        HStack {
            Text("Some completed practice hasn't been saved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                history.retryUnsaved()
            }
            .font(.subheadline.weight(.medium))
        }
    }

    private func countsRow(_ stats: PracticeStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                countTile(value: stats.practicedDays, label: "Days")
                countTile(value: stats.completedRuns, label: "Completed")
                countTile(value: stats.distinctKanji, label: "Characters")
            }
            Text("Completed practice only. Notebook writing isn't counted.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func countTile(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("count.\(label)")
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recentSection(_ stats: PracticeStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Last \(Self.dayCount / 7) weeks")
            RecentActivityGrid(days: stats.recentDays)
        }
    }

    private func reviewSection(_ stats: PracticeStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Review")
                Spacer()
                if !stats.review.isEmpty {
                    NavigationLink(value: SessionRoute.review(stats.review, count: settings.sessionCount)) {
                        Label("Recall these", systemImage: "play.fill")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
            if stats.review.isEmpty {
                Text("Characters you needed a hint or retries for in Recall appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(stats.review, id: \.codePoint) { item in
                        reviewRow(item)
                        Divider()
                    }
                }
            }
        }
    }

    private func reviewRow(_ item: PracticeStats.ReviewItem) -> some View {
        let kanji = dataStore.lookup(codePoint: item.codePoint)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kanji.map(cueText) ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(reasonText(item.reason))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.lastPracticed.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private func cueText(_ kanji: KanjiData) -> String {
        switch kanji.script {
        case .hiragana, .katakana:
            return "\(kanji.romaji ?? "") · \(kanji.script.displayName)"
        case .kanji:
            let meanings = (kanji.meanings ?? []).prefix(RecallEligibility.meaningsShown)
            if !meanings.isEmpty {
                return meanings.joined(separator: ", ")
            }
            return ((kanji.onYomi ?? []) + (kanji.kunYomi ?? [])).joined(separator: "、 ")
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func reasonText(_ reason: PracticeStats.Reason) -> String {
        switch reason {
        case .usedHint:
            return "Used a hint"
        case .neededRetries(let count):
            return "\(count) retr\(count == 1 ? "y" : "ies")"
        }
    }
}
