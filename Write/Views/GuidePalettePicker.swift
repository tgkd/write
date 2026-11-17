import SwiftUI

struct GuidePalettePicker: View {
    @Binding var selection: ColorPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guide Colors")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(ColorPalette.allCases, id: \.self) { palette in
                    row(palette)
                    if palette != ColorPalette.allCases.last {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func row(_ palette: ColorPalette) -> some View {
        Button {
            selection = palette
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Color(uiColor: palette.strokeOrderColor(index: i, total: 5)))
                            .frame(width: 16, height: 16)
                    }
                }
                .accessibilityHidden(true)
                Text(palette.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if selection == palette {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityAddTraits(selection == palette ? .isSelected : [])
        .accessibilityIdentifier("guidePalette.\(palette.rawValue)")
    }
}
