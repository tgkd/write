import SwiftUI

struct RecentActivityGrid: View {
    let days: [PracticeStats.DayActivity]

    private static let columnCount = 7
    private static let maxCellSize: CGFloat = 44
    private static let cellSpacing: CGFloat = 4
    private static let maxGridWidth = CGFloat(columnCount) * maxCellSize + CGFloat(columnCount - 1) * cellSpacing

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Self.cellSpacing), count: Self.columnCount)

    var body: some View {
        let peak = max(days.map(\.completions).max() ?? 0, 1)
        LazyVGrid(columns: columns, spacing: Self.cellSpacing) {
            ForEach(days, id: \.day) { day in
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill(for: day.completions, peak: peak))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .frame(maxWidth: Self.maxGridWidth)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recent activity")
        .accessibilityValue(summary)
    }

    private var summary: String {
        let activeDays = days.filter { $0.completions > 0 }
        let total = activeDays.reduce(0) { $0 + $1.completions }
        let overview = String(localized: "Practiced on \(activeDays.count) of \(days.count) days, \(total) completed")
        guard let latest = activeDays.max(by: { $0.day < $1.day }) else {
            return overview
        }
        let latestLabel = label(for: latest)
        return String(localized: "\(overview). Latest: \(latestLabel)")
    }

    private func fill(for completions: Int, peak: Int) -> Color {
        guard completions > 0 else { return Color(.systemGray6) }
        let strength = 0.3 + 0.7 * Double(completions) / Double(peak)
        return Color.accentColor.opacity(strength)
    }

    private func label(for day: PracticeStats.DayActivity) -> String {
        let date = day.day.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "\(date): \(day.completions) completed")
    }
}
