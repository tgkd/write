import Foundation

struct KanjiComponent: Codable, Equatable, Sendable {
    let element: String?
    let position: String?
    let strokes: [KanjiStroke]
}

struct KanjiData: Codable, Equatable, Sendable {
    let codePoint: String
    let element: String?
    let strokes: [KanjiStroke]
    let components: [KanjiComponent]

    var character: Character {
        guard let scalar = UInt32(codePoint, radix: 16),
              let unicode = Unicode.Scalar(scalar) else {
            fatalError("Invalid code point: \(codePoint)")
        }
        return Character(unicode)
    }
}
