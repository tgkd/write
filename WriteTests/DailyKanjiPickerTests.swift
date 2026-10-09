import XCTest
@testable import Write

final class DailyKanjiPickerTests: XCTestCase {

    private let entries = [
        DailyKanji(codePoint: "4e00", character: "一", meanings: ["one"], strokeCount: 1, jlpt: 5),
        DailyKanji(codePoint: "4e8c", character: "二", meanings: ["two"], strokeCount: 2, jlpt: 5),
        DailyKanji(codePoint: "4e09", character: "三", meanings: ["three"], strokeCount: 3, jlpt: 5),
    ]

    private let tokyo = DailyKanjiPickerTests.makeCalendar("Asia/Tokyo")
    private let losAngeles = DailyKanjiPickerTests.makeCalendar("America/Los_Angeles")

    private static func makeCalendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
        in calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    func testFirstDayIsDayZeroFromMidnightToMidnight() {
        let picker = DailyKanjiPicker(entries: entries, calendar: tokyo)
        let midnight = date(2026, 1, 1, in: tokyo)
        let lastSecond = date(2026, 1, 1, 23, 59, 59, in: tokyo)

        XCTAssertEqual(picker.dayNumber(for: midnight), 0)
        XCTAssertEqual(picker.dayNumber(for: lastSecond), 0)
        XCTAssertEqual(picker.kanji(for: midnight), entries[0])
        XCTAssertEqual(picker.kanji(for: lastSecond), entries[0])
    }

    func testNextDaysAdvanceAndWrap() {
        let picker = DailyKanjiPicker(entries: entries, calendar: tokyo)
        let secondDay = date(2026, 1, 2, in: tokyo)
        let fourthDay = date(2026, 1, 4, in: tokyo)

        XCTAssertEqual(picker.dayNumber(for: secondDay), 1)
        XCTAssertEqual(picker.kanji(for: secondDay), entries[1])
        XCTAssertEqual(picker.dayNumber(for: fourthDay), 3)
        XCTAssertEqual(picker.kanji(for: fourthDay), entries[0])
    }

    func testDayBeforeEpochUsesNonNegativeModulo() {
        let picker = DailyKanjiPicker(entries: entries, calendar: tokyo)
        let dayBefore = date(2025, 12, 31, 12, in: tokyo)

        XCTAssertEqual(picker.dayNumber(for: dayBefore), -1)
        XCTAssertEqual(picker.kanji(for: dayBefore), entries[2])
    }

    func testSeparatePickersAgreeOnEveryDay() {
        let first = DailyKanjiPicker(entries: entries, calendar: tokyo)
        let second = DailyKanjiPicker(entries: entries, calendar: tokyo)
        let start = date(2026, 3, 1, 9, in: tokyo)

        for offset in 0..<30 {
            let day = tokyo.date(byAdding: .day, value: offset, to: start)!
            XCTAssertEqual(first.kanji(for: day), second.kanji(for: day))
        }
    }

    func testSameInstantCanFallOnDifferentLocalDays() {
        let tokyoPicker = DailyKanjiPicker(entries: entries, calendar: tokyo)
        let losAngelesPicker = DailyKanjiPicker(entries: entries, calendar: losAngeles)
        let instant = date(2026, 1, 2, 1, in: tokyo)

        XCTAssertEqual(tokyoPicker.dayNumber(for: instant), 1)
        XCTAssertEqual(losAngelesPicker.dayNumber(for: instant), 0)
        XCTAssertEqual(tokyoPicker.kanji(for: instant), entries[1])
        XCTAssertEqual(losAngelesPicker.kanji(for: instant), entries[0])
    }

    func testDaylightSavingDaysCountAsOneDay() {
        let picker = DailyKanjiPicker(entries: entries, calendar: losAngeles)
        let beforeSpringForward = date(2026, 3, 8, in: losAngeles)
        let afterSpringForward = date(2026, 3, 9, in: losAngeles)
        let beforeFallBack = date(2026, 11, 1, in: losAngeles)
        let afterFallBack = date(2026, 11, 2, in: losAngeles)

        XCTAssertEqual(picker.dayNumber(for: afterSpringForward) - picker.dayNumber(for: beforeSpringForward), 1)
        XCTAssertEqual(picker.dayNumber(for: afterFallBack) - picker.dayNumber(for: beforeFallBack), 1)
    }

    func testEmptyPickerReturnsNil() {
        let picker = DailyKanjiPicker(entries: [], calendar: tokyo)

        XCTAssertNil(picker.kanji(for: date(2026, 1, 1, in: tokyo)))
    }

    func testTimelineDatesStartNowThenFollowLocalMidnights() {
        let picker = DailyKanjiPicker(entries: entries, calendar: tokyo)
        let now = date(2026, 1, 1, 15, 30, in: tokyo)

        let dates = picker.timelineDates(from: now, days: 7)

        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(dates.first, now)
        for (offset, timelineDate) in dates.enumerated().dropFirst() {
            XCTAssertEqual(timelineDate, date(2026, 1, 1 + offset, in: tokyo))
        }
        for (offset, timelineDate) in dates.enumerated() {
            XCTAssertEqual(picker.kanji(for: timelineDate), entries[offset % entries.count])
        }
    }
}
