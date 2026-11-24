import { escapeHtml } from './escape.mjs';

export function renderHead(ctx) {
  return [
    '<meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    `<title>${escapeHtml(ctx.t.meta.title)}</title>`,
    `<link rel="stylesheet" href="${ctx.asset('/assets/site.css')}">`,
  ].join('\n');
}
