import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config, localeUrl } from './config.mjs';
import { renderBody } from './render/body.mjs';
import { renderHead } from './render/head.mjs';
import { renderNotFound } from './render/not-found.mjs';
import { renderRobots, renderSitemap } from './render/sitemap.mjs';

const siteDir = dirname(fileURLToPath(import.meta.url));
const pagesDir = join(siteDir, '..', 'pages');
const styleOrder = ['tokens.css', 'page.css', 'try.css'];

function writeOutput(relativePath, content) {
  const outputPath = join(pagesDir, relativePath);
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, content);
  console.log(`Wrote pages/${relativePath}`);
}

function asset(path) {
  const hash = createHash('sha256').update(readFileSync(join(pagesDir, path))).digest('hex').slice(0, 10);
  return `${path}?v=${hash}`;
}

function loadLocale(code) {
  return JSON.parse(readFileSync(join(siteDir, 'locales', `${code}.json`), 'utf8'));
}

function renderDocument(htmlLang, head, body) {
  return `<!DOCTYPE html>\n<html lang="${htmlLang}">\n<head>\n${head}\n</head>\n<body>\n${body}\n</body>\n</html>\n`;
}

function contextFor(locale) {
  return {
    config,
    locale,
    locales: config.locales,
    t: loadLocale(locale.code),
    canonicalUrl: localeUrl(locale),
    asset,
  };
}

const css = styleOrder.map((name) => readFileSync(join(siteDir, 'styles', name), 'utf8')).join('\n');
writeOutput('assets/site.css', css);

for (const locale of config.locales) {
  const ctx = contextFor(locale);
  const outputPath = locale.path === '/' ? 'index.html' : `${locale.path.slice(1)}index.html`;
  writeOutput(outputPath, renderDocument(locale.htmlLang, renderHead(ctx), renderBody(ctx)));
}

const defaultLocale = config.locales.find((locale) => locale.code === config.defaultLocale);
const notFound = renderNotFound(contextFor(defaultLocale));
writeOutput('404.html', renderDocument(defaultLocale.htmlLang, notFound.head, notFound.body));

writeOutput('sitemap.xml', renderSitemap(config));
writeOutput('robots.txt', renderRobots(config));
