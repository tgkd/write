#!/usr/bin/env python3
"""
Preprocess KanjiVG XML and KANJIDIC2 XML into a bundled JSON file.

Usage:
    python3 Scripts/preprocess_kanjivg.py <kanjivg.xml> <kanjidic2.xml> <output.json>

Merges stroke geometry from KanjiVG with readings, meanings, and metadata
from KANJIDIC2. JLPT levels use the community N5-N1 mapping from
Data/jlpt_levels.json (sourced from kanjiapi.dev) instead of the obsolete
4-level values in KANJIDIC2.
"""

import json
import os
import sys
import xml.etree.ElementTree as ET

NS = {"kvg": "http://kanjivg.tagaini.net"}


def extract_strokes(group_el):
    strokes = []
    stroke_counter = [0]

    def walk(el):
        if el.tag == "path":
            stroke_counter[0] += 1
            strokes.append({
                "strokeNumber": stroke_counter[0],
                "pathData": el.get("d", ""),
                "strokeType": el.get(f"{{{NS['kvg']}}}type"),
            })
        for child in el:
            walk(child)

    walk(group_el)
    return strokes


def extract_components(group_el):
    components = []
    for child in group_el:
        if child.tag != "g":
            continue
        element = child.get(f"{{{NS['kvg']}}}element")
        position = child.get(f"{{{NS['kvg']}}}position")
        if element is None and position is None:
            components.extend(extract_components(child))
            continue
        comp_strokes = extract_strokes(child)
        components.append({
            "element": element,
            "position": position,
            "strokes": comp_strokes,
        })
    return components


def process_kanji(kanji_el):
    kanji_id = kanji_el.get("id", "")
    code_point = kanji_id.replace("kvg:kanji_", "").lstrip("0") or "0"
    top_group = kanji_el.find("g")
    if top_group is None:
        return None
    element = top_group.get(f"{{{NS['kvg']}}}element")
    all_strokes = extract_strokes(top_group)
    if not all_strokes:
        return None
    components = extract_components(top_group)
    return {
        "codePoint": code_point,
        "element": element,
        "strokes": all_strokes,
        "components": components,
    }


def is_cjk_unified(code_point_hex):
    try:
        cp = int(code_point_hex, 16)
    except ValueError:
        return False
    return (0x4E00 <= cp <= 0x9FFF) or (0x3400 <= cp <= 0x4DBF)


def load_kanjidic2(path):
    """Parse KANJIDIC2 XML and return a dict keyed by lowercase hex code point."""
    tree = ET.parse(path)
    root = tree.getroot()
    result = {}

    for ch in root.findall("character"):
        ucs = ch.find(".//cp_value[@cp_type='ucs']")
        if ucs is None:
            continue
        code_point = ucs.text.lower()

        entry = {}

        misc = ch.find("misc")
        if misc is not None:
            grade_el = misc.find("grade")
            if grade_el is not None:
                entry["grade"] = int(grade_el.text)


            freq_el = misc.find("freq")
            if freq_el is not None:
                entry["freq"] = int(freq_el.text)

        rmgroup = ch.find(".//reading_meaning/rmgroup")
        if rmgroup is not None:
            on = [r.text for r in rmgroup.findall("reading[@r_type='ja_on']") if r.text]
            kun = [r.text for r in rmgroup.findall("reading[@r_type='ja_kun']") if r.text]
            meanings = [m.text for m in rmgroup.findall("meaning") if m.get("m_lang") is None and m.text]

            if on:
                entry["onYomi"] = on
            if kun:
                entry["kunYomi"] = kun
            if meanings:
                entry["meanings"] = meanings

        if entry:
            result[code_point] = entry

    return result


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <kanjivg.xml> <kanjidic2.xml> <output.json>", file=sys.stderr)
        sys.exit(1)
    kanjivg_path = sys.argv[1]
    kanjidic2_path = sys.argv[2]
    output_path = sys.argv[3]

    jlpt_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "jlpt_levels.json")
    with open(jlpt_path, encoding="utf-8") as f:
        jlpt_map = json.load(f)
    print(f"Loaded {len(jlpt_map)} JLPT N5-N1 mappings")

    kanjidic2 = load_kanjidic2(kanjidic2_path)
    print(f"Loaded {len(kanjidic2)} entries from KANJIDIC2")

    tree = ET.parse(kanjivg_path)
    root = tree.getroot()

    result = {}
    total = 0
    skipped = 0
    enriched = 0
    for kanji_el in root.findall("kanji"):
        total += 1
        data = process_kanji(kanji_el)
        if data is None:
            skipped += 1
            continue
        if not is_cjk_unified(data["codePoint"]):
            skipped += 1
            continue

        metadata = kanjidic2.get(data["codePoint"], {})
        if metadata:
            data.update(metadata)
            enriched += 1

        jlpt_level = jlpt_map.get(data["codePoint"])
        if jlpt_level is not None:
            data["jlpt"] = jlpt_level

        result[data["codePoint"]] = data

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))

    print(f"Processed {total} entries, kept {len(result)} CJK kanji, skipped {skipped}")
    print(f"Enriched {enriched} entries with KANJIDIC2 metadata")


if __name__ == "__main__":
    main()
