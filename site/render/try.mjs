import { escapeHtml, fillPlaceholders, jsonForScript } from './escape.mjs';
import { glyphViewBox, renderGlyph } from './glyph.mjs';

const browserStrings = [
  'canvasLabel',
  'instruction',
  'accepted',
  'wrongOrder',
  'wrongDirection',
  'wrongShape',
  'done',
  'guideOn',
  'guideOff',
];

function renderGuides(characters) {
  return characters
    .map(
      (character, index) =>
        `<div class="try-layer try-guide" data-character="${escapeHtml(character)}"${index === 0 ? '' : ' hidden'}>${renderGlyph(character)}</div>`,
    )
    .join('');
}

function renderGrid() {
  return `<svg class="try-layer try-grid" viewBox="${glyphViewBox}" aria-hidden="true" focusable="false"><line x1="54.5" y1="0" x2="54.5" y2="109"></line><line x1="0" y1="54.5" x2="109" y2="54.5"></line></svg>`;
}

function renderInk() {
  return `<svg class="try-layer try-ink" viewBox="${glyphViewBox}" aria-hidden="true" focusable="false"><g class="try-written"></g><g class="try-trail"></g><circle class="try-start" r="3.4" cx="0" cy="0" visibility="hidden"></circle></svg>`;
}

function renderButton(action, text, extra = '') {
  return `<button type="button" class="button button-quiet try-button" data-action="${action}"${extra}>${escapeHtml(text)}</button>`;
}

export function renderTry(ctx) {
  const strings = ctx.t.try;
  const characters = ctx.config.tryCharacters;
  const payload = {
    characters,
    strings: Object.fromEntries(browserStrings.map((key) => [key, strings[key]])),
  };
  const boardLabel = fillPlaceholders(strings.canvasLabel, { character: characters[0] });
  return `<section class="try section" id="try" aria-labelledby="try-title">
<div class="section-inner try-inner">
<div class="try-intro">
<p class="eyebrow">${escapeHtml(strings.eyebrow)}</p>
<h2 class="section-title" id="try-title">${escapeHtml(strings.title)}</h2>
<p class="lede">${escapeHtml(strings.lede)}</p>
</div>
<div class="try-demo" data-try>
<div class="try-stage">
<div class="try-board" role="img" aria-label="${escapeHtml(boardLabel)}">${renderGrid()}${renderGuides(characters)}${renderInk()}</div>
<p class="try-feedback" aria-live="polite"></p>
</div>
<p class="try-instruction" aria-live="polite"><noscript>${escapeHtml(strings.noScript)}</noscript></p>
<div class="try-controls">${renderButton('hint', strings.hint)}${renderButton('guide', strings.guideOn, ' aria-pressed="true"')}${renderButton('reset', strings.reset)}${renderButton('next', strings.next)}</div>
<script type="application/json" class="try-data">${jsonForScript(payload)}</script>
</div>
</div>
</section>`;
}
