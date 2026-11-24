import { escapeHtml } from '../escape.mjs';
import { closeSection, openSection, practiceSheet, sectionHeader, twoDigits } from './parts.mjs';

const checkKinds = ['shape', 'position', 'direction', 'order'];
const appInterfaceLanguages = ['en', 'ja'];

function messageLang(ctx) {
  return appInterfaceLanguages.includes(ctx.locale.code) ? ctx.locale.code : 'en';
}

export function renderChecks(ctx) {
  const { t, config } = ctx;
  const characters = config.tryCharacters.filter((character) => character !== config.heroCharacter);
  const items = t.checks.items
    .map(
      (item, index) =>
        `<li class="check-card check-${checkKinds[index]}" data-animate style="--n:${index}"><div class="check-visual" data-replay>${practiceSheet(characters[index % characters.length], { className: 'practice-grid-small' })}</div><p class="check-index" aria-hidden="true">${twoDigits(index)}</p><h3 class="item-title">${escapeHtml(item.title)}</h3><p class="item-body">${escapeHtml(item.body)}</p></li>`,
    )
    .join('');
  const messages = t.checks.messages
    .map((message, index) => `<li class="feedback-pill" style="--n:${index}">${escapeHtml(message)}</li>`)
    .join('');
  return [
    openSection('checks'),
    sectionHeader({ id: 'checks', eyebrow: t.checks.eyebrow, title: t.checks.title, lede: t.checks.lede }),
    `<ol class="check-list">${items}</ol>`,
    '<div class="feedback" data-animate>',
    `<div class="feedback-copy"><h3 class="feedback-title">${escapeHtml(t.checks.feedbackTitle)}</h3><p class="lede">${escapeHtml(t.checks.feedbackBody)}</p></div>`,
    `<ul class="feedback-pills" lang="${messageLang(ctx)}">${messages}</ul>`,
    '</div>',
    closeSection,
  ].join('');
}
