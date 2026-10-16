import Foundation

@MainActor
final class StrokeCaptureRecorder {
    static let shared = StrokeCaptureRecorder()

    static let launchArgument = "-captureStrokes"
    static let defaultsKey = "captureStrokes"

    var isEnabled: Bool
    let directory: URL
    private let fileManager: FileManager

    init(directory: URL, isEnabled: Bool, fileManager: FileManager = .default) {
        self.directory = directory
        self.isEnabled = isEnabled
        self.fileManager = fileManager
    }

    private convenience init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let enabled = ProcessInfo.processInfo.arguments.contains(Self.launchArgument)
            || UserDefaults.standard.bool(forKey: Self.defaultsKey)
        self.init(directory: documents.appendingPathComponent("StrokeCaptures", isDirectory: true), isEnabled: enabled)
    }

    func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    func record(_ stroke: CapturedStroke) {
        guard isEnabled else {
            return
        }
        do {
            let data = try JSONEncoder().encode(stroke)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL(for: stroke.id), options: .atomic)
        } catch {
            return
        }
    }
}
