import { escapeHtml } from './escape.mjs';
import { renderGlyph } from './glyph.mjs';
import { renderTry } from './try.mjs';

export function renderBody(ctx) {
  return [
    '<main id="main">',
    `<h1>${escapeHtml(ctx.t.hero.title)}</h1>`,
    renderGlyph(ctx.config.heroCharacter, { label: ctx.t.hero.demoLabel }),
    renderTry(ctx),
    '</main>',
    `<script type="module" src="${ctx.asset('/assets/site.js')}"></script>`,
    `<script type="module" src="${ctx.asset('/assets/try.js')}"></script>`,
  ].join('\n');
}
