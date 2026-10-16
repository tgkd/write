struct MissEvidence: Codable, Equatable, Sendable {
    var shape = 0
    var position = 0
    var proportion = 0
    var order = 0
    var notEvaluated = 0
    var disputed = 0
}

extension MissEvidence {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shape = try container.decodeIfPresent(Int.self, forKey: .shape) ?? 0
        position = try container.decodeIfPresent(Int.self, forKey: .position) ?? 0
        proportion = try container.decodeIfPresent(Int.self, forKey: .proportion) ?? 0
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        notEvaluated = try container.decodeIfPresent(Int.self, forKey: .notEvaluated) ?? 0
        disputed = try container.decodeIfPresent(Int.self, forKey: .disputed) ?? 0
    }
}
