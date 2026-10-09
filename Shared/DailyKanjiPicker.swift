import Foundation

struct DailyKanjiPicker: Sendable {
    private let entries: [DailyKanji]
    private let calendar: Calendar
    private let epoch: Date?

    init(entries: [DailyKanji], calendar: Calendar) {
        self.entries = entries
        self.calendar = calendar
        epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)).map(calendar.startOfDay(for:))
    }

    func dayNumber(for date: Date) -> Int {
        guard let epoch else {
            return 0
        }
        return calendar.dateComponents([.day], from: epoch, to: calendar.startOfDay(for: date)).day ?? 0
    }

    func kanji(for date: Date) -> DailyKanji? {
        guard !entries.isEmpty else {
            return nil
        }
        let count = entries.count
        return entries[((dayNumber(for: date) % count) + count) % count]
    }

    func timelineDates(from date: Date, days: Int) -> [Date] {
        let today = calendar.startOfDay(for: date)
        let followingDays = (1..<max(days, 1)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map(calendar.startOfDay(for:))
        }
        return [date] + followingDays
    }
}
