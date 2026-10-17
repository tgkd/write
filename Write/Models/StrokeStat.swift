struct StrokeStat: Codable, Equatable, Sendable {
    var attempts = 0
    var evidence = MissEvidence()
    var drawnInstead: [Int] = []
    var undone = 0
    var firstHint: String?
    var acceptedHint: String?
}

extension StrokeStat {
    private enum CodingKeys: String, CodingKey {
        case attempts
        case evidence
        case drawnInstead
        case undone
        case firstHint
        case acceptedHint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attempts = try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        evidence = try container.decodeIfPresent(MissEvidence.self, forKey: .evidence) ?? MissEvidence()
        drawnInstead = try container.decodeIfPresent([Int].self, forKey: .drawnInstead) ?? []
        undone = try container.decodeIfPresent(Int.self, forKey: .undone) ?? 0
        firstHint = try container.decodeIfPresent(String.self, forKey: .firstHint)
        acceptedHint = try container.decodeIfPresent(String.self, forKey: .acceptedHint)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if attempts != 0 {
            try container.encode(attempts, forKey: .attempts)
        }
        if !evidence.isEmpty {
            try container.encode(evidence, forKey: .evidence)
        }
        if !drawnInstead.isEmpty {
            try container.encode(drawnInstead, forKey: .drawnInstead)
        }
        if undone != 0 {
            try container.encode(undone, forKey: .undone)
        }
        try container.encodeIfPresent(firstHint, forKey: .firstHint)
        try container.encodeIfPresent(acceptedHint, forKey: .acceptedHint)
    }
}
