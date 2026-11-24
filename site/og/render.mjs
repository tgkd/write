import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { config, ogImagePath } from '../config.mjs';
import { ogImageSize } from './size.mjs';
import { renderOgDocument } from './template.mjs';

const ogDir = dirname(fileURLToPath(import.meta.url));
const siteDir = join(ogDir, '..');
const pagesDir = join(siteDir, '..', 'pages');
const outputDir = process.argv[2] ? resolve(process.argv[2]) : mkdtempSync(join(tmpdir(), 'write-og-'));
const iconUrl = pathToFileURL(join(pagesDir, 'icon.png')).href;

mkdirSync(outputDir, { recursive: true });
mkdirSync(join(pagesDir, dirname(ogImagePath(config.locales[0]))), { recursive: true });

console.log(`Capture each page at ${ogImageSize.width}x${ogImageSize.height} into the PNG next to it:`);
for (const locale of config.locales) {
  const t = JSON.parse(readFileSync(join(siteDir, 'locales', `${locale.code}.json`), 'utf8'));
  const html = renderOgDocument({
    lang: locale.htmlLang,
    appName: config.appName,
    headline: t.hero.title,
    facts: t.hero.facts,
    character: config.heroCharacter,
    iconUrl,
  });
  const htmlPath = join(outputDir, `${locale.code}.html`);
  writeFileSync(htmlPath, html);
  console.log(`${pathToFileURL(htmlPath).href} -> ${join(pagesDir, ogImagePath(locale))}`);
}
