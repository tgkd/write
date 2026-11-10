import SwiftUI

struct WritingView: View {
    @StateObject private var session: WritingSession
    @StateObject private var ink = WritingInkStore()
    @State private var cellSide: CGFloat?
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var wordHistory: WordHistoryStore
    @Environment(\.dismiss) private var dismiss

    init(prompts: [WordPrompt], dataStore: KanjiDataStore, mode: WritingMode) {
        _session = StateObject(wrappedValue: WritingSession(prompts: prompts, mode: mode, lookup: { dataStore.lookup(character: $0) }))
    }

    var body: some View {
        Group {
            if session.isComplete {
                if session.results.isEmpty {
                    VStack(spacing: 20) {
                        Text("Writing complete").font(.title).accessibilityIdentifier("writing.complete")
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("writing.done")
                    }
                } else {
                    SentenceSessionSummaryView(results: session.results)
                }
            } else if let item = session.currentItem {
                writingContent(item: item)
            }
        }
        .background(WritingPencilInteraction(onDoubleTap: undo))
        .navigationTitle("Writing")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("End session") { dismiss() }.accessibilityIdentifier("writing.end")
            }
        }
        .onAppear {
            session.validationConfig = settings.validationConfig
            session.onSentenceCompleted = { [weak wordHistory] in wordHistory?.add($0) }
        }
        .onChange(of: settings.writingMode) { session.requestedMode = $0 }
        .onChange(of: settings.gradingStrictness) { _ in session.validationConfig = settings.validationConfig }
    }

    private func writingContent(item: WritingSession.Item) -> some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(session.activeMode == .empty && !session.isSentenceComplete ? item.kana : item.sentence)
                            .font(.title3).accessibilityIdentifier("writing.sentence")
                        if let translation = item.prompt.translation {
                            Text(translation).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Sentence \(session.sentenceNumber) of \(session.totalSentenceCount)")
                                .font(.caption).accessibilityIdentifier("writing.sentenceProgress")
                            Spacer()
                            ReadingSpeakerButton(text: SpokenReading.text(for: item.prompt))
                        }
                        if let cellSide {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(Array(item.phrases.enumerated()), id: \.element.id) { index, phrase in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(phrase.reading)
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                            .accessibilityIdentifier("writing.phrase.\(index)")
                                        WordFlowLayout(spacing: 12, lineSpacing: 12) {
                                            ForEach(phrase.units) { cell in
                                                unitView(cell, side: cellSide)
                                                    .id(cell.id)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .id(item.prompt.id)
                .onChange(of: session.currentCell?.id) { id in
                    if let id {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .onAppear {
                    if cellSide == nil, geometry.size.width > 32 {
                        cellSide = min(200, geometry.size.width - 32)
                    }
                }
                .safeAreaInset(edge: .bottom) { controls }
            }
        }
    }

    @ViewBuilder
    private func unitView(_ cell: WritingSession.Cell, side: CGFloat) -> some View {
        if cell.isPunctuation {
            Text(String(cell.character)).font(.title2)
                .frame(width: 24, height: side)
                .accessibilityIdentifier("writing.punctuation.\(cell.id)")
        } else if let state = session.slotState, session.currentCell?.id == cell.id {
            WritingGradedCellView(cell: cell, slotState: state, ink: ink)
                .id(ObjectIdentifier(state)).frame(width: side, height: side)
        } else {
            WritingCellView(cell: cell, mode: session.activeMode,
                            isFinished: session.activeMode != .free
                                && (session.isSentenceComplete || session.completedCellIDs.contains(cell.id)),
                            isActive: false, ink: ink)
                .frame(width: side, height: side)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if session.activeMode != .free {
                Group {
                    if let state = session.slotState {
                        WritingRejectionNotice(state: state)
                            .id(ObjectIdentifier(state))
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 36)
            }
            Picker("Writing mode", selection: $settings.writingMode) {
                ForEach(WritingMode.allCases) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.menu).accessibilityIdentifier("writing.mode")
            if settings.writingMode != session.activeMode {
                if session.endsBeforeQueuedEmpty {
                    Text("No remaining prompts are eligible for Empty. This session will finish after this sentence.")
                        .font(.caption).accessibilityIdentifier("writing.noRemainingEmpty")
                } else {
                    Text("Mode changes apply to the next sentence.").font(.caption)
                }
            }
            if session.activeMode == .free {
                Text("No checking").font(.footnote).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Undo stroke").accessibilityIdentifier("writing.undo")
                .disabled(!canUndo)
                if session.activeMode == .free {
                    Button("Clear cell") { ink.clear() }
                        .accessibilityIdentifier("writing.clear").disabled(!ink.canUndo)
                } else if let state = session.slotState, state.isRecall {
                    WritingHintControls(state: state)
                }
                if !session.isSentenceComplete {
                    Button {
                        ink.clear(session.restartPhrase().map(\.id))
                    } label: {
                        Image(systemName: "arrow.counterclockwise").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(session.activeMode == .free ? "Restart sentence" : "Restart phrase")
                    .accessibilityIdentifier("writing.restart")
                }
                Spacer(minLength: 0)
                if session.activeMode == .free || session.isSentenceComplete {
                    Button {
                        ink.leavePhrase()
                        session.advance()
                    } label: { Text(nextLabel) }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("writing.next")
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8).background(.bar)
    }

    private var canUndo: Bool {
        if session.activeMode == .free {
            return !session.isSentenceComplete && ink.canUndo
        }
        return session.slotState?.matchedStrokeIndices.isEmpty == false
    }

    private func undo() {
        if session.activeMode == .free {
            if !session.isSentenceComplete { ink.undo() }
        } else if let cell = session.currentCell, session.slotState?.undoLastStroke() != nil {
            ink.canvas(for: cell.id).removeLastStroke()
            ink.noteStroke(in: cell.id)
        }
    }

    private var nextLabel: LocalizedStringKey {
        session.isLastPrompt ? "Done" : "Next sentence"
    }
}
