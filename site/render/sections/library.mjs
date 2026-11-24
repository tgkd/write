import { escapeHtml } from '../escape.mjs';
import { closeSection, openSection, practiceSheet, sectionHeader } from './parts.mjs';

export function renderLibrary(ctx) {
  const { t, config } = ctx;
  const cells = config.libraryCharacters
    .map((character, index) => `<li class="wall-cell" style="--cell:${index}">${practiceSheet(character, { className: 'practice-grid-small' })}</li>`)
    .join('');
  const stats = t.library.stats
    .map(
      (stat, index) =>
        `<div class="stat" data-animate style="--n:${index}"><dt class="stat-label">${escapeHtml(stat.label)}</dt><dd class="stat-value">${escapeHtml(stat.value)}</dd></div>`,
    )
    .join('');
  return [
    openSection('library'),
    sectionHeader({ id: 'library', eyebrow: t.library.eyebrow, title: t.library.title, lede: t.library.lede }),
    `<div class="glyph-wall" role="img" aria-label="${escapeHtml(t.library.glyphsLabel)}" data-replay><ul class="wall-grid" aria-hidden="true">${cells}</ul></div>`,
    `<dl class="stats">${stats}</dl>`,
    closeSection,
  ].join('');
}
