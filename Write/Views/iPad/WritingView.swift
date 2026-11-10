import SwiftUI

struct WritingView: View {
    @StateObject private var session: WritingSession
    @StateObject private var ink = WritingInkStore()
    @State private var cellSide: CGFloat?
    @State private var focusedPhrase = 0
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
        VStack(spacing: 0) {
            header(item: item)
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        if let cellSide {
                            VStack(alignment: .leading, spacing: 28) {
                                ForEach(Array(item.phrases.enumerated()), id: \.element.id) { index, phrase in
                                    phraseRow(phrase, index: index, side: cellSide)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, geometry.size.height / 2)
                        }
                    }
                    .scrollDisabled(true)
                    .id(item.prompt.id)
                    .onChange(of: focusedPhraseIndex) { _ in
                        centerFocus(item: item, proxy: proxy, animated: true)
                    }
                    .onChange(of: session.currentCell?.id) { _ in
                        centerFocus(item: item, proxy: proxy, animated: true)
                    }
                    .onChange(of: cellSide) { _ in
                        DispatchQueue.main.async {
                            centerFocus(item: item, proxy: proxy, animated: false)
                        }
                    }
                    .onChange(of: geometry.size) { _ in
                        DispatchQueue.main.async {
                            centerFocus(item: item, proxy: proxy, animated: false)
                        }
                    }
                    .onAppear {
                        if cellSide == nil, geometry.size.width > 32 {
                            cellSide = min(200, geometry.size.width - 32)
                        }
                        DispatchQueue.main.async {
                            centerFocus(item: item, proxy: proxy, animated: false)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        .onChange(of: session.promptIndex) { _ in resetFocus() }
        .onChange(of: session.phraseIndex) { _ in resetFocus() }
    }

    private func header(item: WritingSession.Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phraseRow(_ phrase: WritingSession.Phrase, index: Int, side: CGFloat) -> some View {
        let isFocused = index == focusedPhraseIndex
        return VStack(alignment: .leading, spacing: 6) {
            Text(phrase.reading)
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("writing.phrase.\(index)")
            WordFlowLayout(spacing: 12, lineSpacing: 12) {
                ForEach(phrase.units) { cell in
                    unitView(cell, side: side)
                        .id(cell.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(isFocused || session.isSentenceComplete ? 1 : 0.35)
        .allowsHitTesting(isFocused)
        .id(phrase.id)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }

    private var isFocusManual: Bool {
        session.activeMode == .free || session.isSentenceComplete
    }

    private var focusedPhraseIndex: Int {
        isFocusManual ? focusedPhrase : session.phraseIndex
    }

    private func resetFocus() {
        focusedPhrase = session.activeMode == .free ? 0 : session.phraseIndex
    }

    private func moveFocus(by delta: Int) {
        let count = session.currentItem?.phrases.count ?? 0
        guard count > 0 else {
            return
        }
        ink.leavePhrase()
        focusedPhrase = min(max(focusedPhraseIndex + delta, 0), count - 1)
    }

    private func centerFocus(item: WritingSession.Item, proxy: ScrollViewProxy, animated: Bool) {
        let target: String
        if let cell = session.currentCell {
            target = cell.id
        } else if item.phrases.indices.contains(focusedPhraseIndex) {
            target = item.phrases[focusedPhraseIndex].id
        } else {
            return
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(target, anchor: .center) }
        } else {
            proxy.scrollTo(target, anchor: .center)
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
                        resetFocus()
                    } label: {
                        Image(systemName: "arrow.counterclockwise").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(session.activeMode == .free ? "Restart sentence" : "Restart phrase")
                    .accessibilityIdentifier("writing.restart")
                }
                if isFocusManual, phraseCount > 1 {
                    Button {
                        moveFocus(by: -1)
                    } label: {
                        Image(systemName: "chevron.up").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Previous row").accessibilityIdentifier("writing.previousRow")
                    .disabled(focusedPhraseIndex == 0)
                    Button {
                        moveFocus(by: 1)
                    } label: {
                        Image(systemName: "chevron.down").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Next row").accessibilityIdentifier("writing.nextRow")
                    .disabled(focusedPhraseIndex + 1 >= phraseCount)
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

    private var phraseCount: Int {
        session.currentItem?.phrases.count ?? 0
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
