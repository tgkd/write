import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { allCharacters } from '../config.mjs';

const strokesDir = dirname(fileURLToPath(import.meta.url));
const sourcePath = join(strokesDir, '..', '..', 'Write', 'Resources', 'kanji_strokes.json');
const outputPath = join(strokesDir, 'characters.json');

const source = JSON.parse(readFileSync(sourcePath, 'utf8'));
const output = {};

for (const character of allCharacters()) {
  const codePoint = character.codePointAt(0).toString(16).padStart(4, '0');
  const record = source[codePoint];
  if (!record) {
    throw new Error(`No stroke data for ${character} (${codePoint})`);
  }
  output[character] = {
    character,
    codePoint,
    strokes: record.strokes.map((stroke) => stroke.pathData),
    meanings: record.meanings ?? [],
    romaji: record.romaji ?? null,
    jlpt: record.jlpt ?? null,
  };
}

writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`);
console.log(`Wrote ${Object.keys(output).length} characters to ${outputPath}`);
