import Foundation

enum CharacterFilter: Hashable, Sendable {
    case all
    case hiragana
    case katakana
    case jlpt(Int)
    case schoolGrade(Int)
    case otherJoyo

    enum Scheme: Hashable, CaseIterable, Sendable {
        case jlpt
        case school

        var label: String {
            switch self {
            case .jlpt: return "JLPT"
            case .school: return String(localized: "School")
            }
        }

        var levels: [CharacterFilter] {
            switch self {
            case .jlpt: return [.jlpt(5), .jlpt(4), .jlpt(3), .jlpt(2), .jlpt(1)]
            case .school: return (1...6).map { .schoolGrade($0) } + [.otherJoyo]
            }
        }
    }

    private static let secondaryJoyoGrade = 8

    var label: String {
        switch self {
        case .all: return String(localized: "All")
        case .hiragana: return String(localized: "Hiragana")
        case .katakana: return String(localized: "Katakana")
        case .jlpt(let level): return "N\(level)"
        case .schoolGrade(let grade): return String(localized: "Grade \(grade)")
        case .otherJoyo: return String(localized: "Other Jōyō")
        }
    }

    var scheme: Scheme? {
        switch self {
        case .all, .hiragana, .katakana: return nil
        case .jlpt: return .jlpt
        case .schoolGrade, .otherJoyo: return .school
        }
    }

    func includes(_ kanji: KanjiData) -> Bool {
        switch self {
        case .all: return true
        case .hiragana: return kanji.script == .hiragana
        case .katakana: return kanji.script == .katakana
        case .jlpt(let level): return kanji.jlpt == level
        case .schoolGrade(let grade): return kanji.grade == grade
        case .otherJoyo: return kanji.grade == Self.secondaryJoyoGrade
        }
    }

    static let scriptFilters: [CharacterFilter] = [.all, .hiragana, .katakana]

    static func pickerOrder(for scheme: Scheme) -> [CharacterFilter] {
        scriptFilters + scheme.levels
    }
}
