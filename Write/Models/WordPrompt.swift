import CryptoKit
import Foundation

struct WordPrompt: Codable, Equatable, Identifiable, Sendable {
    private struct RevisionContent: Encodable {
        let before: String
        let reading: String
        let after: String
        let gloss: String
        let segments: [Segment]
    }

    enum Segment: Codable, Equatable, Sendable {
        case kanji(String)
        case kana(String)

        private enum CodingKeys: String, CodingKey {
            case kanji
            case kana
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let kanji = try container.decodeIfPresent(String.self, forKey: .kanji) {
                self = .kanji(kanji)
                return
            }
            self = .kana(try container.decode(String.self, forKey: .kana))
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .kanji(let text):
                try container.encode(text, forKey: .kanji)
            case .kana(let text):
                try container.encode(text, forKey: .kana)
            }
        }

        var text: String {
            switch self {
            case .kanji(let text), .kana(let text):
                return text
            }
        }

        var isKanji: Bool {
            if case .kanji = self {
                return true
            }
            return false
        }

        var kanjiCharacter: Character? {
            guard case .kanji(let text) = self, text.count == 1 else {
                return nil
            }
            return text.first
        }
    }

    let id: String
    let before: String
    let reading: String
    let after: String
    let gloss: String
    let segments: [Segment]
    let notes: String
    var translation: String? = nil
    var tokens: [SentenceToken]? = nil

    var sentence: String {
        before + reading + after
    }

    var answer: String {
        segments.map(\.text).joined()
    }

    var kanjiSegmentIndices: [Int] {
        segments.indices.filter { segments[$0].isKanji }
    }

    var revision: String {
        let content = RevisionContent(before: before, reading: reading, after: after, gloss: gloss, segments: segments)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(content)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func slotID(segmentIndex: Int) -> String {
        "\(id)-\(segmentIndex)"
    }
}
