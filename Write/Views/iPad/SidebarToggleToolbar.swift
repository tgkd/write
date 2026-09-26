import SwiftUI

struct SidebarToggleToolbar: ViewModifier {
    @Binding var columnVisibility: NavigationSplitViewVisibility

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .toolbar(removing: .sidebarToggle)
                .toolbar { toggleItem }
        } else {
            content
                .toolbar { toggleItem }
        }
    }

    private var toggleItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
            } label: {
                Image(systemName: "sidebar.left")
            }
            .accessibilityLabel("Toggle Sidebar")
        }
    }
}
