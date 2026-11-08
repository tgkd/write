import SwiftUI

struct PracticeModelView: View {
    let kanji: KanjiData
    let showsGrid: Bool

    private static let inkRatio: CGFloat = 0.022

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                if showsGrid {
                    PracticeGridView()
                }
                strokesPath(in: geometry.size)
                    .stroke(
                        Color.primary,
                        style: StrokeStyle(lineWidth: side * Self.inkRatio, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .accessibilityElement()
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(kanji.text)
        .accessibilityIdentifier("answerGlyph")
    }

    private func strokesPath(in size: CGSize) -> Path {
        let transform = StrokeRenderer.scaleTransform(to: size)
        let path = CGMutablePath()
        for stroke in kanji.strokes {
            if let parsed = try? StrokeRenderer.createPath(from: stroke.pathData) {
                path.addPath(parsed, transform: transform)
            }
        }
        return Path(path)
    }
}
