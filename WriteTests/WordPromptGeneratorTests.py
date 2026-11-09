import importlib.util
import json
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "build_word_prompts", Path(__file__).resolve().parents[1] / "Scripts" / "build_word_prompts.py"
)
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class WordPromptGeneratorTests(unittest.TestCase):
    def token(self, surface, reading=None, head=None):
        return {"surface": surface, "reading": reading, "b": {"head": head} if head else None}

    def test_presentation_uses_auxiliary_metadata_and_keeps_token_indices(self):
        tokens = [self.token("散歩", "さんぽ", "散歩"), self.token("しましょう", head="為る"), self.token("。")]
        prompt = generator.build_prompt("test", {"english": "Let's walk."}, tokens, 0, "walk", [("kanji", "散歩")], "")
        encoded = json.loads(generator.encode_prompt(prompt))
        self.assertEqual(encoded["presentation"], {"version": 1, "groups": [[0, 1, 2]], "emptyIssues": None})
        self.assertEqual([t["surface"] for t in encoded["tokens"]], ["散歩", "しましょう", "。"])
        self.assertTrue(all("b" not in token for token in encoded["tokens"]))

    def test_missing_reading_does_not_absorb_an_independent_adverb(self):
        tokens = [self.token("学校", "がっこう"), self.token("を"), self.token("よく"), self.token("休む", "やすむ"), self.token("。")]
        self.assertEqual(generator.chunk_tokens(tokens), [[0, 1], [2], [3, 4]])

    def test_prefix_and_punctuation_stay_with_their_phrase(self):
        tokens = [self.token("お"), self.token("茶", "ちゃ"), self.token("を"), self.token("。")]
        self.assertEqual(generator.chunk_tokens(tokens), [[0, 1, 2, 3]])

    def entry(self, sequence, spellings, reading="はな", usually_kana=False):
        return {
            "seq": sequence,
            "kanji": [{"text": text, "common": True, "info": set()} for text in spellings],
            "readings": [{"text": reading, "nokanji": False, "restrict": [], "common": True}],
            "senses": [{"pos": {"n"}, "misc": {"uk"} if usually_kana else set()}],
        }

    def issues(self, entries, head="花"):
        entries = {entry["seq"]: entry for entry in entries}
        by_spelling, homophones = generator.build_indexes(entries)
        tokens = [self.token("猫", "ねこ"), {"surface": head, "reading": "はな", "b": {"head": head, "reading": None}}]
        return generator.context_spelling_issues(tokens, 0, by_spelling, homophones, entries)

    def test_non_target_common_alternative_is_flagged(self):
        self.assertEqual(self.issues([self.entry(1, ["花", "華"])]), [{"tokenIndex": 1, "reason": "common alternative spelling"}])

    def test_non_target_homophone_is_flagged(self):
        self.assertEqual(self.issues([self.entry(1, ["花"]), self.entry(2, ["鼻"])]), [{"tokenIndex": 1, "reason": "common homophone"}])

    def test_non_target_usually_kana_is_flagged(self):
        self.assertEqual(self.issues([self.entry(1, ["花"], usually_kana=True)]), [{"tokenIndex": 1, "reason": "usually written in kana"}])

    def test_unambiguous_context_passes_and_target_is_not_rechecked(self):
        self.assertEqual(self.issues([self.entry(1, ["花"])]), [])

    def test_missing_metadata_cannot_claim_empty_safety(self):
        issues = generator.context_spelling_issues([self.token("花", "はな")], -1, {}, {}, {})
        self.assertEqual(issues, [{"tokenIndex": 0, "reason": "target not on the B line"}])


if __name__ == "__main__":
    unittest.main()
