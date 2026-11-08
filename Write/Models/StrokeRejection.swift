import Foundation

enum StrokeRejection: Equatable, Sendable {
    case shape
    case position
    case shapeAndPosition
    case size
    case wrongOrder(drawnStroke: Int, expectedStroke: Int)
    case outOfFrame

    var notice: String {
        switch self {
        case .shape:
            return String(localized: "The shape doesn't match this stroke.")
        case .position:
            return String(localized: "Too far from where this stroke belongs.")
        case .shapeAndPosition:
            return String(localized: "Wrong shape, and too far from where this stroke belongs.")
        case .size:
            return String(localized: "This stroke is too big or too small.")
        case .wrongOrder(let drawn, let expected):
            return String(localized: "Right shape, wrong order: that was stroke \(drawn + 1). Draw stroke \(expected + 1) first.")
        case .outOfFrame:
            return String(localized: "That stroke went outside the box. Keep it inside.")
        }
    }
}
