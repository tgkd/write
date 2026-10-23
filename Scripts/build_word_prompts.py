#!/usr/bin/env python3
import collections
import json
import re
import sys

NEW_PROMPT_COUNT = 96
MAX_WRITTEN_LENGTH = 18
MIN_WRITTEN_LENGTH = 6
MAX_TARGETS_PER_KANJI = 2
MAX_GLOSS_LENGTH = 32

COMMON_PRIORITIES = {"news1", "ichi1", "spec1", "spec2"} | {f"nf{n:02d}" for n in range(1, 25)}
IRREGULAR_FORMS = {"rK", "sK", "oK", "iK", "ik", "ok", "io", "sk", "rk", "ateji"}

PUNCTUATION = set("。、！？")
SMALL_KANA = set("ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮ")
UNSTROKED_ALLOWED = PUNCTUATION | SMALL_KANA | {"ー"}
NUMERALS = set("一二三四五六七八九十百千")
PREFIXES = {"お", "ご"}

FUNCTION_WORDS = {
    "は", "が", "を", "に", "の", "で", "へ", "と", "も", "か", "や", "よ", "ね", "な", "わ", "ぞ", "さ",
    "から", "まで", "より", "ので", "のに", "けど", "けれど", "けれども", "しか", "だけ", "ばかり", "ほど",
    "くらい", "ぐらい", "など", "って", "とか", "なら", "でも", "には", "では", "とは", "にも", "へは",
    "へも", "からは", "までに", "ても", "て", "し", "ながら", "たり", "だり", "よりも", "かな", "かしら",
    "だ", "です", "でした", "だった", "でしょう", "だろう", "でしょうか", "ですか", "ですね", "ですよ",
    "だろうか", "のだ", "のです", "んだ", "んです", "らしい", "ようだ", "ようです", "みたい", "みたいだ",
    "そうだ", "そうです", "たい", "ます", "ました", "ません", "ましょう", "ましょうか", "ない", "なかった",
    "た", "しかない", "かもしれない", "かもしれません", "ではない", "ではありません", "じゃない",
    "である", "であった", "なあ", "よね", "のよ", "の", "ん", "なさい", "ください", "なければならない",
    "さえ", "すら", "こそ", "ずつ", "かい", "だい", "っけ", "かね", "じゃ", "ぜ", "わよ", "のか", "なの", "だから",
    "だけど", "けども", "になる", "になった", "になって", "になり", "になります", "になりました", "とも", "がち", "がちだ",
}
TE_FORM_AUXILIARIES = {"居る", "呉れる", "貰う", "仕舞う", "見る", "置く", "有る", "行く", "来る", "下さい", "頂く"}
AUXILIARY_SUFFIXES = {
    "たい", "たかった", "たくない", "ます", "ました", "ません", "ましょう", "ましょうか", "ませんでした",
    "ない", "なかった", "なくて", "なさい",
}
SURU_HEADWORDS = {"為る", "する", "為れる", "為せる", "為さる"}
EXCLUDED_MISC = {
    "abbr", "arch", "rare", "hist", "col", "sl", "id", "yoji", "proverb", "hon", "hum", "obs", "dated", "derog",
    "vulg", "sens", "net-sl", "m-sl", "place", "surname", "given", "person", "organization", "company", "work",
    "product", "char", "ev", "dei", "on-mim", "uk",
}
EXCLUDED_POS = {"exp", "num", "ctr", "n-pr", "pref", "suf", "n-suf", "n-pref", "int", "prt", "conj", "aux"}
EXCLUDED_SENTENCES = {
    78851: "proverb with a figurative translation",
    78852: "proverb with a figurative translation",
    89141: "suicide",
    103759: "prefix 新 read as a separate phrase",
    127077: "proverb with a figurative translation",
    145515: "proverb with a figurative translation",
    172396: "transcription reads 今 as こん",
    173925: "proverb with a figurative translation",
    189518: "proverb with a figurative translation",
    189519: "corpus typo 道って for 通って",
    193048: "idiom with a figurative translation",
}

GODAN_ROWS = {
    "う": "わいうえおっ", "く": "かきくけこい", "ぐ": "がぎぐげごい", "す": "さしすせそ", "つ": "たちつてとっ",
    "ぬ": "なにぬねのん", "ぶ": "ばびぶべぼん", "む": "まみむめもん", "る": "らりるれろっ",
}
ADJECTIVE_ENDINGS = "いくかけさそすみ"

