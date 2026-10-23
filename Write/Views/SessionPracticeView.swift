import SwiftUI

struct SessionPracticeView: View {
    @StateObject private var sessionState: SessionState
    @EnvironmentObject private var settings: AppSettings
    @State private var showNextButton = false
    @Environment(\.dismiss) private var dismiss

    init(kanji: [KanjiData], kind: SessionKind = .practice, origin: RunOrigin = .randomSession) {
        _sessionState = StateObject(wrappedValue: SessionState(kanjiQueue: kanji, kind: kind, origin: origin))
    }

    var body: some View {
        Group {
            if sessionState.isSessionComplete {
                SessionSummaryView(results: sessionState.results, kind: sessionState.kind)
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
                .accessibilityLabel("End session")
            }
            ToolbarItem(placement: .principal) {
                if !sessionState.isSessionComplete {
                    let p = sessionState.progress
                    Text("\(title) · \(p.current) / \(p.total)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var title: String {
        switch sessionState.kind {
        case .practice: return String(localized: "Practice")
        case .recall: return String(localized: "Recall")
        }
    }

    private func practiceContent(kanji: KanjiData) -> some View {
        ZStack(alignment: .bottom) {
            PracticeView(
                kanjiData: kanji,
                mode: settings.practiceMode,
                isRecall: sessionState.kind == .recall,
                showToolbar: false,
                context: RunContext(
                    sessionID: sessionState.id,
                    origin: sessionState.origin,
                    slot: sessionState.currentIndex
                ),
                onComplete: { record in
                    sessionState.recordResult(attemptCount: record.misses, usedHint: record.revealed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showNextButton = true
                        }
                    }
                }
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
