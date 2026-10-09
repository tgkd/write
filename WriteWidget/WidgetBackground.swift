import SwiftUI
import WidgetKit

struct WidgetBackground: ViewModifier {
    @Environment(\.widgetFamily) private var family

    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content
                .containerBackground(for: .widget) { background }
        } else if isAccessory {
            content
        } else {
            content
                .padding()
                .background(background)
        }
    }

    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return false
        }
    }

    private var background: Color {
        isAccessory ? .clear : Color(.systemBackground)
    }
}
