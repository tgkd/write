#!/usr/bin/env swift
/**
 Preprocess KanjiVG XML into a bundled JSON file for the Write app.

 Usage:
     swift Scripts/preprocess_kanjivg.swift <kanjivg.xml> <output.json>

 See Scripts/preprocess_kanjivg.py for the primary (Python) implementation.
 This Swift script produces identical output and can be used as a build phase.
*/

import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

struct KanjiStrokeJSON: Codable {
    let strokeNumber: Int
    let pathData: String
    let strokeType: String?
}

struct KanjiComponentJSON: Codable {
    let element: String?
    let position: String?
    let strokes: [KanjiStrokeJSON]
}

struct KanjiDataJSON: Codable {
    let codePoint: String
    let element: String?
    let strokes: [KanjiStrokeJSON]
    let components: [KanjiComponentJSON]
}

let kvgNS = "http://kanjivg.tagaini.net"

func extractStrokes(from node: XMLNode) -> [KanjiStrokeJSON] {
    guard let element = node as? XMLElement else { return [] }
    var strokes: [KanjiStrokeJSON] = []
    var counter = 0

    func walk(_ el: XMLElement) {
        if el.name == "path" {
            counter += 1
            let d = el.attribute(forName: "d")?.stringValue ?? ""
            let strokeType = el.attribute(forLocalName: "type", uri: kvgNS)?.stringValue
            strokes.append(KanjiStrokeJSON(strokeNumber: counter, pathData: d, strokeType: strokeType))
        }
        for child in el.children ?? [] {
            if let childEl = child as? XMLElement {
                walk(childEl)
            }
        }
    }

    walk(element)
    return strokes
}

func extractComponents(from node: XMLElement) -> [KanjiComponentJSON] {
    var components: [KanjiComponentJSON] = []
    for child in node.children ?? [] {
        guard let childEl = child as? XMLElement, childEl.name == "g" else { continue }
        let el = childEl.attribute(forLocalName: "element", uri: kvgNS)?.stringValue
        let pos = childEl.attribute(forLocalName: "position", uri: kvgNS)?.stringValue
        if el == nil && pos == nil {
            components.append(contentsOf: extractComponents(from: childEl))
            continue
        }
        let compStrokes = extractStrokes(from: childEl)
        components.append(KanjiComponentJSON(element: el, position: pos, strokes: compStrokes))
    }
    return components
}

func isCJKUnified(_ hex: String) -> Bool {
    guard let cp = UInt32(hex, radix: 16) else { return false }
    return (0x4E00...0x9FFF).contains(cp) || (0x3400...0x4DBF).contains(cp)
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: \(CommandLine.arguments[0]) <kanjivg.xml> <output.json>\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

let xmlData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
let doc = try XMLDocument(data: xmlData, options: [])
guard let root = doc.rootElement() else {
    fputs("No root element found\n", stderr)
    exit(1)
}

var result: [String: KanjiDataJSON] = [:]
var total = 0
var skipped = 0

for kanjiNode in root.children ?? [] {
    guard let kanjiEl = kanjiNode as? XMLElement, kanjiEl.name == "kanji" else { continue }
    total += 1
    let kanjiId = kanjiEl.attribute(forName: "id")?.stringValue ?? ""
    var codePoint = kanjiId.replacingOccurrences(of: "kvg:kanji_", with: "")
    while codePoint.hasPrefix("0") && codePoint.count > 1 {
        codePoint.removeFirst()
    }
    guard let topGroup = kanjiEl.elements(forName: "g").first else {
        skipped += 1
        continue
    }
    let element = topGroup.attribute(forLocalName: "element", uri: kvgNS)?.stringValue
    let allStrokes = extractStrokes(from: topGroup)
    guard !allStrokes.isEmpty else {
        skipped += 1
        continue
    }
    guard isCJKUnified(codePoint) else {
        skipped += 1
        continue
    }
    let components = extractComponents(from: topGroup)
    let data = KanjiDataJSON(codePoint: codePoint, element: element, strokes: allStrokes, components: components)
    result[codePoint] = data
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.withoutEscapingSlashes]
let jsonData = try encoder.encode(result)
try jsonData.write(to: URL(fileURLWithPath: outputPath))

print("Processed \(total) entries, kept \(result.count) CJK kanji, skipped \(skipped)")
