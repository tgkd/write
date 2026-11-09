import SwiftUI

struct WritingCellView: View {
    let cell: WritingSession.Cell
    let mode: WritingMode
    let isFinished: Bool
    let isActive: Bool
    @ObservedObject var ink: WritingInkStore
    @EnvironmentObject private var settings: AppSettings
    @State private var canvasView: DrawingCanvasView?
    @State private var referenceView: KanjiReferenceView?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if settings.showPracticeGrid, cell.kanjiData != nil {
                PracticeGridView()
            }
            if cell.kanjiData == nil {
                Text(String(cell.character))
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("writing.prefilled.\(cell.id)")
            } else if isFinished {
                if let image = ink.snapshots[cell.id] {
                    Image(uiImage: image).resizable().scaledToFit()
                        .accessibilityLabel("Written character")
                        .accessibilityIdentifier("writing.ink.\(cell.id)")
                }
            } else if mode == .free, let data = cell.kanjiData {
                KanjiReferenceRepresentable(kanjiData: data, lineWidth: settings.maskPathWidth,
                                             palette: settings.colorPalette, isHidden: false, referenceView: $referenceView)
                    .allowsHitTesting(false)
                DrawingCanvasRepresentable(
                    onStrokeBegan: { [weak ink, id = cell.id] _ in ink?.select(id) },
                    onStrokeCompleted: { [weak ink, id = cell.id] _, _ in
                        ink?.noteStroke(in: id)
                        ink?.snapshot(id)
                    },
                    allowedTouchTypes: settings.allowedTouchTypes,
                    pressureSensitivity: settings.pressureSensitivity, tiltSensitivity: settings.tiltSensitivity,
                    smoothingStrength: settings.smoothingStrength, brushThickness: settings.brushThickness,
                    captureContext: StrokeCaptureContext(codePoint: data.codePoint, mode: "free-writing-trace"),
                    retainedCanvasView: ink.canvas(for: cell.id), canvasIdentifier: "writing.canvas.\(cell.id)",
                    installsPencilInteraction: false, canvasView: $canvasView
                )
            } else if mode == .trace, let data = cell.kanjiData {
                KanjiReferenceRepresentable(kanjiData: data, lineWidth: settings.maskPathWidth,
                                             palette: settings.colorPalette, isHidden: false, referenceView: $referenceView)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive || (mode == .free && ink.selectedCellID == cell.id) ? Color.accentColor : Color(.systemGray4), lineWidth: 2)
        }
    }
}
