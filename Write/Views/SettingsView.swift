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

                    gradingSection

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.leading, 4)

                        HStack {
                            Text("Kanji per session")
                                .accessibilityHidden(true)
                            Spacer()
                            Stepper(
                                "\(settings.sessionCount)",
                                value: $settings.sessionCount,
                                in: 3...30,
                                step: 1
                            )
                            .accessibilityLabel("Kanji per session")
                            .accessibilityValue("\(settings.sessionCount)")
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
                            .accessibilityAddTraits(.isHeader)
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

                    drawingSection

                    RecallCueSettingsSection()

                    SyncSettingsSection()

                    if DeviceContext.isIPad {
                        iPadSettingsSection
                    }

                    experimentalSection

                    rateRow
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Acknowledgments")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .accessibilityAddTraits(.isHeader)
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
                            Divider()
                            acknowledgmentRow(
                                title: "Tatoeba",
                                detail: "Example sentences — CC BY 2.0 FR",
                                url: "https://tatoeba.org/"
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

    private var gradingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grading")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 10) {
                Picker("Grading", selection: $settings.gradingStrictness) {
                    ForEach(GradingStrictness.allCases, id: \.self) { strictness in
                        Text(strictness.displayName).tag(strictness)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("gradingStrictness")

                Text("How closely strokes must match. Strict also checks stroke length.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Toggle("Explain rejected strokes", isOn: $settings.showRejectionReasons)
                    .accessibilityIdentifier("showRejectionReasons")

                Text("Says whether the shape, place or size was off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var drawingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drawing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                HStack {
                    Text("Smoothing")
                        .accessibilityHidden(true)
                    Spacer()
                    Picker("Smoothing", selection: $settings.smoothingStrength) {
                        ForEach(SmoothingStrength.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().padding(.leading, 16)

                HStack {
                    Text("Brush Thickness")
                        .accessibilityHidden(true)
                    Spacer()
                    Picker("Brush Thickness", selection: $settings.brushThickness) {
                        ForEach(BrushThickness.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().padding(.leading, 16)

                Toggle("Practice grid", isOn: $settings.showPracticeGrid)
                    .accessibilityIdentifier("showPracticeGrid")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var iPadSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layout")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                HStack {
                    Text("Handedness")
                        .accessibilityHidden(true)
                    Spacer()
                    Picker("Handedness", selection: $settings.handedness) {
                        ForEach(Handedness.allCases, id: \.self) { h in
                            Text(h.displayName).tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Apple Pencil")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)
                .padding(.top, 8)

            VStack(spacing: 0) {
                HStack {
                    Text("Pen Pressure")
                        .accessibilityHidden(true)
                    Spacer()
                    Picker("Pen Pressure", selection: $settings.pressureSensitivity) {
                        ForEach(PressureSensitivity.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().padding(.leading, 16)

                HStack {
                    Text("Pen Tilt")
                        .accessibilityHidden(true)
                    Spacer()
                    Picker("Pen Tilt", selection: $settings.tiltSensitivity) {
                        ForEach(TiltSensitivity.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
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
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)
                .padding(.top, 8)

            VStack(spacing: 0) {
                Toggle("Crosshair Guidelines", isOn: $settings.showCrosshairGuidelines)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider().padding(.leading, 16)

                HStack {
                    Text("Cells per Row")
                        .accessibilityHidden(true)
                    Spacer()
                    Stepper(
                        "\(settings.cellsPerRow)",
                        value: $settings.cellsPerRow,
                        in: 6...10,
                        step: 2
                    )
                    .accessibilityLabel("Cells per Row")
                    .accessibilityValue("\(settings.cellsPerRow)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var experimentalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experimental")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)

            Toggle("Word practice", isOn: $settings.showWordPractice)
                .accessibilityIdentifier("showWordPractice")
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Shows the Words session on the home screen. It is still being tested.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var rateRow: some View {
        Link(destination: URL(string: "https://apps.apple.com/app/id6760963794?action=write-review")!) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rate Kanji Write")
                        .foregroundStyle(.primary)
                    Text("Leave a rating on the App Store")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    private func acknowledgmentRow(title: String, detail: LocalizedStringKey, url: String) -> some View {
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
                    .accessibilityHidden(true)
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
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityAddTraits(settings.colorPalette == palette ? .isSelected : [])
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
                .accessibilityAddTraits(.isHeader)
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
                    .accessibilityLabel("Guide Width")
                    .accessibilityValue(widthText)
                    .accessibilityAdjustableAction(adjustWidth)
                    Text(widthText)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 24, alignment: .trailing)
                        .accessibilityHidden(true)
                }

                RoundedRectangle(cornerRadius: sliderWidth / 2)
                    .fill(Color(uiColor: palette.strokeOrderColor(index: 0, total: 3)))
                    .frame(height: sliderWidth)
                    .opacity(0.5)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var widthText: String {
        String(format: "%.0f", sliderWidth)
    }

    private func adjustWidth(_ direction: AccessibilityAdjustmentDirection) {
        let range = AppSettings.maskPathWidthRange
        switch direction {
        case .increment:
            sliderWidth = min(sliderWidth + 1, range.upperBound)
        case .decrement:
            sliderWidth = max(sliderWidth - 1, range.lowerBound)
        @unknown default:
            return
        }
        onChanged(sliderWidth)
    }
}