LEGACY_PROMPTS = [
    {
        "id": "w01", "tatoeba": 143825, "before": "", "reading": "みず", "after": "が のみたい。",
        "gloss": "water", "segments": [("kanji", "水")],
        "notes": "Tatoeba #143825 (CC BY 2.0 FR): 水が飲みたい。 “I want to drink some water.” Kana from the Tatoeba furigana transcription. Only spelling: 水.",
    },
    {
        "id": "w02", "tatoeba": 125498, "before": "にわの ", "reading": "はな", "after": "は うつくしい。",
        "gloss": "flower", "segments": [("kanji", "花")],
        "notes": "Tatoeba #125498 (CC BY 2.0 FR): 庭の花は美しい。 “The flowers in the garden are beautiful.” Kana from the Tatoeba furigana transcription. Answer 花; 鼻 (nose) is ruled out by にわの and the gloss; 華 is a literary variant and is not accepted.",
    },
    {
        "id": "w03", "tatoeba": 189727, "before": "", "reading": "あめ", "after": "が ふるそうだ。",
        "gloss": "rain", "segments": [("kanji", "雨")],
        "notes": "Tatoeba #189727 (CC BY 2.0 FR): 雨が降るそうだ。 “They say it will rain.” Kana from the Tatoeba furigana transcription. Answer 雨; 飴 (candy) is ruled out by ふる and the gloss.",
    },
    {
        "id": "w04", "tatoeba": 108413, "before": "かれは ", "reading": "さかな", "after": "を さんびき つった。",
        "gloss": "fish", "segments": [("kanji", "魚")],
        "notes": "Tatoeba #108413 (CC BY 2.0 FR): 彼は魚を３匹釣った。 “He caught three fish.” Kana from the Tatoeba furigana transcription. Answer 魚; 肴 is a different word; つった fixes the meaning. The sentence tokens write ３ as 三, since the fullwidth digit has no stroke data.",
        "digits": {"３": "三"},
    },
    {
        "id": "w05", "tatoeba": 150316, "before": "つぎの ", "reading": "えき", "after": "で おります。",
        "gloss": "(train) station", "segments": [("kanji", "駅")],
        "notes": "Tatoeba #150316 (CC BY 2.0 FR): 次の駅で降ります。 “I am getting off at the next station.” Kana from the Tatoeba furigana transcription. Answer 駅; 液 and 益 are ruled out by つぎの〜で おります and the gloss.",
    },
    {
        "id": "w06", "tatoeba": 108870, "before": "かれは がっこうを よく ", "reading": "やすむ", "after": "。",
        "gloss": "to be absent, to take time off", "segments": [("kanji", "休"), ("kana", "む")],
        "notes": "Tatoeba #108870 (CC BY 2.0 FR): 彼は学校をよく休む。 “He often absents himself from school.” Kana from the Tatoeba furigana transcription. Answer 休む, okurigana む shown. No competing everyday spelling.",
    },
    {
        "id": "w07", "tatoeba": 229710, "before": "", "reading": "たかい", "after": " たてものですね。",
        "gloss": "high, tall (building)", "segments": [("kanji", "高"), ("kana", "い")],
        "notes": "Tatoeba #229710 (CC BY 2.0 FR): 高い建物ですね。 “That is a high building, is it not?” Kana from the Tatoeba furigana transcription. Answer 高い, okurigana い shown; たてもの makes the height sense clear.",
    },
    {
        "id": "w08", "tatoeba": 231367, "before": "あの いぬは ", "reading": "おおきい", "after": "。",
        "gloss": "big", "segments": [("kanji", "大"), ("kana", "きい")],
        "notes": "Tatoeba #231367 (CC BY 2.0 FR): あの犬は大きい。 “That dog is big.” Kana from the Tatoeba furigana transcription. Answer 大きい as a predicate, okurigana きい shown, so 大きな is not the target.",
    },
    {
        "id": "w09", "tatoeba": 78845, "before": "ひつじは くさを ", "reading": "たべる", "after": "。",
        "gloss": "to eat", "segments": [("kanji", "食"), ("kana", "べる")],
        "notes": "Tatoeba #78845 (CC BY 2.0 FR): 羊は草を食べる。 “Sheep feed on grass.” Kana from the Tatoeba furigana transcription. Answer 食べる, okurigana べる shown. No competing everyday spelling.",
    },
    {
        "id": "w10", "tatoeba": 103766, "before": "かれは しんしゃを ", "reading": "かった", "after": "。",
        "gloss": "bought", "segments": [("kanji", "買"), ("kana", "った")],
        "notes": "Tatoeba #103766 (CC BY 2.0 FR): 彼は新車を買った。 “He bought a new car.” Kana from the Tatoeba furigana transcription. Answer 買った (買う), okurigana った shown; 勝った and 飼った are ruled out by しんしゃを and the gloss.",
    },
    {
        "id": "w11", "tatoeba": 4849, "before": "", "reading": "まつ", "after": "しかない。",
        "gloss": "to wait", "segments": [("kanji", "待"), ("kana", "つ")],
        "notes": "Tatoeba #4849 (CC BY 2.0 FR): 待つしかない。 “I can only wait.” Kana from the Tatoeba furigana transcription. Answer 待つ, okurigana つ shown; 松 is ruled out by しかない and the gloss.",
    },
    {
        "id": "w12", "tatoeba": 155294, "before": "わたしは はやく ", "reading": "およげる", "after": "。",
        "gloss": "can swim", "segments": [("kanji", "泳"), ("kana", "げる")],
        "notes": "Tatoeba #155294 (CC BY 2.0 FR): 私は速く泳げる。 “I can swim fast.” Kana from the Tatoeba furigana transcription. Answer 泳げる (泳ぐ), okurigana げる shown. No competing everyday spelling.",
    },
    {
        "id": "w13", "tatoeba": 184467, "before": "", "reading": "がっこう", "after": "に いく じかんよ。",
        "gloss": "school", "segments": [("kanji", "学"), ("kanji", "校")],
        "notes": "Tatoeba #184467 (CC BY 2.0 FR): 学校に行く時間よ。 “It's time to go to school.” Kana from the Tatoeba furigana transcription. Answer 学校. No everyday homophone.",
    },
    {
        "id": "w14", "tatoeba": 105758, "before": "かれは わたしの ", "reading": "せんせい", "after": "です。",
        "gloss": "teacher", "segments": [("kanji", "先"), ("kanji", "生")],
        "notes": "Tatoeba #105758 (CC BY 2.0 FR): 彼は私の先生です。 “He is my teacher.” Kana from the Tatoeba furigana transcription. Answer 先生; 先制, 宣誓 and 専制 are ruled out by わたしの and the gloss.",
    },
    {
        "id": "w15", "tatoeba": 124806, "before": "", "reading": "でんしゃ", "after": "に かさを わすれた。",
        "gloss": "train", "segments": [("kanji", "電"), ("kanji", "車")],
        "notes": "Tatoeba #124806 (CC BY 2.0 FR): 電車に傘を忘れた。 “I left my umbrella on the train.” Kana from the Tatoeba furigana transcription. Answer 電車; 列車 is a different word.",
    },
    {
        "id": "w16", "tatoeba": 229331, "before": "いい ", "reading": "てんき", "after": "ですね。",
        "gloss": "weather", "segments": [("kanji", "天"), ("kanji", "気")],
        "notes": "Tatoeba #229331 (CC BY 2.0 FR): いい天気ですね。 “It is a nice day, isn't it?” Kana from the Tatoeba furigana transcription. Answer 天気; 転機 is ruled out by いい〜ですね and the gloss.",
    },
    {
        "id": "w17", "tatoeba": 174014, "before": "", "reading": "こうえん", "after": "を さんぽしましょう。",
        "gloss": "park", "segments": [("kanji", "公"), ("kanji", "園")],
        "notes": "Tatoeba #174014 (CC BY 2.0 FR): 公園を散歩しましょう。 “Let's take a walk in the park.” Kana from the Tatoeba furigana transcription. Answer 公園; 講演, 公演 and 後援 are ruled out by さんぽ and the gloss.",
    },
    {
        "id": "w18", "tatoeba": 179875, "before": "ちかくに ", "reading": "びょういん", "after": "が ある。",
        "gloss": "hospital", "segments": [("kanji", "病"), ("kanji", "院")],
        "notes": "Tatoeba #179875 (CC BY 2.0 FR): 近くに病院がある。 “There is a hospital nearby.” Kana from the Tatoeba furigana transcription. Answer 病院; 美容院 is read びよういん, a different word.",
    },
    {
        "id": "w19", "tatoeba": 155984, "before": "わたしは ", "reading": "しゅくだい", "after": "を おえた。",
        "gloss": "homework", "segments": [("kanji", "宿"), ("kanji", "題")],
        "notes": "Tatoeba #155984 (CC BY 2.0 FR): 私は宿題を終えた。 “I've finished my homework.” Kana from the Tatoeba furigana transcription. Answer 宿題. No everyday homophone.",
    },
    {
        "id": "w20", "tatoeba": 104466, "before": "かれは ", "reading": "てがみ", "after": "を かいた。",
        "gloss": "letter (mail)", "segments": [("kanji", "手"), ("kanji", "紙")],
        "notes": "Tatoeba #104466 (CC BY 2.0 FR): 彼は手紙を書いた。 “He wrote a letter.” Kana from the Tatoeba furigana transcription. Answer 手紙. No everyday homophone.",
    },
    {
        "id": "w21", "tatoeba": 194438, "before": "もうすぐ ", "reading": "なつやすみ", "after": "です。",
        "gloss": "summer vacation", "segments": [("kanji", "夏"), ("kanji", "休"), ("kana", "み")],
        "notes": "Tatoeba #194438 (CC BY 2.0 FR): もうすぐ夏休みです。 “Soon there will be summer vacation.” Kana from the Tatoeba furigana transcription. Answer 夏休み, okurigana み shown.",
    },
    {
        "id": "w22", "tatoeba": 143874, "before": "", "reading": "としょかん", "after": "に ほんを かえした。",
        "gloss": "library", "segments": [("kanji", "図"), ("kanji", "書"), ("kanji", "館")],
        "notes": "Tatoeba #143874 (CC BY 2.0 FR): 図書館に本を返した。 “She took the book back to the library.” Kana from the Tatoeba furigana transcription. Answer 図書館; 図書室 is a different word.",
    },
    {
        "id": "w23", "tatoeba": 154827, "before": "わたしは ", "reading": "どうぶつえん", "after": "へ いった。",
        "gloss": "zoo", "segments": [("kanji", "動"), ("kanji", "物"), ("kanji", "園")],
        "notes": "Tatoeba #154827 (CC BY 2.0 FR): 私は動物園へ行った。 “I went to the zoo.” Kana from the Tatoeba furigana transcription. Answer 動物園. No everyday homophone.",
    },
    {
        "id": "w24", "tatoeba": 105211, "before": "かれは ", "reading": "じてんしゃ", "after": "で つうがくする。",
        "gloss": "bicycle", "segments": [("kanji", "自"), ("kanji", "転"), ("kanji", "車")],
        "notes": "Tatoeba #105211 (CC BY 2.0 FR): 彼は自転車で通学する。 “He goes to school by bicycle.” Kana from the Tatoeba furigana transcription. Answer 自転車. No everyday homophone.",
    },
]


