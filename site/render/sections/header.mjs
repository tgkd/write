import { appStoreUrl } from '../../config.mjs';
import { escapeHtml } from '../escape.mjs';
import { renderGlyph } from '../glyph.mjs';
import { languageLinks } from './parts.mjs';

export function renderHeader(ctx) {
  const { t } = ctx;
  const navItems = [
    ['#checks', t.nav.features],
    ['#try', t.nav.tryIt],
    ['#ipad', t.nav.ipad],
    ['#faq', t.nav.faq],
  ]
    .map(([href, label]) => `<li><a href="${href}">${escapeHtml(label)}</a></li>`)
    .join('');
  return [
    `<a class="skip-link" href="#main">${escapeHtml(t.nav.skipToContent)}</a>`,
    '<header class="site-header">',
    '<div class="site-header-inner">',
    `<a class="brand" href="${ctx.locale.path}" aria-label="${escapeHtml(t.nav.home)}">${renderGlyph('書', { className: 'brand-mark' })}<span class="brand-name">${escapeHtml(ctx.config.appName)}</span></a>`,
    `<nav class="site-nav"><ul class="nav-list">${navItems}</ul></nav>`,
    `<nav class="lang-switch" aria-label="${escapeHtml(t.nav.language)}"><ul class="lang-list">${languageLinks(ctx, { short: true })}</ul></nav>`,
    `<a class="button button-primary button-small header-download" href="${appStoreUrl(ctx.locale)}">${escapeHtml(t.nav.download)}</a>`,
    '</div>',
    '</header>',
  ].join('');
}
