const replacements = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
};

export function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => replacements[character]);
}

export function fillPlaceholders(template, values) {
  return template.replace(/\{(\w+)\}/g, (match, key) => (key in values ? String(values[key]) : match));
}

export function jsonForScript(value) {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}
