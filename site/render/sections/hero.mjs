import { escapeHtml } from '../escape.mjs';
import { deviceFigure, practiceSheet, storeButtons, storeNote } from './parts.mjs';

export function renderHero(ctx) {
  const { t } = ctx;
  const facts = t.hero.facts.map((fact) => `<li class="chip">${escapeHtml(fact)}</li>`).join('');
  return [
    '<section class="hero" aria-labelledby="hero-title">',
    '<div class="hero-inner">',
    '<div class="hero-copy">',
    `<p class="eyebrow">${escapeHtml(t.hero.eyebrow)}</p>`,
    `<h1 class="hero-title" id="hero-title">${escapeHtml(t.hero.title)}</h1>`,
    `<p class="lede hero-lede">${escapeHtml(t.hero.lede)}</p>`,
    `<div class="hero-actions">${storeButtons(ctx, t.store.badgeLabel, { size: 'large' })}${storeNote(ctx)}</div>`,
    `<ul class="chips">${facts}</ul>`,
    '</div>',
    '<div class="hero-art">',
    `<figure class="hero-sheet" data-replay>${practiceSheet(ctx.config.heroCharacter, { label: t.hero.demoLabel })}<figcaption class="hero-caption">${escapeHtml(t.hero.demoCaption)}</figcaption></figure>`,
    deviceFigure(ctx, 'home', t.hero.screenAlt, {
      sizes: '(min-width: 1152px) 13rem, (min-width: 960px) 17vw, 36vw',
      priority: true,
      className: 'hero-phone',
    }),
    '</div>',
    '</div>',
    '</section>',
  ].join('');
}
