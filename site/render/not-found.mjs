import { escapeHtml } from './escape.mjs';
import { practiceSheet } from './sections/parts.mjs';

export function renderNotFound(ctx) {
  const { t } = ctx;
  return {
    head: [
      '<meta charset="UTF-8">',
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
      '<meta name="robots" content="noindex">',
      `<title>${escapeHtml(t.notFound.title)}</title>`,
      `<link rel="stylesheet" href="${ctx.asset('/assets/site.css')}">`,
    ].join('\n'),
    body: [
      '<main id="main" class="not-found">',
      `<div class="not-found-sheet">${practiceSheet(ctx.config.heroCharacter)}</div>`,
      `<h1 class="section-title">${escapeHtml(t.notFound.title)}</h1>`,
      `<p class="lede">${escapeHtml(t.notFound.body)}</p>`,
      `<p><a class="button button-primary" href="/">${escapeHtml(t.notFound.home)}</a></p>`,
      '</main>',
    ].join('\n'),
  };
}
