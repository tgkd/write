#!/usr/bin/env python3
"""
Preprocess KanjiVG XML into a bundled JSON file for the Write app.

Usage:
    python3 Scripts/preprocess_kanjivg.py <kanjivg.xml> <output.json>

Input: KanjiVG combined XML file (all kanji in one file)
Output: JSON keyed by Unicode code point hex string, e.g.:
{
  "4eee": {
    "codePoint": "4eee",
    "element": "仮",
    "strokes": [
      {"strokeNumber": 1, "pathData": "M32.01,17c...", "strokeType": "㇒"},
      ...
    ],
    "components": [
      {"element": "亻", "position": "left", "strokes": [...]},
      ...
    ]
  }
}
"""

import json
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


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <kanjivg.xml> <output.json>", file=sys.stderr)
        sys.exit(1)
    input_path = sys.argv[1]
    output_path = sys.argv[2]

    tree = ET.parse(input_path)
    root = tree.getroot()

    result = {}
    total = 0
    skipped = 0
    for kanji_el in root.findall("kanji"):
        total += 1
        data = process_kanji(kanji_el)
        if data is None:
            skipped += 1
            continue
        if not is_cjk_unified(data["codePoint"]):
            skipped += 1
            continue
        result[data["codePoint"]] = data

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))

    print(f"Processed {total} entries, kept {len(result)} CJK kanji, skipped {skipped}")


if __name__ == "__main__":
    main()
