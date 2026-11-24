import { escapeHtml } from './escape.mjs';

export function renderTry(ctx) {
  return `<section class="try" id="try" aria-labelledby="try-title"><h2 id="try-title">${escapeHtml(ctx.t.try.title)}</h2></section>`;
}
