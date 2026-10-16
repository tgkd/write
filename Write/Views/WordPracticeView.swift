import SwiftUI

struct WordPracticeView: View {
    let prompts: [WordPrompt]
    let dataStore: KanjiDataStore

    @StateObject private var wordState: WordPracticeState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var wordHistory: WordHistoryStore
    @State private var showCompletionCheck = false
    @State private var showNextButton = false
    @Environment(\.dismiss) private var dismiss

    init(prompts: [WordPrompt], dataStore: KanjiDataStore) {
        self.prompts = prompts
        self.dataStore = dataStore
        _wordState = StateObject(wrappedValue: WordPracticeState(prompts: prompts, dataStore: dataStore))
    }

    var body: some View {
        Group {
            if wordState.isSessionComplete {
                WordSessionSummaryView(results: wordState.results)
            } else if let prompt = wordState.currentPrompt, let slotState = wordState.slotState {
                practiceContent(prompt: prompt, slotState: slotState)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .principal) {
                if !wordState.isSessionComplete {
                    let progress = wordState.progress
                    Text("Words · \(progress.current) / \(progress.total)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("word.progress")
                }
            }
        }
        .onAppear {
            wordState.validationConfig = settings.validationConfig
            wordState.onWordCompleted = { record in
                wordHistory.add(record)
            }
        }
        .onChange(of: settings.gradingStrictness) { _ in
            wordState.validationConfig = settings.validationConfig
        }
    }

    private func practiceContent(prompt: WordPrompt, slotState: PracticeState) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                header(prompt: prompt, slotState: slotState)

                Spacer(minLength: 0)

                WordSlotCanvas(
                    slotState: slotState,
                    showCompletionCheck: showCompletionCheck,
                    isLocked: wordState.isWordComplete,
                    onSlotCompleted: handleSlotCompleted,
                    onResetWord: { wordState.resetWord() }
                )
                .id(wordState.slotRun)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)

            if showNextButton {
                nextButton
                    .frame(maxWidth: 640)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 48)
            }
        }
    }

    private func header(prompt: WordPrompt, slotState: PracticeState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            WordSentenceView(prompt: prompt)

            Text(prompt.gloss)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("wordGloss")

            WordSlotsRow(
                prompt: prompt,
                completedSegments: wordState.completedSegmentIndices,
                currentSegment: wordState.currentSegmentIndex,
                slotState: slotState
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showNextButton = false
            }
            showCompletionCheck = false
            wordState.advanceWord()
        } label: {
            Text(wordState.isLastWord ? "Finish" : "Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
        }
        .accessibilityIdentifier("word.next")
    }

    private func handleSlotCompleted() {
        guard wordState.isWordComplete else {
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
