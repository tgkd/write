import SwiftUI
import UIKit

struct UITestingSizeClassToggle: ViewModifier {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-uiTestingSizeClassToggle")

    func body(content: Content) -> some View {
        if Self.isEnabled, #available(iOS 17, *) {
            content.overlay(alignment: .bottomLeading) {
                Button("Toggle width") {
                    Self.toggle()
                }
                .accessibilityIdentifier("uiTesting.sizeClassToggle")
            }
        } else {
            content
        }
    }

    @available(iOS 17, *)
    @MainActor
    private static func toggle() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            let isCompact = window.traitCollection.horizontalSizeClass == .compact
            window.traitOverrides.horizontalSizeClass = isCompact ? .regular : .compact
        }
    }
}
