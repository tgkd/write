import { escapeHtml } from '../escape.mjs';
import { closeSection, deviceFigure, openSection, sectionHeader } from './parts.mjs';

const guideScreens = ['trace', 'guided', 'copy'];

export function renderGuides(ctx) {
  const { t } = ctx;
  const items = t.guides.items
    .map(
      (item, index) =>
        `<li class="panel guide-card" data-animate style="--n:${index}">${deviceFigure(ctx, guideScreens[index], item.screenAlt, { sizes: '(min-width: 720px) 15rem, 64vw', className: 'card-phone' })}<div class="card-copy"><p class="chip chip-solid">${escapeHtml(item.name)}</p><h3 class="item-title">${escapeHtml(item.title)}</h3><p class="item-body">${escapeHtml(item.body)}</p></div></li>`,
    )
    .join('');
  return [
    openSection('guides'),
    sectionHeader({ id: 'guides', eyebrow: t.guides.eyebrow, title: t.guides.title, lede: t.guides.lede }),
    `<ol class="card-row card-row-3">${items}</ol>`,
    closeSection,
  ].join('');
}
