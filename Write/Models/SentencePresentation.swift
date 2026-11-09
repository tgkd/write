import Foundation

struct SentencePresentation: Codable, Equatable, Sendable {
    let version: Int
    let groups: [[Int]]
    var emptyIssues: [SpellingIssue]? = nil

    struct SpellingIssue: Codable, Equatable, Sendable {
        let tokenIndex: Int
        let reason: String
    }

    var allowsEmpty: Bool {
        version == 1 && emptyIssues?.isEmpty == true
    }

    func validatedGroups(tokenCount: Int) -> [[Int]]? {
        guard version == 1, !groups.isEmpty, groups.allSatisfy({ !$0.isEmpty }),
              groups.flatMap({ $0 }) == Array(0..<tokenCount) else {
            return nil
        }
        return groups
    }
}
