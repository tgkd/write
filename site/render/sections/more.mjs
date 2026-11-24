import { escapeHtml } from '../escape.mjs';
import { closeSection, openSection, sectionHeader, twoDigits } from './parts.mjs';

export function renderMore(ctx) {
  const { t } = ctx;
  const items = t.more.items
    .map(
      (item, index) =>
        `<li class="feature" data-animate style="--n:${index % 3}"><p class="feature-index" aria-hidden="true">${twoDigits(index)}</p><h3 class="item-title">${escapeHtml(item.title)}</h3><p class="item-body">${escapeHtml(item.body)}</p></li>`,
    )
    .join('');
  return [
    openSection('more'),
    sectionHeader({ id: 'more', eyebrow: t.more.eyebrow, title: t.more.title }),
    `<ul class="feature-grid feature-grid-3">${items}</ul>`,
    closeSection,
  ].join('');
}
