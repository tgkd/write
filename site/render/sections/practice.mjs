import { escapeHtml } from '../escape.mjs';
import { closeSection, deviceFigure, openSection, sectionHeader } from './parts.mjs';

const practiceScreens = ['home', 'review'];

export function renderPractice(ctx) {
  const { t } = ctx;
  const items = t.practice.items
    .map(
      (item, index) =>
        `<li class="panel practice-card" data-animate style="--n:${index}"><div class="card-copy"><p class="chip chip-solid">${escapeHtml(item.name)}</p><h3 class="item-title">${escapeHtml(item.title)}</h3><p class="item-body">${escapeHtml(item.body)}</p></div>${deviceFigure(ctx, practiceScreens[index], item.screenAlt, { sizes: '(min-width: 720px) 15rem, 64vw', className: 'card-phone' })}</li>`,
    )
    .join('');
  const points = t.practice.points.map((point) => `<li>${escapeHtml(point)}</li>`).join('');
  return [
    openSection('practice'),
    sectionHeader({ id: 'practice', eyebrow: t.practice.eyebrow, title: t.practice.title, lede: t.practice.lede }),
    `<ul class="card-row card-row-2">${items}</ul>`,
    '<div class="practice-progress" data-animate>',
    `<ol class="point-list">${points}</ol>`,
    deviceFigure(ctx, 'progress', t.practice.progressAlt, { sizes: '(min-width: 720px) 16rem, 64vw', className: 'progress-phone' }),
    '</div>',
    closeSection,
  ].join('');
}
