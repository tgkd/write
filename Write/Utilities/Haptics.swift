import UIKit

@MainActor
enum Haptics {
    enum Event {
        case unitCompleted
        case runCompleted
    }

    private static let canvasGenerators = NSMapTable<UIView, AnyObject>.weakToStrongObjects()

    static func play(_ event: Event, on view: UIView? = nil) {
        if #available(iOS 17.5, *), DeviceContext.isIPad, let host = hostView(for: view) {
            playOnPencil(event, host: host, source: view)
        } else {
            playOnDevice(event)
        }
    }

    static func prepare(on view: UIView) {
        guard #available(iOS 17.5, *), DeviceContext.isIPad else {
            return
        }
        for host in [view, hostView(for: nil)].compactMap({ $0 }) {
            canvasGenerator(for: host).prepare()
        }
    }

    private static func playOnDevice(_ event: Event) {
        switch event {
        case .unitCompleted:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .runCompleted:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    @available(iOS 17.5, *)
    private static func playOnPencil(_ event: Event, host: UIView, source: UIView?) {
        let generator = canvasGenerator(for: host)
        let location = location(of: source, in: host)
        switch event {
        case .unitCompleted:
            generator.alignmentOccurred(at: location)
        case .runCompleted:
            generator.pathCompleted(at: location)
        }
    }

    @available(iOS 17.5, *)
    private static func canvasGenerator(for host: UIView) -> UICanvasFeedbackGenerator {
        if let cached = canvasGenerators.object(forKey: host) as? UICanvasFeedbackGenerator {
            return cached
        }
        let generator = UICanvasFeedbackGenerator(view: host)
        canvasGenerators.setObject(generator, forKey: host)
        return generator
    }

    private static func hostView(for view: UIView?) -> UIView? {
        if let view, view.window != nil {
            return view
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func location(of source: UIView?, in host: UIView) -> CGPoint {
        guard let source, source.window != nil, source.window === host.window else {
            return CGPoint(x: host.bounds.midX, y: host.bounds.midY)
        }
        return source.convert(CGPoint(x: source.bounds.midX, y: source.bounds.midY), to: host)
    }
}
