import SwiftUI

struct RecallCueSettingsSection: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recall")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(RecallCueOrder.allCases, id: \.self) { order in
                    orderRow(order)
                    if order != RecallCueOrder.allCases.last {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Which line leads the cue under the character. Both orders show the same readings and meanings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private func orderRow(_ order: RecallCueOrder) -> some View {
        Button {
            settings.recallCueOrder = order
        } label: {
            HStack {
                Text(order.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if settings.recallCueOrder == order {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("recallCueOrder.\(order.rawValue)")
        .accessibilityAddTraits(settings.recallCueOrder == order ? .isSelected : [])
    }
}
