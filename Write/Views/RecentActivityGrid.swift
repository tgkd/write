import SwiftUI

struct RecentActivityGrid: View {
    let days: [PracticeStats.DayActivity]
    let today: Date
    let calendar: Calendar

    private static let weekCount = 5
    private static let maxDaySize: CGFloat = 44
    private static let strongFill = 0.75

    private struct Cell: Identifiable {
        let day: Date
        let completions: Int?
        var id: Date { day }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let cells = makeCells()
        let past = cells.compactMap(\.completions)
        let activeCount = past.filter { $0 > 0 }.count
        let peak = max(past.max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last month")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("^[\(activeCount) day](inflect: true) practiced")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(cells) { cell in
                    dayCell(cell, peak: peak)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recent activity")
            .accessibilityValue(summary(of: cells))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func dayCell(_ cell: Cell, peak: Int) -> some View {
        let strength = fillStrength(cell.completions, peak: peak)
        let isToday = calendar.isDate(cell.day, inSameDayAs: today)
        return ZStack {
            Circle()
                .fill(strength > 0 ? Color.accentColor.opacity(strength) : Color.clear)
            Text(cell.day, format: .dateTime.day())
                .font(.subheadline.monospacedDigit())
                .fontWeight(strength >= Self.strongFill ? .semibold : .regular)
                .foregroundStyle(textStyle(cell, strength: strength))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .overlay {
            if isToday {
                Circle()
                    .strokeBorder(Color.primary, lineWidth: 1.5)
                    .padding(-3)
            }
        }
        .frame(maxWidth: Self.maxDaySize)
        .aspectRatio(1, contentMode: .fit)
    }

    private func fillStrength(_ completions: Int?, peak: Int) -> Double {
        guard let completions, completions > 0 else { return 0 }
        return 0.3 + 0.7 * Double(completions) / Double(peak)
    }

    private func textStyle(_ cell: Cell, strength: Double) -> AnyShapeStyle {
        if cell.completions == nil {
            return AnyShapeStyle(.tertiary)
        }
        if strength >= Self.strongFill {
            return AnyShapeStyle(Color.white)
        }
        return AnyShapeStyle(.primary)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func makeCells() -> [Cell] {
        let lastDay = calendar.startOfDay(for: today)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: lastDay)?.start ?? lastDay
        guard let gridStart = calendar.date(byAdding: .day, value: -7 * (Self.weekCount - 1), to: weekStart) else {
            return []
        }
        let completionsByDay = Dictionary(days.map { ($0.day, $0.completions) }, uniquingKeysWith: +)
        return (0..<(7 * Self.weekCount)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            let completions: Int? = day > lastDay ? nil : (completionsByDay[day] ?? 0)
            return Cell(day: day, completions: completions)
        }
    }

    private func summary(of cells: [Cell]) -> String {
        let past = cells.filter { $0.completions != nil }
        let active = past.filter { ($0.completions ?? 0) > 0 }
        let total = active.reduce(0) { $0 + ($1.completions ?? 0) }
        let overview = String(localized: "Practiced on \(active.count) of \(past.count) days, \(total) completed")
        guard let latest = active.last else {
            return overview
        }
        let latestLabel = label(for: latest.day, completions: latest.completions ?? 0)
        return String(localized: "\(overview). Latest: \(latestLabel)")
    }

    private func label(for day: Date, completions: Int) -> String {
        let date = day.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "\(date): \(completions) completed")
    }
}
