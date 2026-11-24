import { escapeHtml } from '../render/escape.mjs';
import { renderGlyph } from '../render/glyph.mjs';
import { ogImageSize } from './size.mjs';

const styles = `
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: ${ogImageSize.width}px; height: ${ogImageSize.height}px; overflow: hidden; }
body {
  background: #ffffff;
  color: #0a0a0a;
  font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'Hiragino Sans', sans-serif;
  -webkit-font-smoothing: antialiased;
}
.card {
  display: grid;
  grid-template-columns: 1fr 470px;
  align-items: center;
  gap: 40px;
  width: 100%;
  height: 100%;
  padding: 72px 80px;
}
.copy { display: flex; flex-direction: column; gap: 28px; min-width: 0; }
.brand { display: flex; align-items: center; gap: 16px; font-size: 30px; font-weight: 700; letter-spacing: -0.01em; }
.brand img { width: 56px; height: 56px; border-radius: 13px; border: 1px solid #e2e2e2; }
.headline { font-size: 76px; font-weight: 800; line-height: 1.04; letter-spacing: -0.035em; }
:lang(ja) .headline { letter-spacing: 0; line-height: 1.2; }
.facts { display: flex; flex-wrap: wrap; gap: 12px; }
.facts li { list-style: none; padding: 10px 22px; border: 2px solid #e2e2e2; border-radius: 999px; font-size: 24px; font-weight: 600; }
.glyph { display: block; width: 470px; height: 470px; overflow: visible; }
.glyph-stroke { fill: none; stroke: #0a0a0a; stroke-width: 7; stroke-linecap: round; stroke-linejoin: round; }
`;

const fitScript = `
const headline = document.querySelector('.headline');
const copy = document.querySelector('.copy');
let size = parseFloat(getComputedStyle(headline).fontSize);
while (copy.scrollHeight > ${ogImageSize.height - 144} && size > 40) {
  size -= 2;
  headline.style.fontSize = size + 'px';
}
`;

export function renderOgDocument({ lang, appName, headline, facts, character, iconUrl }) {
  const factItems = facts.map((fact) => `<li>${escapeHtml(fact)}</li>`).join('');
  return `<!DOCTYPE html>
<html lang="${escapeHtml(lang)}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=${ogImageSize.width}, height=${ogImageSize.height}">
<title>${escapeHtml(appName)}</title>
<style>${styles}</style>
</head>
<body>
<main class="card">
<div class="copy">
<p class="brand"><img src="${escapeHtml(iconUrl)}" alt="" width="56" height="56">${escapeHtml(appName)}</p>
<h1 class="headline">${escapeHtml(headline)}</h1>
<ul class="facts">${factItems}</ul>
</div>
${renderGlyph(character)}
</main>
<script>${fitScript}</script>
</body>
</html>
`;
}
