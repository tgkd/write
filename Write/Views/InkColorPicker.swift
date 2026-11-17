import SwiftUI

struct InkColorPicker: View {
    @Binding var selection: InkColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ink Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(InkColor.allCases, id: \.self) { ink in
                    row(ink)
                    if ink != InkColor.allCases.last {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func row(_ ink: InkColor) -> some View {
        Button {
            selection = ink
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(uiColor: ink.color))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text(ink.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if selection == ink {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityAddTraits(selection == ink ? .isSelected : [])
        .accessibilityIdentifier("inkColor.\(ink.rawValue)")
    }
}
