import Foundation

struct SentenceToken: Codable, Equatable, Sendable {
    let surface: String
    let reading: String?
}
