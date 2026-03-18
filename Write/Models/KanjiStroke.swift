import Foundation

struct KanjiStroke: Codable, Equatable, Sendable {
    let strokeNumber: Int
    let pathData: String
    let strokeType: String?
}
