import XCTest
@testable import Write

@MainActor
final class StrokeCaptureTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StrokeCaptureTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func makeStroke(id: UUID = UUID(), x: Double = 1) -> CapturedStroke {
        CapturedStroke(
            id: id,
            codePoint: "6c34",
            mode: "guided",
            touchType: "pencil",
            canvasWidth: 320,
            canvasHeight: 320,
            samples: [
                CapturedSample(x: x, y: 2, t: 0, force: 0.5, altitude: 1.2),
                CapturedSample(x: x + 3, y: 4, t: 0.016, force: nil, altitude: nil)
            ]
        )
    }

    func testCapturedStrokeJSONRoundTrip() throws {
        let stroke = makeStroke()
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(CapturedStroke.self, from: data)
        XCTAssertEqual(decoded, stroke)
    }

    func testRecorderWritesAndOverwritesById() throws {
        let recorder = StrokeCaptureRecorder(directory: directory, isEnabled: true)
        let id = UUID()

        recorder.record(makeStroke(id: id, x: 1))
        let url = recorder.fileURL(for: id)
        let first = try JSONDecoder().decode(CapturedStroke.self, from: Data(contentsOf: url))
        XCTAssertEqual(first.samples.first?.x, 1)

        recorder.record(makeStroke(id: id, x: 9))
        let second = try JSONDecoder().decode(CapturedStroke.self, from: Data(contentsOf: url))
        XCTAssertEqual(second.samples.first?.x, 9)

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(files, ["\(id.uuidString).json"])
    }

    func testDisabledRecorderWritesNothing() {
        let recorder = StrokeCaptureRecorder(directory: directory, isEnabled: false)
        recorder.record(makeStroke())
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testSampleConversionKeepsOrderAndRelativeTime() {
        let canvasSamples = [
            BrushStroke.Sample(point: CGPoint(x: 10, y: 20), timestamp: 100.5, force: 0.25, altitude: 1.1),
            BrushStroke.Sample(point: CGPoint(x: 30, y: 40), timestamp: 100.516),
            BrushStroke.Sample(point: CGPoint(x: 50, y: 60), timestamp: 100.532, force: 0.75, altitude: 0.9)
        ]

        let samples = CapturedSample.samples(from: canvasSamples)

        XCTAssertEqual(samples.map(\.x), [10, 30, 50])
        XCTAssertEqual(samples.map(\.y), [20, 40, 60])
        XCTAssertEqual(samples[0].t, 0)
        XCTAssertEqual(samples[1].t, 0.016, accuracy: 1e-9)
        XCTAssertEqual(samples[2].t, 0.032, accuracy: 1e-9)
        XCTAssertEqual(samples[0].force, 0.25)
        XCTAssertEqual(samples[0].altitude ?? 0, 1.1, accuracy: 1e-9)
        XCTAssertNil(samples[1].force)
        XCTAssertNil(samples[1].altitude)
        XCTAssertEqual(samples[2].force, 0.75)
        XCTAssertEqual(samples[2].altitude ?? 0, 0.9, accuracy: 1e-9)
    }

    func testSampleConversionOfEmptyStroke() {
        XCTAssertTrue(CapturedSample.samples(from: []).isEmpty)
    }

    func testCapturedStrokeFromCanvasCapture() {
        let capture = CanvasStrokeCapture(
            id: UUID(),
            touchType: .direct,
            canvasSize: CGSize(width: 300, height: 250),
            samples: [BrushStroke.Sample(point: CGPoint(x: 1, y: 2), timestamp: 5)]
        )
        let context = StrokeCaptureContext(codePoint: "6c34", mode: "study")

        let stroke = CapturedStroke(capture: capture, context: context)

        XCTAssertEqual(stroke.id, capture.id)
        XCTAssertEqual(stroke.codePoint, "6c34")
        XCTAssertEqual(stroke.mode, "study")
        XCTAssertEqual(stroke.touchType, "finger")
        XCTAssertEqual(stroke.canvasWidth, 300)
        XCTAssertEqual(stroke.canvasHeight, 250)
        XCTAssertEqual(stroke.samples, [CapturedSample(x: 1, y: 2, t: 0, force: nil, altitude: nil)])
    }

    func testTouchTypeNames() {
        XCTAssertEqual(CapturedStroke.touchTypeName(.pencil), "pencil")
        XCTAssertEqual(CapturedStroke.touchTypeName(.direct), "finger")
        XCTAssertEqual(CapturedStroke.touchTypeName(.indirect), "other")
    }
}
