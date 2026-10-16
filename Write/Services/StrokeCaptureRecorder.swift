import Foundation

@MainActor
final class StrokeCaptureRecorder {
    static let shared = StrokeCaptureRecorder()

    var isEnabled: Bool {
        false
    }

    func record(_ stroke: CapturedStroke) {}
}
