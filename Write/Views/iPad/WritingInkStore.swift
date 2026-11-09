import Combine
import UIKit

@MainActor
final class WritingInkStore: ObservableObject {
    @Published private(set) var selectedCellID: String?
    @Published private(set) var strokeCounts: [String: Int] = [:]
    @Published private(set) var snapshots: [String: UIImage] = [:]
    private var canvases: [String: DrawingCanvasView] = [:]

    func canvas(for id: String) -> DrawingCanvasView {
        if let canvas = canvases[id] {
            return canvas
        }
        let canvas = DrawingCanvasView()
        canvases[id] = canvas
        return canvas
    }

    func select(_ id: String) {
        selectedCellID = id
    }

    func noteStroke(in id: String) {
        strokeCounts[id] = canvases[id]?.strokeCount ?? 0
        canvases[id]?.accessibilityValue = String(strokeCounts[id] ?? 0)
    }

    var canUndo: Bool {
        guard let selectedCellID else {
            return false
        }
        return (strokeCounts[selectedCellID] ?? 0) > 0
    }

    func undo() {
        guard let selectedCellID, let canvas = canvases[selectedCellID] else {
            return
        }
        canvas.removeLastStroke()
        noteStroke(in: selectedCellID)
        if canvas.strokeCount == 0 {
            snapshots[selectedCellID] = nil
        } else {
            snapshot(selectedCellID)
        }
    }

    func clear() {
        guard let selectedCellID, let canvas = canvases[selectedCellID] else {
            return
        }
        canvas.clearAll()
        noteStroke(in: selectedCellID)
        snapshots[selectedCellID] = nil
    }

    func leavePhrase() {
        selectedCellID = nil
    }

    func snapshot(_ id: String) {
        guard let canvas = canvases[id], !canvas.bounds.isEmpty else {
            return
        }
        snapshots[id] = UIGraphicsImageRenderer(bounds: canvas.bounds).image { context in
            canvas.layer.render(in: context.cgContext)
        }
    }

    func clear(_ ids: [String]) {
        for id in ids {
            canvases[id]?.clearAll()
            snapshots[id] = nil
            noteStroke(in: id)
        }
        selectedCellID = nil
    }
}
