import { appStoreUrl } from '../../config.mjs';
import { screen } from '../../images/screens.mjs';
import { escapeHtml } from '../escape.mjs';
import { renderGlyph } from '../glyph.mjs';

export function sectionHeader({ id, eyebrow, title, lede = null, className = '' }) {
  const classes = ['section-header', className].filter(Boolean).join(' ');
  const ledeHtml = lede ? `<p class="lede">${escapeHtml(lede)}</p>` : '';
  return `<header class="${classes}" data-animate><p class="eyebrow">${escapeHtml(eyebrow)}</p><h2 class="section-title" id="${id}-title">${escapeHtml(title)}</h2>${ledeHtml}</header>`;
}

export function openSection(id, className = '') {
  const classes = ['section', `section-${id}`, className].filter(Boolean).join(' ');
  return `<section class="${classes}" id="${id}" aria-labelledby="${id}-title"><div class="section-inner">`;
}

export const closeSection = '</div></section>';

export function deviceFigure(ctx, name, alt, { sizes, priority = false, cropTop = false, className = '' }) {
  const shot = screen(name, ctx.locale.screens);
  const classes = ['device', `device-${shot.device}`, cropTop ? 'device-crop-top' : '', className].filter(Boolean).join(' ');
  const loading = priority ? 'fetchpriority="high" decoding="async"' : 'loading="lazy" decoding="async"';
  return `<figure class="${classes}"><div class="device-body"><div class="device-screen"><img src="${shot.src}" srcset="${shot.srcset}" sizes="${sizes}" width="${shot.width}" height="${shot.height}" alt="${escapeHtml(alt)}" ${loading}></div></div></figure>`;
}

export function storeButtons(ctx, label, { size = '' } = {}) {
  const sizeClass = size ? ` button-${size}` : '';
  const appStore = `<a class="button button-primary${sizeClass}" href="${appStoreUrl(ctx.locale)}">${escapeHtml(label)}</a>`;
  const play = ctx.config.playUrl
    ? `<a class="button button-quiet${sizeClass}" href="${escapeHtml(ctx.config.playUrl)}">Google Play</a>`
    : '';
  return appStore + play;
}

export function storeNote(ctx) {
  return `<p class="store-note"><strong>${escapeHtml(ctx.t.store.free)}</strong><span aria-hidden="true"> · </span><span>${escapeHtml(ctx.t.store.requirement)}</span></p>`;
}

export function practiceSheet(character, { label = null, className = '' } = {}) {
  const classes = ['practice-grid', className].filter(Boolean).join(' ');
  return `<div class="${classes}">${renderGlyph(character, { className: 'glyph-ghost' })}${renderGlyph(character, { className: 'glyph-ink', label })}</div>`;
}

export function languageLinks(ctx, { short }) {
  return ctx.locales
    .map((other) => {
      const current = other.code === ctx.locale.code ? ' aria-current="page"' : '';
      const text = short ? other.code.toUpperCase() : other.label;
      const name = short ? ` aria-label="${escapeHtml(other.label)}"` : '';
      return `<li><a href="${other.path}" hreflang="${other.hreflang}" lang="${other.htmlLang}"${name}${current}>${escapeHtml(text)}</a></li>`;
    })
    .join('');
}

export function twoDigits(index) {
  return String(index + 1).padStart(2, '0');
}
