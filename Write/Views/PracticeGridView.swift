import SwiftUI

struct PracticeGridView: View {
    private static let quarter = StrokeRenderer.kanjiVGSize / 4

    var body: some View {
        ZStack {
            PracticeGridLines(positions: [Self.quarter, Self.quarter * 3])
                .stroke(Color(.systemGray5), lineWidth: 1)
            PracticeGridLines(positions: [Self.quarter * 2])
                .stroke(Color(.systemGray4), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
