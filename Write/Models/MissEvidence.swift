struct MissEvidence: Codable, Equatable, Sendable {
    var shape = 0
    var position = 0
    var proportion = 0
    var order = 0
    var notEvaluated = 0
    var disputed = 0
    var boundary = 0

    var isEmpty: Bool {
        self == MissEvidence()
    }

    mutating func record(_ result: StrokeValidationResult) {
        if result.failedBoundary {
            boundary += 1
        }
        if result.wrongOrderCandidate != nil {
            order += 1
            return
        }
        if result.passedGeometry {
            return
        }
        let evidence = result.evidence
        if evidence.shapePassed == nil, evidence.positionPassed == nil, evidence.proportionPassed == nil {
            notEvaluated += 1
            return
        }
        if evidence.shapePassed == false {
            shape += 1
        }
        if evidence.positionPassed == false {
            position += 1
        }
        if evidence.proportionPassed == false {
            proportion += 1
        }
    }
}

extension MissEvidence {
    private enum CodingKeys: String, CodingKey {
        case shape
        case position
        case proportion
        case order
        case notEvaluated
        case disputed
        case boundary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shape = try container.decodeIfPresent(Int.self, forKey: .shape) ?? 0
        position = try container.decodeIfPresent(Int.self, forKey: .position) ?? 0
        proportion = try container.decodeIfPresent(Int.self, forKey: .proportion) ?? 0
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        notEvaluated = try container.decodeIfPresent(Int.self, forKey: .notEvaluated) ?? 0
        disputed = try container.decodeIfPresent(Int.self, forKey: .disputed) ?? 0
        boundary = try container.decodeIfPresent(Int.self, forKey: .boundary) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let counts: [(CodingKeys, Int)] = [
            (.shape, shape),
            (.position, position),
            (.proportion, proportion),
            (.order, order),
            (.notEvaluated, notEvaluated),
            (.disputed, disputed),
            (.boundary, boundary),
        ]
        for (key, count) in counts where count != 0 {
            try container.encode(count, forKey: key)
        }
    }
}
