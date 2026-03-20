import SwiftUI

struct SessionPracticeView: View {
    @StateObject private var sessionState: SessionState
    @State private var showNextButton = false
    @Environment(\.dismiss) private var dismiss

    init(kanji: [KanjiData]) {
        _sessionState = StateObject(wrappedValue: SessionState(kanjiQueue: kanji))
    }

    var body: some View {
        Group {
            if sessionState.isSessionComplete {
                SessionSummaryView(results: sessionState.results)
            } else if let kanji = sessionState.currentKanji {
                practiceContent(kanji: kanji)
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
                if !sessionState.isSessionComplete {
                    let p = sessionState.progress
                    Text("\(p.current) / \(p.total)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func practiceContent(kanji: KanjiData) -> some View {
        ZStack(alignment: .bottom) {
            PracticeView(
                kanjiData: kanji,
                mode: sessionState.mode,
                showToolbar: false,
                onComplete: { attempts in
                    sessionState.recordResult(attemptCount: attempts)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showNextButton = true
                        }
                    }
                },
                onModeChange: { sessionState.mode = $0 }
            )
            .id(sessionState.currentIndex)

            if showNextButton {
                nextButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 48)
            }
        }
    }

    private var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showNextButton = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                sessionState.advance()
            }
        } label: {
            Text(isLastKanji ? "Finish" : "Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary)
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
        }
    }

    private var isLastKanji: Bool {
        sessionState.currentIndex + 1 >= sessionState.kanjiQueue.count
    }
}
