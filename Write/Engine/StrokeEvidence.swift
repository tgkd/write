struct StrokeEvidence: Equatable, Sendable {
    var shapePassed: Bool?
    var positionPassed: Bool?
    var proportionPassed: Bool?
    var boundaryPassed: Bool?

    static let notEvaluated = StrokeEvidence()
}
