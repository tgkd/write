enum StrokeRejection: Equatable, Sendable {
    case shape
    case wrongOrder(drawnStroke: Int, expectedStroke: Int)

    var notice: String? {
        switch self {
        case .shape:
            return nil
        case .wrongOrder(let drawn, let expected):
            return "Right shape, wrong order: that was stroke \(drawn + 1). Draw stroke \(expected + 1) first."
        }
    }
}
