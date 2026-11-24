import { escapeHtml } from '../escape.mjs';
import { closeSection, openSection, sectionHeader } from './parts.mjs';

export function renderFaq(ctx) {
  const { t } = ctx;
  const items = t.faq.items
    .map(
      (item) =>
        `<details class="faq-item"><summary><h3 class="faq-question">${escapeHtml(item.q)}</h3><span class="faq-marker" aria-hidden="true"></span></summary><p class="faq-answer">${escapeHtml(item.a)}</p></details>`,
    )
    .join('');
  return [
    openSection('faq'),
    '<div class="faq-layout">',
    sectionHeader({ id: 'faq', eyebrow: t.faq.eyebrow, title: t.faq.title, className: 'faq-header' }),
    `<div class="faq-list">${items}</div>`,
    '</div>',
    closeSection,
  ].join('');
}