class Rejected(Exception):
    pass


def is_hiragana(character):
    return "ぁ" <= character <= "ゖ"


def is_katakana(character):
    return "ァ" <= character <= "ヺ" or character == "ー"


def is_kana(character):
    return is_hiragana(character) or is_katakana(character)


def is_kanji(character):
    code = ord(character)
    return 0x4E00 <= code <= 0x9FFF or 0x3400 <= code <= 0x4DBF or 0xF900 <= code <= 0xFAFF or character == "々"


def has_kanji(text):
    return any(is_kanji(character) for character in text)


def is_kana_text(text):
    return bool(text) and all(is_kana(character) for character in text)


def split_word(text):
    match = re.fullmatch(r"([^ぁ-ゖァ-ー]+)([ぁ-ゖ]*)", text)
    if match is None or not all(is_kanji(character) for character in match.group(1)):
        return None
    return match.group(1), match.group(2)


def load_strokes(path):
    with open(path, encoding="utf-8") as f:
        source = json.load(f)
    return {entry["element"]: entry for entry in source.values()}


def load_transcriptions(path):
    result = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            fields = line.rstrip("\n").split("\t")
            if len(fields) >= 5 and fields[1] == "jpn":
                result[int(fields[0])] = fields[4]
    return result


def load_examples(path):
    examples = {}
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    for index in range(len(lines) - 1):
        line = lines[index]
        if not line.startswith("A: ") or not lines[index + 1].startswith("B: "):
            continue
        match = re.fullmatch(r"A: (.*?)\t(.*)#ID=(\d+)_(\d+)", line.rstrip())
        if match is None:
            continue
        japanese_id = int(match.group(4))
        examples[japanese_id] = {
            "id": japanese_id,
            "japanese": match.group(1).strip(),
            "english": match.group(2).strip(),
            "b": lines[index + 1][3:].split(),
        }
    return examples


