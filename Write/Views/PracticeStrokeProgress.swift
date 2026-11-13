import Foundation

extension PracticeState {
    var strokeProgressDescription: String {
        if isComplete {
            return String(localized: "Complete")
        }
        let total = totalStrokes
        let current = min(currentStrokeIndex + 1, total)
        return String(localized: "Stroke \(current) of \(total)")
    }
}
