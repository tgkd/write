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
                        Text("Session")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)

                        HStack {
                            Text("Kanji per session")
                            Spacer()
                            Stepper(
                                "\(settings.sessionCount)",
                                value: $settings.sessionCount,
                                in: 3...30,
                                step: 1
                            )
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

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

                    if DeviceContext.isIPad {
                        iPadSettingsSection
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Acknowledgments")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.leading, 4)

                        VStack(alignment: .leading, spacing: 12) {
                            acknowledgmentRow(
                                title: "KanjiVG",
                                detail: "Stroke data — CC BY-SA 3.0",
                                url: "https://kanjivg.tagaini.net/"
                            )
                            Divider()
                            acknowledgmentRow(
                                title: "KANJIDIC2",
                                detail: "Readings & meanings — CC BY-SA 4.0",
                                url: "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project"
                            )
                        }
                        .padding(16)
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

    private var iPadSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple Pencil")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                HStack {
                    Text("Pressure Sensitivity")
                    Spacer()
                    Picker("", selection: $settings.pressureSensitivity) {
                        ForEach(PressureSensitivity.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().padding(.leading, 16)

                Toggle("Allow Finger Drawing", isOn: $settings.allowFingerDrawing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Notebook")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
                .padding(.top, 8)

            VStack(spacing: 0) {
                Toggle("Crosshair Guidelines", isOn: $settings.showCrosshairGuidelines)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider().padding(.leading, 16)

                HStack {
                    Text("Cells per Row")
                    Spacer()
                    Stepper(
                        "\(settings.cellsPerRow)",
                        value: $settings.cellsPerRow,
                        in: 6...10,
                        step: 2
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func acknowledgmentRow(title: String, detail: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
