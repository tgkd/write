import { localeUrl } from '../config.mjs';
import { escapeHtml } from './escape.mjs';

function alternateLink(hreflang, href) {
  return `    <xhtml:link rel="alternate" hreflang="${hreflang}" href="${escapeHtml(href)}"/>`;
}

function urlEntry(loc, lastModified, alternates = []) {
  return [
    '  <url>',
    `    <loc>${escapeHtml(loc)}</loc>`,
    `    <lastmod>${lastModified}</lastmod>`,
    ...alternates,
    '  </url>',
  ].join('\n');
}

export function renderSitemap(config) {
  const defaultLocale = config.locales.find((locale) => locale.code === config.defaultLocale);
  const alternates = [
    ...config.locales.map((locale) => alternateLink(locale.hreflang, localeUrl(locale))),
    alternateLink('x-default', localeUrl(defaultLocale)),
  ];
  const entries = [
    ...config.locales.map((locale) => urlEntry(localeUrl(locale), config.lastModified, alternates)),
    urlEntry(`${config.origin}${config.privacyPath}`, config.lastModified),
  ];
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">',
    ...entries,
    '</urlset>',
    '',
  ].join('\n');
}

export function renderRobots(config) {
  return `User-agent: *\nAllow: /\n\nSitemap: ${config.origin}/sitemap.xml\n`;
}
