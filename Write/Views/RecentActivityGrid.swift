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
                    .accessibilityLabel(label(for: day))
            }
        }
        .frame(maxWidth: Self.maxGridWidth)
        .frame(maxWidth: .infinity, alignment: .leading)
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
