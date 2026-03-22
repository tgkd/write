import Foundation

struct NotebookRow: Equatable, Sendable {
    let kanjiData: KanjiData
    let cellCount: Int
}

struct CellCoordinate: Equatable, Hashable, Sendable {
    let row: Int
    let cell: Int
}

@MainActor
final class NotebookState: ObservableObject {
    @Published var rows: [NotebookRow]

    private(set) var cellsPerRow: Int

    init(kanjiList: [KanjiData], cellsPerRow: Int) {
        self.cellsPerRow = cellsPerRow
        self.rows = kanjiList.map { NotebookRow(kanjiData: $0, cellCount: cellsPerRow) }
    }

    func addRow(kanji: KanjiData) {
        rows.append(NotebookRow(kanjiData: kanji, cellCount: cellsPerRow))
    }

    func updateCellsPerRow(_ newValue: Int) {
        guard newValue != cellsPerRow else { return }
        cellsPerRow = newValue
        rows = rows.map { NotebookRow(kanjiData: $0.kanjiData, cellCount: newValue) }
    }
}
