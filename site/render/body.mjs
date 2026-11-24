import { renderChecks } from './sections/checks.mjs';
import { renderCta } from './sections/cta.mjs';
import { renderFaq } from './sections/faq.mjs';
import { renderFooter } from './sections/footer.mjs';
import { renderGuides } from './sections/guides.mjs';
import { renderHeader } from './sections/header.mjs';
import { renderHero } from './sections/hero.mjs';
import { renderIpad } from './sections/ipad.mjs';
import { renderLibrary } from './sections/library.mjs';
import { renderMore } from './sections/more.mjs';
import { renderPractice } from './sections/practice.mjs';
import { renderSentences } from './sections/sentences.mjs';
import { renderTry } from './try.mjs';

export function renderBody(ctx) {
  return [
    renderHeader(ctx),
    '<main id="main" tabindex="-1">',
    renderHero(ctx),
    renderChecks(ctx),
    renderTry(ctx),
    renderGuides(ctx),
    renderPractice(ctx),
    renderSentences(ctx),
    renderIpad(ctx),
    renderLibrary(ctx),
    renderMore(ctx),
    renderFaq(ctx),
    renderCta(ctx),
    '</main>',
    renderFooter(ctx),
    `<script type="module" src="${ctx.asset('/assets/site.js')}"></script>`,
    `<script type="module" src="${ctx.asset('/assets/try.js')}"></script>`,
  ].join('\n');
}
