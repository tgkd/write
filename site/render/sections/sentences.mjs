import { escapeHtml } from '../escape.mjs';
import { closeSection, deviceFigure, openSection, sectionHeader } from './parts.mjs';

export function renderSentences(ctx) {
  const { t } = ctx;
  const points = t.sentences.points.map((point) => `<li>${escapeHtml(point)}</li>`).join('');
  return [
    openSection('sentences'),
    '<div class="split">',
    '<div class="split-copy">',
    sectionHeader({ id: 'sentences', eyebrow: t.sentences.eyebrow, title: t.sentences.title, lede: t.sentences.lede }),
    `<ol class="point-list" data-animate>${points}</ol>`,
    '</div>',
    `<div class="split-media" data-animate>${deviceFigure(ctx, 'ipad-writing', t.sentences.screenAlt, { sizes: '(min-width: 1152px) 40rem, (min-width: 960px) 55vw, 92vw' })}</div>`,
    '</div>',
    closeSection,
  ].join('');
}
