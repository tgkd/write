import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { devices, screenLocales, screenPath, screens } from './screens.mjs';

const imagesDir = dirname(fileURLToPath(import.meta.url));
const repoDir = join(imagesDir, '..', '..');
const sourceDir = join(repoDir, 'appstore-screenshots');
const pagesDir = join(repoDir, 'pages');

let written = 0;

for (const [name, entry] of Object.entries(screens)) {
  for (const screensLocale of screenLocales) {
    const sourcePath = join(sourceDir, entry[screensLocale]);
    if (!existsSync(sourcePath)) {
      throw new Error(`Missing source screenshot ${sourcePath}`);
    }
    for (const width of devices[entry.device].widths) {
      const outputPath = join(pagesDir, screenPath(name, screensLocale, width));
      mkdirSync(dirname(outputPath), { recursive: true });
      execFileSync('cwebp', ['-quiet', '-q', '82', '-resize', String(width), '0', sourcePath, '-o', outputPath]);
      written += 1;
    }
  }
}

console.log(`Wrote ${written} images to ${join(pagesDir, 'assets', 'screens')}`);
