#!/usr/bin/env python3
"""
Preprocess KanjiVG XML and KANJIDIC2 XML into a bundled kanji and kana JSON file.

Usage:
    python3 Scripts/preprocess_kanjivg.py <kanjivg.xml> <kanjidic2.xml> <output.json>

Merges stroke geometry from KanjiVG with readings, meanings, and metadata
from KANJIDIC2. JLPT levels use the community N5-N1 mapping from
Data/jlpt_levels.json (sourced from kanjiapi.dev) instead of the obsolete
4-level values in KANJIDIC2.
"""

import json
import math
import re
import os
import sys
import xml.etree.ElementTree as ET

NS = {"kvg": "http://kanjivg.tagaini.net"}
EXCLUDED_CODE_POINTS = {"534d"}
YOON_SMALL_BIG_RATIO = 0.72


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


def parse_path(d):
    tokens = re.findall(r'[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?', d)
    i = 0
    cmd = None
    pos = 0j
    result = []
    while i < len(tokens):
        if tokens[i].isalpha():
            cmd = tokens[i]
            i += 1
        op = cmd.upper()
        if op not in ('M','C'):
            raise ValueError('Unsupported SVG command: '+cmd)
        n = {'M':2,'C':6}[op]
        values = [float(x) for x in tokens[i:i+n]]
        if len(values) != n:
            raise ValueError(d)
        i += n
        relative = cmd.islower()
        points = [complex(values[k],values[k+1])+(pos if relative else 0) for k in range(0,n,2)]
        end = points[-1]
        if op == 'M':
            result.append(('M',end))
            cmd = 'l' if relative else 'L'
        else:
            result.append((op,pos,*points))
        pos = end
    return result

def point(seg,t):
    if seg[0] == 'C':
        a,b,c,d = seg[1:]
        return (1-t)**3*a+3*(1-t)**2*t*b+3*(1-t)*t*t*c+t**3*d
    return seg[1]*(1-t)+seg[2]*t

def extrema(seg):
    if seg[0] == 'M':
        return [seg[1]]
    ts = [0.,1.]
    if seg[0] == 'C':
        for component in ('real','imag'):
            p = [getattr(z,component) for z in seg[1:]]
            a = -p[0]+3*p[1]-3*p[2]+p[3]
            b = 2*(p[0]-2*p[1]+p[2])
            c = p[1]-p[0]
            roots = []
            if abs(a)<1e-12:
                if abs(b)>1e-12:
                    roots = [-c/b]
            elif b*b-4*a*c>=0:
                root = math.sqrt(b*b-4*a*c)
                roots = [(-b+root)/(2*a),(-b-root)/(2*a)]
            ts.extend(t for t in roots if 0<t<1)
    return [point(seg,t) for t in ts]

def bounds(paths):
    pts = [z for path in paths for seg in path for z in extrema(seg)]
    return min(z.real for z in pts),min(z.imag for z in pts),max(z.real for z in pts),max(z.imag for z in pts)

def dimensions(paths):
    x,y,r,b = bounds(paths)
    return r-x,b-y

def transform(paths,s,tx,ty):
    return [ [(seg[0],*(z*s+complex(tx,ty) for z in seg[1:])) for seg in path] for path in paths]

def serialize(path):
    def xy(z):
        return f'{z.real:.8f},{z.imag:.8f}'
    return ' '.join(seg[0]+' '.join(xy(z) for z in (seg[1:] if seg[0]=='M' else seg[2:])) for seg in path)

def compose_yoon(code_point, romaji, glyphs):
    keys = code_point.split("-")
    sources = [glyphs[key] for key in keys]
    paths = [[parse_path(stroke["pathData"]) for stroke in source["strokes"]] for source in sources]
    big_bounds, small_bounds = [bounds(group) for group in paths]
    bw, bh = dimensions(paths[0])
    sw, sh = dimensions(paths[1])
    bm, sm = max(bw, bh), max(sw, sh)
    length = min(82.0, 85.0 / (bw / bm + YOON_SMALL_BIG_RATIO * sw / sm))
    big_scale = length / bm
    small_scale = length * YOON_SMALL_BIG_RATIO / sm
    positions = [(8.0, 101.0 - bh * big_scale), (16.0 + bw * big_scale, 101.0 - sh * small_scale)]
    strokes = []
    for source, group, box, scale, (x, y) in zip(
        sources, paths, [big_bounds, small_bounds], [big_scale, small_scale], positions
    ):
        placed = transform(group, scale, x - box[0] * scale, y - box[1] * scale)
        for stroke, path in zip(source["strokes"], placed):
            strokes.append({
                "strokeNumber": len(strokes) + 1,
                "pathData": serialize(path),
                "strokeType": stroke["strokeType"],
            })
    return {
        "codePoint": code_point,
        "element": "".join(chr(int(key, 16)) for key in keys),
        "strokes": strokes,
        "components": [],
        "romaji": romaji,
    }


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

    kana_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kana_romaji.json")
    with open(kana_path, encoding="utf-8") as f:
        kana_map = json.load(f)

    yoon_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "yoon_romaji.json")
    with open(yoon_path, encoding="utf-8") as f:
        yoon_map = json.load(f)
    yoon_glyph_keys = {key for combination in yoon_map for key in combination.split("-")}
    yoon_glyphs = {}

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
        code_point = data["codePoint"]
        if code_point in yoon_glyph_keys:
            yoon_glyphs[code_point] = data
        if code_point in EXCLUDED_CODE_POINTS:
            skipped += 1
            continue
        if code_point in kana_map:
            data["romaji"] = kana_map[code_point]
        elif is_cjk_unified(code_point) or "grade" in kanjidic2.get(code_point, {}):
            metadata = kanjidic2.get(code_point, {})
            if metadata:
                data.update(metadata)
                enriched += 1

            jlpt_level = jlpt_map.get(code_point)
            if jlpt_level is not None:
                data["jlpt"] = jlpt_level
        else:
            skipped += 1
            continue

        result[code_point] = data

    missing = kana_map.keys() - result.keys()
    if missing:
        characters = ", ".join(chr(int(cp, 16)) for cp in sorted(missing))
        sys.exit(f"Missing kana from KanjiVG: {characters}")

    missing = yoon_glyph_keys - yoon_glyphs.keys()
    if missing:
        sys.exit(f"Missing yoon glyphs from KanjiVG: {', '.join(sorted(missing))}")
    for code_point, romaji in yoon_map.items():
        result[code_point] = compose_yoon(code_point, romaji, yoon_glyphs)

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))

    print(f"Processed {total} entries, kept {len(result) - len(kana_map) - len(yoon_map)} CJK kanji, {len(kana_map)} kana and {len(yoon_map)} yoon, skipped {skipped}")
    print(f"Enriched {enriched} entries with KANJIDIC2 metadata")


if __name__ == "__main__":
    main()
