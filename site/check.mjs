import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config, localeUrl, ogImagePath } from './config.mjs';

const siteDir = dirname(fileURLToPath(import.meta.url));
const pagesDir = join(siteDir, '..', 'pages');
const errors = [];

function fail(scope, message) {
  errors.push(`${scope}: ${message}`);
}

function loadLocale(code) {
  return JSON.parse(readFileSync(join(siteDir, 'locales', `${code}.json`), 'utf8'));
}

function compareShape(scope, reference, candidate, path) {
  if (Array.isArray(reference)) {
    if (!Array.isArray(candidate) || candidate.length !== reference.length) {
      fail(scope, `${path} must be an array of ${reference.length} items`);
      return;
    }
    reference.forEach((item, index) => compareShape(scope, item, candidate[index], `${path}[${index}]`));
    return;
  }
  if (reference !== null && typeof reference === 'object') {
    if (candidate === null || typeof candidate !== 'object' || Array.isArray(candidate)) {
      fail(scope, `${path} must be an object`);
      return;
    }
    for (const key of Object.keys(reference)) {
      compareShape(scope, reference[key], candidate[key], path ? `${path}.${key}` : key);
    }
    for (const key of Object.keys(candidate)) {
      if (!(key in reference)) {
        fail(scope, `${path ? `${path}.` : ''}${key} is not in the en locale`);
      }
    }
    return;
  }
  if (typeof candidate !== 'string' || candidate.trim() === '') {
    fail(scope, `${path} must be a non-empty string`);
    return;
  }
  const referencePlaceholders = (reference.match(/\{\w+\}/g) ?? []).sort().join();
  const candidatePlaceholders = (candidate.match(/\{\w+\}/g) ?? []).sort().join();
  if (referencePlaceholders !== candidatePlaceholders) {
    fail(scope, `${path} must keep the placeholders ${referencePlaceholders || 'none'}`);
  }
}

function resolveLocalPath(reference) {
  const clean = reference.split('#')[0].split('?')[0];
  if (clean === '') {
    return null;
  }
  const direct = join(pagesDir, clean);
  if (clean.endsWith('/')) {
    return join(direct, 'index.html');
  }
  if (existsSync(direct) && statSync(direct).isFile()) {
    return direct;
  }
  return `${direct}.html`;
}

function localReferences(html) {
  const references = [];
  for (const match of html.matchAll(/\s(?:href|src|poster)="(\/[^"]*)"/g)) {
    references.push(match[1]);
  }
  for (const match of html.matchAll(/\ssrcset="([^"]*)"/g)) {
    for (const candidate of match[1].split(',')) {
      const url = candidate.trim().split(/\s+/)[0];
      if (url.startsWith('/')) {
        references.push(url);
      }
    }
  }
  return references;
}

function attribute(tag, name) {
  const match = tag.match(new RegExp(`\\s${name}="([^"]*)"`));
  return match ? match[1] : null;
}

