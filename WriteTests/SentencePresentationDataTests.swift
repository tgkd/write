import XCTest
@testable import Write

final class SentencePresentationDataTests: XCTestCase {
    func testGeneratedGroupsPartitionEveryTokenWithoutChangingTheSentence() throws {
        let prompts = WordPromptStore().prompts
        XCTAssertEqual(prompts.count, 120)
        for prompt in prompts {
            let tokens = try XCTUnwrap(prompt.tokens)
            let groups = try XCTUnwrap(prompt.presentation?.validatedGroups(tokenCount: tokens.count), prompt.id)
            XCTAssertEqual(groups.flatMap { $0 }, Array(tokens.indices), prompt.id)
            XCTAssertEqual(groups.map { $0.map { tokens[$0].surface }.joined() }.joined(), tokens.map(\.surface).joined(), prompt.id)
        }
    }

    func testFunctionWordsAttachButTheAdverbRemainsSeparate() throws {
        let prompt = try XCTUnwrap(WordPromptStore().prompts.first { $0.id == "w06" })
        let tokens = try XCTUnwrap(prompt.tokens)
        let groups = try XCTUnwrap(prompt.presentation?.groups)
        XCTAssertEqual(groups.map { $0.map { tokens[$0].surface }.joined() }, ["彼は", "学校を", "よく", "休む。"])
    }

    func testEmptyEligibilityIsGeneratedAndLeavesEnoughPrompts() {
        let store = WordPromptStore()
        XCTAssertTrue(store.prompts.allSatisfy { $0.presentation?.emptyIssues != nil })
        let eligible = store.writingPrompts.filter { $0.presentation?.allowsEmpty == true }
        XCTAssertGreaterThanOrEqual(eligible.count, 5)
        XCTAssertLessThan(eligible.count, store.prompts.count)
        for _ in 0..<5 {
            let ids = store.randomWritingPromptIDs(count: 5, mode: .empty)
            XCTAssertEqual(ids.count, 5)
            XCTAssertTrue(ids.allSatisfy { id in eligible.contains { $0.id == id } })
        }
    }

    func testFreeWritingStoreExcludesUnsupportedPresentationWithoutAffectingWords() {
        var prompt = WordPromptStore().prompts[0]
        prompt.presentation = SentencePresentation(version: 99, groups: [[0]])
        let store = WordPromptStore(prompts: [prompt])
        XCTAssertEqual(store.prompts.count, 1)
        XCTAssertEqual(store.sentencePrompts.count, 1)
        XCTAssertTrue(store.writingPrompts.isEmpty)
    }
}
