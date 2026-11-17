import SwiftUI

struct SizeStepperButtons: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    let smallerLabel: LocalizedStringKey
    let largerLabel: LocalizedStringKey
    var isLocked = false

    var body: some View {
        Button {
            value = max(range.lowerBound, value - step)
        } label: {
            Image(systemName: "minus")
        }
        .accessibilityLabel(smallerLabel)
        .disabled(isLocked || value <= range.lowerBound)

        Button {
            value = min(range.upperBound, value + step)
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel(largerLabel)
        .disabled(isLocked || value >= range.upperBound)
    }
}
