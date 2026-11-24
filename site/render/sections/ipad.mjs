import { escapeHtml } from '../escape.mjs';
import { closeSection, deviceFigure, openSection, sectionHeader, twoDigits } from './parts.mjs';

export function renderIpad(ctx) {
  const { t } = ctx;
  const items = t.ipad.items
    .map(
      (item, index) =>
        `<li class="feature" data-animate style="--n:${index}"><p class="feature-index" aria-hidden="true">${twoDigits(index)}</p><h3 class="item-title">${escapeHtml(item.title)}</h3><p class="item-body">${escapeHtml(item.body)}</p></li>`,
    )
    .join('');
  return [
    openSection('ipad', 'section-inverse'),
    sectionHeader({ id: 'ipad', eyebrow: t.ipad.eyebrow, title: t.ipad.title, lede: t.ipad.lede }),
    `<div class="ipad-stage" data-animate>${deviceFigure(ctx, 'ipad-home', t.ipad.homeAlt, { sizes: '(min-width: 1152px) 72rem, 94vw' })}</div>`,
    '<div class="ipad-details">',
    `<ul class="feature-grid">${items}</ul>`,
    `<div class="ipad-notebook" data-animate>${deviceFigure(ctx, 'ipad-notebook', t.ipad.notebookAlt, { sizes: '(min-width: 1152px) 34rem, (min-width: 960px) 46vw, 92vw' })}</div>`,
    '</div>',
    closeSection,
  ].join('');
}
