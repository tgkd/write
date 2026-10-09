import SwiftUI

private struct StudyEligibilityKey: EnvironmentKey {
    static let defaultValue = StudyEligibility()
}

extension EnvironmentValues {
    var studyEligibility: StudyEligibility {
        get { self[StudyEligibilityKey.self] }
        set { self[StudyEligibilityKey.self] = newValue }
    }
}
