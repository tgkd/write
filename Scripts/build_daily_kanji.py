import hashlib
import json
import sys


def daily_entry(entry):
    code_point = entry["codePoint"]
    result = {
        "codePoint": code_point,
        "character": chr(int(code_point, 16)),
        "meanings": entry["meanings"][:2],
    }
    on_yomi = entry.get("onYomi") or []
    if on_yomi:
        result["onYomi"] = on_yomi[0]
    kun_yomi = entry.get("kunYomi") or []
    if kun_yomi:
        result["kunYomi"] = kun_yomi[0]
    result["strokeCount"] = len(entry["strokes"])
    result["jlpt"] = entry["jlpt"]
    return result


def shuffle_key(entry):
    return hashlib.sha256(entry["codePoint"].encode()).hexdigest()


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <kanji_strokes.json> <output.json>", file=sys.stderr)
        sys.exit(1)
    input_path = sys.argv[1]
    output_path = sys.argv[2]

    with open(input_path, encoding="utf-8") as f:
        source = json.load(f)

    kept = [entry for entry in source.values() if entry.get("jlpt") is not None]

    missing = [entry["codePoint"] for entry in kept if not entry.get("meanings")]
    if missing:
        characters = ", ".join(chr(int(cp, 16)) for cp in sorted(missing))
        sys.exit(f"JLPT kanji without meanings: {characters}")

    result = [daily_entry(entry) for entry in sorted(kept, key=shuffle_key)]

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))

    levels = ", ".join(
        f"N{level} {sum(1 for entry in result if entry['jlpt'] == level)}" for level in range(5, 0, -1)
    )
    print(f"Wrote {len(result)} daily kanji ({levels}) to {output_path}")


if __name__ == "__main__":
    main()
