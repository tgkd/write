import { escapeHtml } from '../escape.mjs';
import { practiceSheet, storeButtons, storeNote } from './parts.mjs';

export function renderCta(ctx) {
  const { t } = ctx;
  return [
    '<section class="section section-cta" id="download" aria-labelledby="download-title">',
    '<div class="section-inner cta-inner">',
    `<div class="cta-sheet" data-replay>${practiceSheet('書')}</div>`,
    '<div class="cta-copy" data-animate>',
    `<h2 class="cta-title section-title" id="download-title">${escapeHtml(t.cta.title)}</h2>`,
    `<p class="lede">${escapeHtml(t.cta.lede)}</p>`,
    `<div class="cta-actions">${storeButtons(ctx, t.cta.button, { size: 'large' })}</div>`,
    storeNote(ctx),
    '</div>',
    '</div>',
    '</section>',
  ].join('');
}
