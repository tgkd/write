import { escapeHtml } from './escape.mjs';

export function renderNotFound(ctx) {
  return {
    head: [
      '<meta charset="UTF-8">',
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
      '<meta name="robots" content="noindex">',
      `<title>${escapeHtml(ctx.t.notFound.title)}</title>`,
      `<link rel="stylesheet" href="${ctx.asset('/assets/site.css')}">`,
    ].join('\n'),
    body: `<main id="main"><h1>${escapeHtml(ctx.t.notFound.title)}</h1><p>${escapeHtml(ctx.t.notFound.body)}</p><p><a href="/">${escapeHtml(ctx.t.notFound.home)}</a></p></main>`,
  };
}
