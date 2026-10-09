import Foundation

struct DailyKanji: Codable, Equatable, Hashable, Sendable {
    let codePoint: String
    let character: String
    let meanings: [String]
    var onYomi: String? = nil
    var kunYomi: String? = nil
    let strokeCount: Int
    let jlpt: Int

    var primaryMeaning: String {
        meanings.first ?? ""
    }

    var strokeCountLabel: String {
        strokeCount == 1 ? "1 stroke" : "\(strokeCount) strokes"
    }
}
