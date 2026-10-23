import SwiftUI

struct SentencePracticeView: View {
    let prompts: [WordPrompt]
    let dataStore: KanjiDataStore

    @StateObject private var sentenceState: SentencePracticeState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var wordHistory: WordHistoryStore
    @State private var showCompletionCheck = false
    @State private var showNextButton = false
    @Environment(\.dismiss) private var dismiss

    init(prompts: [WordPrompt], dataStore: KanjiDataStore) {
        self.prompts = prompts
        self.dataStore = dataStore
        _sentenceState = StateObject(wrappedValue: SentencePracticeState(prompts: prompts, dataStore: dataStore))
    }

    var body: some View {
        Group {
            if sentenceState.isSessionComplete {
                SentenceSessionSummaryView(results: sentenceState.results)
            } else if let item = sentenceState.currentItem, let slotState = sentenceState.slotState {
                practiceContent(item: item, slotState: slotState)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("End session")
                .accessibilityIdentifier("sentence.end")
            }
            ToolbarItem(placement: .principal) {
                if !sentenceState.isSessionComplete {
                    let progress = sentenceState.progress
                    Text("Sentences · \(progress.current) / \(progress.total)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("sentence.progress")
                }
            }
        }
        .onAppear {
            sentenceState.validationConfig = settings.validationConfig
            sentenceState.onSentenceCompleted = { record in
                wordHistory.add(record)
            }
        }
        .onChange(of: settings.gradingStrictness) { _ in
            sentenceState.validationConfig = settings.validationConfig
        }
    }

    private func practiceContent(item: SentencePracticeState.Item, slotState: PracticeState) -> some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                HStack(spacing: 0) {
                    if settings.handedness == .left {
                        canvasColumn(slotState: slotState)
                        Divider()
                        sidePanel(item: item, slotState: slotState, width: geo.size.width)
                    } else {
                        sidePanel(item: item, slotState: slotState, width: geo.size.width)
                        Divider()
                        canvasColumn(slotState: slotState)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    promptPanel(item: item, slotState: slotState)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    canvasColumn(slotState: slotState)
                }
            }
        }
    }

    private func sidePanel(item: SentencePracticeState.Item, slotState: PracticeState, width: CGFloat) -> some View {
        ScrollView {
            promptPanel(item: item, slotState: slotState)
                .padding(24)
        }
        .frame(width: min(440, width * 0.4))
    }

    private func promptPanel(item: SentencePracticeState.Item, slotState: PracticeState) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            SentencePromptHeader(item: item)
            SentenceBlocksView(
                item: item,
                completedCharacters: sentenceState.completedCharacterIndices,
                currentCharacter: sentenceState.currentCharacterIndex,
                slotState: slotState
            )
        }
    }

    private func canvasColumn(slotState: PracticeState) -> some View {
        ZStack(alignment: .bottom) {
            SentenceSlotCanvas(
                slotState: slotState,
                showCompletionCheck: showCompletionCheck,
                isLocked: sentenceState.isSentenceComplete,
                onSlotCompleted: handleSlotCompleted,
                onRestartSentence: { sentenceState.restartSentence() }
            )
            .id(sentenceState.slotRun)

            if showNextButton {
                nextButton
                    .frame(maxWidth: 640)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showNextButton = false
            }
            showCompletionCheck = false
            sentenceState.advanceSentence()
        } label: {
            Text(sentenceState.isLastSentence ? "Finish" : "Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
        }
        .accessibilityIdentifier("sentence.next")
    }

    private func handleSlotCompleted() {
        guard sentenceState.isSentenceComplete else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showCompletionCheck = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showCompletionCheck = false
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNextButton = true
            }
        }
    }
}
