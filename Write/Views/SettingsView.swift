import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    GuideWidthControl(
                        width: settings.maskPathWidth,
                        palette: settings.colorPalette,
                        onChanged: { settings.maskPathWidth = $0 }
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color Palette")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            ForEach(ColorPalette.allCases, id: \.self) { palette in
                                paletteRow(palette)
                                if palette != ColorPalette.allCases.last {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func paletteRow(_ palette: ColorPalette) -> some View {
        Button {
            settings.colorPalette = palette
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Color(uiColor: palette.strokeOrderColor(index: i, total: 5)))
                            .frame(width: 16, height: 16)
                    }
                }
                Text(palette.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if settings.colorPalette == palette {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

private struct GuideWidthControl: View {
    let palette: ColorPalette
    let onChanged: (CGFloat) -> Void
    @State private var sliderWidth: CGFloat

    init(width: CGFloat, palette: ColorPalette, onChanged: @escaping (CGFloat) -> Void) {
        self.palette = palette
        self.onChanged = onChanged
        _sliderWidth = State(initialValue: width)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guide Width")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Slider(
                        value: $sliderWidth,
                        in: AppSettings.maskPathWidthRange,
                        step: 0.5
                    ) { editing in
                        if !editing {
                            onChanged(sliderWidth)
                        }
                    }
                    Text(String(format: "%.0f", sliderWidth))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }

                RoundedRectangle(cornerRadius: sliderWidth / 2)
                    .fill(Color(uiColor: palette.strokeOrderColor(index: 0, total: 3)))
                    .frame(height: sliderWidth)
                    .opacity(0.5)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
