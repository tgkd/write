import SwiftUI

struct PracticeSessionCard: View {
    let reviewCount: Int
    let isNewEnabled: Bool
    let isReviewEnabled: Bool
    let startNew: () -> Void
    let startReview: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        VStack(alignment: .leading, spacing: 6) {
            Text("Practice")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            layout {
                newButton
                reviewButton
            }
        }
    }

    private var newButton: some View {
        Button(action: startNew) {
            buttonLabel(title: "New", systemImage: "pencil.tip", count: nil)
        }
        .buttonStyle(.plain)
        .disabled(!isNewEnabled)
        .accessibilityLabel(Text("New"))
        .accessibilityIdentifier("session.practice")
        .accessibilityInputLabels([Text("New")])
    }

    private var reviewButton: some View {
        Button(action: startReview) {
            buttonLabel(title: "Review", systemImage: "repeat", count: reviewCount > 0 ? reviewCount : nil)
        }
        .buttonStyle(.plain)
        .disabled(!isReviewEnabled)
        .accessibilityLabel(Text("Review"))
        .accessibilityValue(reviewCount > 0 ? Text("\(reviewCount) to review") : Text(verbatim: ""))
        .accessibilityIdentifier("session.review")
        .accessibilityInputLabels([Text("Review")])
    }

    private func buttonLabel(title: LocalizedStringKey, systemImage: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Spacer(minLength: 4)
            if let count {
                Text(count, format: .number)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