def load_jmdict(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    entries = {}
    for block in re.findall(r"<entry>(.*?)</entry>", text, re.S):
        sequence = int(re.search(r"<ent_seq>(\d+)</ent_seq>", block).group(1))
        kanji = []
        for element in re.findall(r"<k_ele>(.*?)</k_ele>", block, re.S):
            kanji.append({
                "text": re.search(r"<keb>(.*?)</keb>", element).group(1),
                "info": set(re.findall(r"<ke_inf>&(.*?);</ke_inf>", element)),
                "common": bool(set(re.findall(r"<ke_pri>(.*?)</ke_pri>", element)) & COMMON_PRIORITIES),
                "ichi": "<ke_pri>ichi1</ke_pri>" in element,
                "rank": min([int(value) for value in re.findall(r"<ke_pri>nf(\d+)</ke_pri>", element)] or [49]),
            })
        readings = []
        for element in re.findall(r"<r_ele>(.*?)</r_ele>", block, re.S):
            readings.append({
                "text": re.search(r"<reb>(.*?)</reb>", element).group(1),
                "nokanji": "<re_nokanji" in element,
                "restrict": set(re.findall(r"<re_restr>(.*?)</re_restr>", element)),
                "info": set(re.findall(r"<re_inf>&(.*?);</re_inf>", element)),
                "common": bool(set(re.findall(r"<re_pri>(.*?)</re_pri>", element)) & COMMON_PRIORITIES),
            })
        senses = []
        for element in re.findall(r"<sense>(.*?)</sense>", block, re.S):
            senses.append({
                "pos": re.findall(r"<pos>&(.*?);</pos>", element),
                "misc": set(re.findall(r"<misc>&(.*?);</misc>", element)),
                "glosses": [unescape(gloss) for gloss in re.findall(r"<gloss[^>]*>(.*?)</gloss>", element)],
            })
        for previous, sense in zip(senses, senses[1:]):
            if not sense["pos"]:
                sense["pos"] = previous["pos"]
        entries[sequence] = {"seq": sequence, "kanji": kanji, "readings": readings, "senses": senses}
    return entries


def unescape(text):
    return text.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'")


def readings_for(entry, spelling):
    return [
        reading for reading in entry["readings"]
        if not reading["nokanji"] and (not reading["restrict"] or spelling in reading["restrict"])
    ]


def usable_spellings(entry):
    return [kanji for kanji in entry["kanji"] if not kanji["info"] & IRREGULAR_FORMS]


def is_common(entry):
    return any(kanji["common"] for kanji in entry["kanji"]) or any(reading["common"] for reading in entry["readings"])


def entry_pos(entry):
    return {pos for sense in entry["senses"] for pos in sense["pos"]}


def inflection_heads(reading, pos_set):
    heads = set()
    for pos in pos_set:
        if pos.startswith("v1") and reading.endswith("る"):
            heads.add(reading[:-1])
        elif pos.startswith("v5") and reading and reading[-1] in GODAN_ROWS:
            base = reading[:-1]
            heads.update(base + ending for ending in GODAN_ROWS[reading[-1]])
            if pos in ("v5k-s", "v5aru"):
                heads.add(base + "っ")
                heads.add(base + "い")
        elif pos in ("adj-i", "adj-ix") and reading.endswith("い"):
            heads.update(reading[:-1] + ending for ending in ADJECTIVE_ENDINGS)
        elif pos == "vk" and reading.endswith("くる"):
            heads.update(reading[:-2] + ending for ending in "こきく")
    return heads


def homophone_keys(entry):
    pos_set = entry_pos(entry)
    keys = set()
    for reading in entry["readings"]:
        if reading["nokanji"]:
            continue
        heads = inflection_heads(reading["text"], pos_set)
        keys.update(heads if heads else {reading["text"]})
    return keys


def build_indexes(entries):
    by_spelling = collections.defaultdict(list)
    homophones = collections.defaultdict(set)
    for entry in entries.values():
        for kanji in entry["kanji"]:
            by_spelling[kanji["text"]].append(entry)
        if is_common(entry) and usable_spellings(entry):
            for key in homophone_keys(entry):
                homophones[key].add(entry["seq"])
    return by_spelling, homophones


def parse_transcription(markup):
    units = []
    position = 0
    pattern = re.compile(r"\[([^\]|]+)((?:\|[^\]|]*)+)\]")
    while position < len(markup):
        match = pattern.match(markup, position)
        if match:
            base = match.group(1)
            readings = match.group(2)[1:].split("|")
            if len(readings) == len(base) and all(readings):
                units.extend(zip(base, readings))
            else:
                units.append((base, "".join(readings)))
            position = match.end()
            continue
        if markup[position] in "[]|":
            raise Rejected("transcription markup")
        units.append((markup[position], None))
        position += 1
    return units


def parse_b_token(raw):
    surface_match = re.search(r"\{([^}]*)\}", raw)
    reading_match = re.search(r"\(([^)#][^)]*)\)", raw)
    sense_match = re.search(r"\[(\d+)\]", raw)
    head = re.sub(r"\{[^}]*\}|\([^)]*\)|\[[^\]]*\]|~", "", raw)
    if not head:
        return None
    return {
        "head": head,
        "reading": reading_match.group(1) if reading_match else None,
        "sense": int(sense_match.group(1)) if sense_match else None,
        "surface": surface_match.group(1) if surface_match else head,
    }


def split_b_token(token):
    head = token["head"]
    surface = token["surface"]
    if all(is_kanji(character) for character in head) and surface.startswith(head) and surface != head:
        rest = surface[len(head):]
        if rest in FUNCTION_WORDS:
            word = dict(token, surface=head)
            particle = {"head": rest, "reading": None, "sense": None, "surface": rest}
            return [word, particle]
    if head.endswith("する") and len(head) > 2 and all(is_kanji(character) for character in head[:-2]):
        stem = head[:-2]
        if surface.startswith(stem) and len(surface) > len(stem) and surface[len(stem)] in "しさせ":
            noun = {"head": stem, "reading": None, "sense": None, "surface": stem}
            verb = {"head": "為る", "reading": None, "sense": None, "surface": surface[len(stem):]}
            return [noun, verb]
    return [token]


def align(sentence, b_tokens, allow_kanji_gaps):
    spans = []
    position = 0
    for b_token in b_tokens:
        surface = b_token["surface"]
        index = sentence.find(surface, position)
        if index < 0:
            raise Rejected("alignment")
        add_gap(spans, sentence, position, index, allow_kanji_gaps)
        spans.append({"start": index, "end": index + len(surface), "b": b_token})
        position = index + len(surface)
    add_gap(spans, sentence, position, len(sentence), allow_kanji_gaps)
    return spans


def add_gap(spans, sentence, start, end, allow_kanji_gaps):
    run_start = start
    for index in range(start, end + 1):
        if index < end and sentence[index] not in PUNCTUATION:
            continue
        if run_start < index:
            text = sentence[run_start:index]
            if has_kanji(text) and not allow_kanji_gaps:
                raise Rejected("kanji outside the B line")
            spans.append({"start": run_start, "end": index, "b": None})
        if index < end:
            spans.append({"start": index, "end": index + 1, "b": None})
        run_start = index + 1


def attach_readings(sentence, spans, units):
    boundaries = []
    offset = 0
    for text, reading in units:
        boundaries.append((offset, offset + len(text), text, reading))
        offset += len(text)
    if offset != len(sentence) or "".join(text for text, _ in units) != sentence:
        raise Rejected("transcription differs")
    tokens = []
    for span in spans:
        pieces = []
        for start, end, text, reading in boundaries:
            if end <= span["start"] or start >= span["end"]:
                continue
            if start < span["start"] or end > span["end"]:
                raise Rejected("reading crosses a word boundary")
            if reading is None:
                if has_kanji(text):
                    raise Rejected("kanji without reading")
                pieces.append(text)
            else:
                pieces.append(reading)
        surface = sentence[span["start"]:span["end"]]
        tokens.append({
            "surface": surface,
            "reading": "".join(pieces) if has_kanji(surface) else None,
            "b": span["b"],
        })
    return tokens


def is_verb_or_adjective(head, by_spelling):
    for entry in by_spelling.get(head, []):
        if any(pos.startswith(("v1", "v5", "vk", "adj-i")) for pos in entry_pos(entry)):
            return True
    return False


def merge_tokens(tokens, by_spelling):
    merged = []
    for token in tokens:
        if merged:
            previous = merged[-1]
            numeral = previous["surface"] and all(character in NUMERALS for character in previous["surface"])
            if numeral and len(token["surface"]) == 1 and has_kanji(token["surface"]):
                merged[-1] = combine(previous, token)
                continue
            inflected = previous["b"] is not None and previous["b"]["surface"] != previous["b"]["head"]
            if (
                token["surface"] in AUXILIARY_SUFFIXES
                and inflected
                and is_verb_or_adjective(previous["b"]["head"], by_spelling)
            ):
                merged[-1] = combine(previous, token)
                continue
        merged.append(dict(token))
    return merged


def combine(first, second):
    surface = first["surface"] + second["surface"]
    reading = (first["reading"] or first["surface"]) + (second["reading"] or second["surface"])
    return {
        "surface": surface,
        "reading": reading if has_kanji(surface) else None,
        "b": first["b"],
    }


def token_kana(token):
    return token["reading"] if token["reading"] is not None else token["surface"]


def attaches(token, previous):
    surface = token["surface"]
    if surface in PUNCTUATION:
        return True
    if previous is None:
        return False
    if previous["surface"] in PREFIXES:
        return True
    if has_kanji(surface):
        return False
    if surface in FUNCTION_WORDS:
        return True
    head = token["b"]["head"] if token["b"] else None
    if head in SURU_HEADWORDS and previous["surface"] not in FUNCTION_WORDS and has_kanji(previous["surface"]):
        return True
    if head in ("しか無い", "かも知れない", "では無い", "為さい", "下さい"):
        return True
    if head in TE_FORM_AUXILIARIES and previous["surface"].endswith(("て", "で")) and len(previous["surface"]) > 1:
        return True
    return False


def chunk_tokens(tokens):
    chunks = []
    previous = None
    for index, token in enumerate(tokens):
        if chunks and attaches(token, previous):
            chunks[-1].append(index)
        else:
            chunks.append([index])
        previous = token
    return chunks


def kana_sentence(tokens, target_index):
    chunks = chunk_tokens(tokens)
    before_chunks = []
    after_text = ""
    after_chunks = []
    found = False
    for chunk in chunks:
        text = "".join(token_kana(tokens[index]) for index in chunk)
        if target_index in chunk:
            if chunk[0] != target_index:
                raise Rejected("target inside a phrase")
            after_text = "".join(token_kana(tokens[index]) for index in chunk[1:])
            found = True
        elif found:
            after_chunks.append(text)
        else:
            before_chunks.append(text)
    before = " ".join(before_chunks) + (" " if before_chunks else "")
    after = after_text + ("".join(" " + text for text in after_chunks))
    return before, token_kana(tokens[target_index]), after


def tokenize(example, transcription, digits, by_spelling):
    sentence = example["japanese"]
    markup = transcription
    for source, replacement in (digits or {}).items():
        sentence = sentence.replace(source, replacement)
        markup = markup.replace(source, replacement)
    b_tokens = []
    for raw in example["b"]:
        token = parse_b_token(raw)
        if token:
            b_tokens.extend(split_b_token(token))
    spans = align(sentence, b_tokens, allow_kanji_gaps=bool(digits))
    tokens = attach_readings(sentence, spans, parse_transcription(markup))
    return sentence, merge_tokens(tokens, by_spelling)


def resolve_lemma(token, by_spelling):
    b_token = token["b"]
    if b_token is None:
        raise Rejected("target not on the B line")
    head = b_token["head"]
    surface_parts = split_word(token["surface"])
    head_parts = split_word(head)
    if surface_parts is None or head_parts is None or surface_parts[0] != head_parts[0]:
        raise Rejected("target shape")
    stem, okurigana = surface_parts
    matches = []
    for entry in by_spelling.get(head, []):
        for reading in readings_for(entry, head):
            text = reading["text"]
            if not text.endswith(head_parts[1]):
                continue
            stem_reading = text[:len(text) - len(head_parts[1])]
            if token["reading"] == stem_reading + okurigana and stem_reading:
                matches.append((entry, reading))
    if b_token["reading"]:
        matches = [match for match in matches if match[1]["text"] == b_token["reading"]]
    if len({match[0]["seq"] for match in matches}) != 1:
        raise Rejected("lemma not unique in JMdict")
    entry, reading = matches[0]
    return entry, reading, head, stem


def check_ambiguity(entry, reading, head, token, homophones, entries):
    spelling = next(kanji for kanji in entry["kanji"] if kanji["text"] == head)
    if not spelling["common"] or spelling["info"] & IRREGULAR_FORMS:
        raise Rejected("target spelling not common")
    if "uk" in entry["senses"][0]["misc"]:
        raise Rejected("usually written in kana")
    alternatives = [kanji["text"] for kanji in entry["kanji"] if kanji["text"] != head and kanji["common"]]
    if alternatives:
        raise Rejected("common alternative spelling")
    heads = inflection_heads(reading["text"], entry_pos(entry))
    if heads:
        candidates = [key for key in heads if token["reading"].startswith(key)]
        if not candidates:
            raise Rejected("inflection not recognised")
        key = max(candidates, key=len)
    else:
        key = reading["text"]
    others = homophones.get(key, set()) - {entry["seq"]}
    clashing = [
        seq for seq in others
        if any(kanji["text"] != head for kanji in usable_spellings(entries[seq]))
    ]
    if clashing:
        raise Rejected("common homophone")


def check_word_kind(entry, sense, reading, head, tokens, index, by_spelling):
    if set(sense["pos"]) & EXCLUDED_POS:
        raise Rejected("word class")
    if sense["misc"] & EXCLUDED_MISC:
        raise Rejected("register or proper noun")
    first_gloss = sense["glosses"][0]
    if first_gloss[:1].isupper() and "(language)" not in first_gloss:
        raise Rejected("register or proper noun")
    if head[0] in NUMERALS or "万" in head or "億" in head:
        raise Rejected("numeral")
    conjugating = bool(inflection_heads(reading["text"], entry_pos(entry)))
    if not conjugating:
        surface_tail = split_word(tokens[index]["surface"])[1]
        head_tail = split_word(head)[1]
        if surface_tail and (surface_tail != head_tail or len(surface_tail) > 1):
            raise Rejected("target shape")
        for neighbor in (index - 1, index + 1):
            if 0 <= neighbor < len(tokens):
                other = tokens[neighbor]
                other_head = other["b"]["head"] if other["b"] else ""
                katakana = all(is_katakana(character) for character in other["surface"])
                if (has_kanji(other["surface"]) or katakana) and not is_verb_or_adjective(other_head, by_spelling):
                    raise Rejected("noun next to another noun")


def gloss_for(sense):
    glosses = sense["glosses"]
    gloss = glosses[0]
    if len(glosses) > 1 and len(gloss) + 2 + len(glosses[1]) <= MAX_GLOSS_LENGTH:
        gloss = gloss + ", " + glosses[1]
    if len(gloss) > MAX_GLOSS_LENGTH:
        gloss = re.sub(r"\s*\([^)]*\)", "", gloss).strip()
    if not gloss or len(gloss) > MAX_GLOSS_LENGTH * 2:
        raise Rejected("gloss too long")
    return gloss


def segments_for(token):
    stem, okurigana = split_word(token["surface"])
    segments = [("kanji", character) for character in stem]
    if okurigana:
        segments.append(("kana", okurigana))
    return segments


def check_written_characters(sentence, strokes):
    for character in sentence:
        if character in UNSTROKED_ALLOWED:
            continue
        if character not in strokes:
            raise Rejected("character without stroke data")
        if is_kanji(character):
            entry = strokes[character]
            if entry.get("grade") is None and entry.get("jlpt") is None:
                raise Rejected("rare kanji in sentence")


def check_context_words(tokens, by_spelling):
    for token in tokens:
        if not has_kanji(token["surface"]):
            continue
        head = token["b"]["head"] if token["b"] else None
        entries = by_spelling.get(head, [])
        if not any(kanji["common"] for entry in entries for kanji in entry["kanji"] if kanji["text"] == head):
            raise Rejected("uncommon word in sentence")
        if "を" in head or "が" in head or all(set(entry_pos(entry)) <= EXCLUDED_POS for entry in entries):
            raise Rejected("set phrase in sentence")


def kanji_difficulty(character, strokes):
    entry = strokes.get(character)
    if entry is None or character == "々":
        return None
    jlpt = entry.get("jlpt")
    grade = entry.get("grade")
    if jlpt in (5, 4, 3):
        return 5 - jlpt
    if grade is not None and grade <= 6:
        return 3
    return None


def build_prompt(prompt_id, example, tokens, target_index, gloss, segments, notes):
    before, reading, after = kana_sentence(tokens, target_index)
    return {
        "id": prompt_id,
        "before": before,
        "reading": reading,
        "after": after,
        "gloss": gloss,
        "segments": segments,
        "translation": example["english"],
        "tokens": [{"surface": token["surface"], "reading": token["reading"]} for token in tokens],
        "notes": notes,
    }


def build_legacy(examples, transcriptions, by_spelling):
    prompts = []
    lemmas = set()
    for legacy in LEGACY_PROMPTS:
        example = examples[legacy["tatoeba"]]
        sentence, tokens = tokenize(example, transcriptions[legacy["tatoeba"]], legacy.get("digits"), by_spelling)
        answer = "".join(text for _, text in legacy["segments"])
        target_indices = [index for index, token in enumerate(tokens) if token["surface"] == answer]
        if len(target_indices) != 1:
            sys.exit(f"{legacy['id']}: target {answer} not found as one token in {sentence}")
        prompt = build_prompt(
            legacy["id"], example, tokens, target_indices[0], legacy["gloss"], legacy["segments"], legacy["notes"]
        )
        for key in ("before", "reading", "after"):
            if prompt[key] != legacy[key]:
                sys.exit(f"{legacy['id']}: derived {key} {prompt[key]!r} differs from {legacy[key]!r}")
        b_token = tokens[target_indices[0]]["b"]
        if b_token is not None:
            lemmas.add(b_token["head"])
        lemmas.add(answer)
        prompts.append(prompt)
    return prompts, lemmas


def candidate_targets(example, transcriptions, strokes, by_spelling, homophones, entries):
    transcription = transcriptions.get(example["id"])
    if transcription is None:
        raise Rejected("no transcription")
    sentence, tokens = tokenize(example, transcription, None, by_spelling)
    check_written_characters(sentence, strokes)
    check_context_words(tokens, by_spelling)
    if not example["english"]:
        raise Rejected("no translation")
    results = []
    reasons = collections.Counter()
    for index, token in enumerate(tokens):
        if not has_kanji(token["surface"]):
            continue
        try:
            parts = split_word(token["surface"])
            if parts is None:
                raise Rejected("target shape")
            difficulties = [kanji_difficulty(character, strokes) for character in parts[0]]
            if None in difficulties:
                raise Rejected("target kanji above N3 and grade 6")
            if index > 0 and tokens[index - 1]["surface"] in PREFIXES:
                raise Rejected("target after an honorific prefix")
            entry, reading, head, stem = resolve_lemma(token, by_spelling)
            sense = entry["senses"][0]
            check_word_kind(entry, sense, reading, head, tokens, index, by_spelling)
            if sentence.count(stem) != 1:
                raise Rejected("target kanji repeated in sentence")
            check_ambiguity(entry, reading, head, token, homophones, entries)
            gloss = gloss_for(sense)
            kana_sentence(tokens, index)
            results.append({
                "index": index,
                "entry": entry,
                "head": head,
                "lemma_reading": reading["text"],
                "gloss": gloss,
                "difficulty": max(difficulties),
                "stem": stem,
                "rank": next(kanji["rank"] for kanji in entry["kanji"] if kanji["text"] == head),
                "everyday": 0 if next(kanji for kanji in entry["kanji"] if kanji["text"] == head)["ichi"] else 1,
            })
        except Rejected as rejection:
            reasons[str(rejection)] += 1
    return sentence, tokens, results, reasons


def new_notes(example, target, token):
    answer = token["surface"]
    head = target["head"]
    parts = [
        f"Tatoeba #{example['id']} (CC BY 2.0 FR): {example['japanese']} “{example['english']}”",
        "Kana from the Tatoeba furigana transcription.",
    ]
    stem, okurigana = split_word(answer)
    answer_text = f"Answer {answer}" + (f" ({head})" if head != answer else "")
    if okurigana:
        answer_text += f", okurigana {okurigana} shown"
    parts.append(answer_text + ".")
    parts.append(
        f"Only spelling: {head}. JMdict lists no other common word read {target['lemma_reading']} "
        f"with a kanji spelling, and no common alternative spelling."
    )
    return " ".join(parts)


def build_new(examples, transcriptions, strokes, by_spelling, homophones, entries, used_lemmas, legacy_ids):
    reasons = collections.Counter()
    pool = []
    proverbs = sorted({
        kanji["text"] for entry in entries.values() if any("proverb" in sense["misc"] for sense in entry["senses"])
        for kanji in entry["kanji"] if len(kanji["text"]) >= 4
    })
    for example_id in sorted(examples):
        example = examples[example_id]
        if example_id in legacy_ids or example_id in EXCLUDED_SENTENCES:
            continue
        sentence = example["japanese"]
        if not MIN_WRITTEN_LENGTH <= len(sentence) <= MAX_WRITTEN_LENGTH:
            reasons["sentence length"] += 1
            continue
        if not all(character in strokes or character in UNSTROKED_ALLOWED for character in sentence):
            reasons["character without stroke data"] += 1
            continue
        try:
            sentence, tokens, targets, target_reasons = candidate_targets(
                example, transcriptions, strokes, by_spelling, homophones, entries
            )
        except Rejected as rejection:
            reasons[str(rejection)] += 1
            continue
        reasons.update(f"target: {reason}" for reason in target_reasons)
        if not targets:
            reasons["no eligible target"] += 1
            continue
        if any(proverb in sentence for proverb in proverbs):
            reasons["proverb"] += 1
            continue
        for target in targets:
            pool.append((target["difficulty"], target["everyday"], target["rank"], len(sentence), example_id, target["index"], tokens, target))
    pool.sort(key=lambda item: item[:6])
    chosen = []
    used_sentences = set()
    kanji_use = collections.Counter()
    for _, _, _, _, example_id, index, tokens, target in pool:
        if len(chosen) >= NEW_PROMPT_COUNT:
            break
        if example_id in used_sentences or target["head"] in used_lemmas:
            continue
        if any(kanji_use[character] >= MAX_TARGETS_PER_KANJI for character in target["stem"]):
            continue
        used_sentences.add(example_id)
        used_lemmas.add(target["head"])
        kanji_use.update(target["stem"])
        chosen.append((example_id, index, tokens, target))
    prompts = []
    for example_id, index, tokens, target in sorted(chosen, key=lambda item: item[0]):
        example = examples[example_id]
        token = tokens[index]
        prompts.append(build_prompt(
            f"t{example_id}", example, tokens, index, target["gloss"], segments_for(token),
            new_notes(example, target, token),
        ))
    return prompts, reasons, len(pool)


def encode_string(text):
    return json.dumps(text, ensure_ascii=False)


def encode_prompt(prompt):
    segments = ", ".join("{ " + encode_string(kind) + ": " + encode_string(text) + " }" for kind, text in prompt["segments"])
    tokens = []
    for token in prompt["tokens"]:
        fields = ["\"surface\": " + encode_string(token["surface"])]
        if token["reading"] is not None:
            fields.append("\"reading\": " + encode_string(token["reading"]))
        tokens.append("{" + ", ".join(fields) + "}")
    lines = [
        f"    \"id\": {encode_string(prompt['id'])},",
        f"    \"before\": {encode_string(prompt['before'])},",
        f"    \"reading\": {encode_string(prompt['reading'])},",
        f"    \"after\": {encode_string(prompt['after'])},",
        f"    \"gloss\": {encode_string(prompt['gloss'])},",
        f"    \"segments\": [{segments}],",
        f"    \"translation\": {encode_string(prompt['translation'])},",
        f"    \"tokens\": [{', '.join(tokens)}],",
        f"    \"notes\": {encode_string(prompt['notes'])}",
    ]
    return "  {\n" + "\n".join(lines) + "\n  }"


def verify(prompts, strokes):
    answers = set()
    for prompt in prompts:
        written = "".join(token["surface"] for token in prompt["tokens"])
        kana = "".join(token["reading"] or token["surface"] for token in prompt["tokens"])
        if (prompt["before"] + prompt["reading"] + prompt["after"]).replace(" ", "") != kana:
            sys.exit(f"{prompt['id']}: kana sentence does not match the token readings")
        answer = "".join(text for _, text in prompt["segments"])
        if answer in answers:
            sys.exit(f"{prompt['id']}: duplicate answer {answer}")
        answers.add(answer)
        if answer not in written:
            sys.exit(f"{prompt['id']}: answer {answer} missing from {written}")
        for character in written:
            if character not in strokes and character not in UNSTROKED_ALLOWED:
                sys.exit(f"{prompt['id']}: {character} has no stroke data")
        for token in prompt["tokens"]:
            if has_kanji(token["surface"]) != (token["reading"] is not None):
                sys.exit(f"{prompt['id']}: reading presence wrong for {token['surface']}")


def main():
    if len(sys.argv) != 6:
        print(
            f"Usage: {sys.argv[0]} <examples.utf> <jpn_transcriptions.tsv> <JMdict_e> <kanji_strokes.json> <output.json>",
            file=sys.stderr,
        )
        sys.exit(1)
    examples_path, transcriptions_path, jmdict_path, strokes_path, output_path = sys.argv[1:]

    strokes = load_strokes(strokes_path)
    transcriptions = load_transcriptions(transcriptions_path)
    examples = load_examples(examples_path)
    entries = load_jmdict(jmdict_path)
    by_spelling, homophones = build_indexes(entries)
    print(f"Loaded {len(examples)} examples, {len(transcriptions)} transcriptions, {len(entries)} JMdict entries")

    legacy, used_lemmas = build_legacy(examples, transcriptions, by_spelling)
    legacy_ids = {item["tatoeba"] for item in LEGACY_PROMPTS}
    new, reasons, pool_size = build_new(
        examples, transcriptions, strokes, by_spelling, homophones, entries, used_lemmas, legacy_ids
    )
    if len(new) < NEW_PROMPT_COUNT:
        sys.exit(f"Only {len(new)} new prompts qualified, need {NEW_PROMPT_COUNT}")
    prompts = legacy + new
    verify(prompts, strokes)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("[\n" + ",\n".join(encode_prompt(prompt) for prompt in prompts) + "\n]\n")

    print(f"Wrote {len(prompts)} prompts ({len(legacy)} kept, {len(new)} new from {pool_size} candidates) to {output_path}")
    for reason, count in sorted(reasons.items(), key=lambda item: (-item[1], item[0])):
        print(f"  rejected {count}: {reason}")


if __name__ == "__main__":
    main()