function checkPage(locale) {
  const relativePath = locale.path === '/' ? 'index.html' : `${locale.path.slice(1)}index.html`;
  const scope = `pages/${relativePath}`;
  const fullPath = join(pagesDir, relativePath);
  if (!existsSync(fullPath)) {
    fail(scope, 'file is missing; run node site/build.mjs');
    return;
  }
  const html = readFileSync(fullPath, 'utf8');
  const t = loadLocale(locale.code);

  if (!html.includes(`<html lang="${locale.htmlLang}"`)) {
    fail(scope, `html lang must be ${locale.htmlLang}`);
  }
  if (html.includes('<!--')) {
    fail(scope, 'HTML comments are not allowed');
  }
  if ((html.match(/<h1[\s>]/g) ?? []).length !== 1) {
    fail(scope, 'the page must have exactly one h1');
  }
  if (!/<title>[^<]+<\/title>/.test(html)) {
    fail(scope, 'title is missing');
  }

  const metaTags = html.match(/<meta\s[^>]*>/g) ?? [];
  const linkTags = html.match(/<link\s[^>]*>/g) ?? [];
  const metaContent = (key, value) => {
    const tag = metaTags.find((candidate) => attribute(candidate, key) === value);
    return tag ? attribute(tag, 'content') : null;
  };

  if (!metaContent('name', 'description')) {
    fail(scope, 'meta description is missing');
  }
  if (metaContent('name', 'apple-itunes-app') !== `app-id=${config.appStoreId}`) {
    fail(scope, 'apple-itunes-app smart banner meta is missing or wrong');
  }
  for (const property of ['og:title', 'og:description', 'og:type', 'og:site_name', 'og:image:alt']) {
    if (!metaContent('property', property)) {
      fail(scope, `${property} is missing`);
    }
  }
  if (metaContent('property', 'og:url') !== localeUrl(locale)) {
    fail(scope, `og:url must be ${localeUrl(locale)}`);
  }
  if (metaContent('property', 'og:locale') !== locale.ogLocale) {
    fail(scope, `og:locale must be ${locale.ogLocale}`);
  }
  if (metaContent('property', 'og:image') !== `${config.origin}${ogImagePath(locale)}`) {
    fail(scope, `og:image must be ${config.origin}${ogImagePath(locale)}`);
  }
  if (metaContent('name', 'twitter:card') !== 'summary_large_image') {
    fail(scope, 'twitter:card must be summary_large_image');
  }
  if (!existsSync(join(pagesDir, ogImagePath(locale)))) {
    fail(scope, `Open Graph image pages${ogImagePath(locale)} is missing`);
  }

  const canonical = linkTags.find((tag) => attribute(tag, 'rel') === 'canonical');
  if (!canonical || attribute(canonical, 'href') !== localeUrl(locale)) {
    fail(scope, `canonical must be ${localeUrl(locale)}`);
  }
  const alternates = linkTags.filter((tag) => attribute(tag, 'rel') === 'alternate' && attribute(tag, 'hreflang'));
  const expectedAlternates = [
    ...config.locales.map((other) => [other.hreflang, localeUrl(other)]),
    ['x-default', localeUrl(config.locales.find((other) => other.code === config.defaultLocale))],
  ];
  for (const [hreflang, href] of expectedAlternates) {
    const found = alternates.find((tag) => attribute(tag, 'hreflang') === hreflang);
    if (!found || attribute(found, 'href') !== href) {
      fail(scope, `hreflang ${hreflang} must point to ${href}`);
    }
  }
  if (alternates.length !== expectedAlternates.length) {
    fail(scope, `expected ${expectedAlternates.length} hreflang alternates, found ${alternates.length}`);
  }

  const structuredTypes = new Set();
  for (const match of html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)) {
    try {
      const parsed = JSON.parse(match[1]);
      const nodes = Array.isArray(parsed) ? parsed : parsed['@graph'] ?? [parsed];
      for (const node of nodes) {
        for (const type of [].concat(node['@type'] ?? [])) {
          structuredTypes.add(type);
        }
        if (node['@type'] === 'FAQPage' && node.mainEntity?.length !== t.faq.items.length) {
          fail(scope, 'FAQPage must hold every FAQ item of the locale');
        }
      }
    } catch (error) {
      fail(scope, `JSON-LD does not parse: ${error.message}`);
    }
  }
  if (!structuredTypes.has('FAQPage')) {
    fail(scope, 'JSON-LD FAQPage is missing');
  }
  if (!structuredTypes.has('MobileApplication') && !structuredTypes.has('SoftwareApplication')) {
    fail(scope, 'JSON-LD MobileApplication or SoftwareApplication is missing');
  }

  for (const tag of html.match(/<img\s[^>]*>/g) ?? []) {
    for (const name of ['alt', 'width', 'height']) {
      if (attribute(tag, name) === null) {
        fail(scope, `img without ${name}: ${tag.slice(0, 120)}`);
      }
    }
  }

  for (const reference of localReferences(html)) {
    const resolved = resolveLocalPath(reference);
    if (resolved && !existsSync(resolved)) {
      fail(scope, `local reference ${reference} does not exist in pages/`);
    }
  }

  for (const other of config.locales) {
    if (!html.includes(`href="${other.path}"`)) {
      fail(scope, `no crawlable link to the ${other.code} page (${other.path})`);
    }
  }
  if (!html.includes(`id${config.appStoreId}`)) {
    fail(scope, 'App Store link is missing');
  }
  if (!html.includes(`href="${config.privacyPath}"`)) {
    fail(scope, 'link to the privacy policy is missing');
  }
  if (!html.includes(config.contactEmail)) {
    fail(scope, 'contact address is missing');
  }
  if (config.playUrl === null && html.includes('play.google.com')) {
    fail(scope, 'Google Play link must not show while playUrl is null');
  }
}

const reference = loadLocale(config.defaultLocale);
for (const locale of config.locales) {
  if (locale.code !== config.defaultLocale) {
    compareShape(`site/locales/${locale.code}.json`, reference, loadLocale(locale.code), '');
  }
  checkPage(locale);
}

for (const relativePath of ['404.html', 'sitemap.xml', 'robots.txt', '_headers', 'privacy.html', 'assets/site.css']) {
  if (!existsSync(join(pagesDir, relativePath))) {
    fail(`pages/${relativePath}`, 'file is missing');
  }
}

if (existsSync(join(pagesDir, 'sitemap.xml'))) {
  const sitemap = readFileSync(join(pagesDir, 'sitemap.xml'), 'utf8');
  for (const locale of config.locales) {
    if (!sitemap.includes(`<loc>${localeUrl(locale)}</loc>`)) {
      fail('pages/sitemap.xml', `${localeUrl(locale)} is missing`);
    }
  }
  if (!sitemap.includes('xhtml:link')) {
    fail('pages/sitemap.xml', 'hreflang alternates (xhtml:link) are missing');
  }
}

if (existsSync(join(pagesDir, 'robots.txt'))) {
  const robots = readFileSync(join(pagesDir, 'robots.txt'), 'utf8');
  if (!robots.includes(`Sitemap: ${config.origin}/sitemap.xml`)) {
    fail('pages/robots.txt', 'Sitemap line is missing');
  }
}

if (existsSync(join(pagesDir, 'assets', 'site.css'))) {
  const css = readFileSync(join(pagesDir, 'assets', 'site.css'), 'utf8');
  if (/gradient\(/.test(css)) {
    fail('pages/assets/site.css', 'gradients are not allowed');
  }
  if (css.includes('/*')) {
    fail('pages/assets/site.css', 'comments are not allowed');
  }
  if (!css.includes('prefers-reduced-motion')) {
    fail('pages/assets/site.css', 'a prefers-reduced-motion rule is missing');
  }
}

if (errors.length > 0) {
  console.error(`${errors.length} problems:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log('Site check passed');
