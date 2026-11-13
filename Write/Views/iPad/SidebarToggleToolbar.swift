import SwiftUI

struct SidebarToggleToolbar: ViewModifier {
    @Binding var columnVisibility: NavigationSplitViewVisibility

    func body(content: Content) -> some View {
        content
            .removingSystemSidebarToggle()
            .toolbar { toggleItem }
    }

    private var toggleItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
            } label: {
                Image(systemName: "sidebar.left")
            }
            .accessibilityLabel(toggleLabel)
            .accessibilityInputLabels([toggleLabel, "Sidebar"])
        }
    }

    private var toggleLabel: LocalizedStringKey {
        columnVisibility == .detailOnly ? "Show sidebar" : "Hide sidebar"
    }
}

extension View {
    @ViewBuilder
    func removingSystemSidebarToggle() -> some View {
        if #available(iOS 17.0, *) {
            toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }
}
