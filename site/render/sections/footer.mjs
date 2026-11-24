import { escapeHtml } from '../escape.mjs';
import { renderGlyph } from '../glyph.mjs';
import { languageLinks } from './parts.mjs';

const sources = [
  ['KanjiVG', 'https://kanjivg.tagaini.net/'],
  ['KANJIDIC2', 'https://www.edrdg.org/wiki/index.php/KANJIDIC_Project'],
];

export function renderFooter(ctx) {
  const { t, config } = ctx;
  const year = config.lastModified.slice(0, 4);
  const sourceLinks = sources.map(([name, href]) => `<li><a href="${href}" rel="noopener">${name}</a></li>`).join('');
  return [
    '<footer class="site-footer">',
    '<div class="footer-inner">',
    '<div class="footer-brand">',
    `<a class="brand" href="${ctx.locale.path}" aria-label="${escapeHtml(t.nav.home)}">${renderGlyph('書', { className: 'brand-mark' })}<span class="brand-name">${escapeHtml(config.appName)}</span></a>`,
    `<p class="footer-copyright">© ${year} ${escapeHtml(config.developerName)}</p>`,
    '</div>',
    '<ul class="footer-links">',
    `<li><a href="${config.privacyPath}">${escapeHtml(t.footer.privacy)}</a></li>`,
    `<li><a href="mailto:${config.contactEmail}">${escapeHtml(t.footer.contact)}: ${config.contactEmail}</a></li>`,
    '</ul>',
    `<nav class="footer-languages" aria-label="${escapeHtml(t.footer.languages)}"><p class="footer-heading">${escapeHtml(t.footer.languages)}</p><ul>${languageLinks(ctx, { short: false })}</ul></nav>`,
    '<div class="footer-legal">',
    `<p>${escapeHtml(t.footer.attribution)}</p>`,
    `<ul class="footer-sources">${sourceLinks}</ul>`,
    `<p>${escapeHtml(t.footer.trademark)}</p>`,
    '</div>',
    '</div>',
    '</footer>',
  ].join('');
}
