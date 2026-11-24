import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { escapeHtml } from './escape.mjs';

const renderDir = dirname(fileURLToPath(import.meta.url));
const characters = JSON.parse(readFileSync(join(renderDir, '..', 'strokes', 'characters.json'), 'utf8'));

export const glyphViewBox = '0 0 109 109';

export function glyphData(character) {
  const data = characters[character];
  if (!data) {
    throw new Error(`No stroke data for ${character}. Add it to config.mjs and run site/strokes/extract.mjs`);
  }
  return data;
}

export function renderGlyph(character, { className = '', label = null } = {}) {
  const data = glyphData(character);
  const classes = ['glyph', className].filter(Boolean).join(' ');
  const accessibility = label
    ? `role="img" aria-label="${escapeHtml(label)}"`
    : 'aria-hidden="true" focusable="false"';
  const paths = data.strokes
    .map(
      (pathData, index) =>
        `<path class="glyph-stroke" d="${escapeHtml(pathData)}" pathLength="1" data-stroke="${index + 1}" style="--i:${index}"></path>`,
    )
    .join('');
  return `<svg class="${classes}" viewBox="${glyphViewBox}" data-glyph="${escapeHtml(character)}" style="--stroke-count:${data.strokes.length}" ${accessibility}>${paths}</svg>`;
}
