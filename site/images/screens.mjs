export const devices = {
  phone: { sourceWidth: 1320, sourceHeight: 2868, widths: [440, 880] },
  ipad: { sourceWidth: 2752, sourceHeight: 2064, widths: [900, 1800] },
};

export const screens = {
  home: {
    device: 'phone',
    en: 'captures-2026-11-v117/iphone-6.9/home.png',
    ja: 'captures-2026-11-v117/ja-iphone-6.9/home.png',
  },
  review: {
    device: 'phone',
    en: 'captures-2026-11-v117/iphone-6.9/review-mid.png',
    ja: 'captures-2026-11-v117/ja-iphone-6.9/review-mid.png',
  },
  progress: {
    device: 'phone',
    en: 'captures-2026-11-v117/iphone-6.9/progress.png',
    ja: 'captures-2026-11-v117/ja-iphone-6.9/progress.png',
  },
  trace: {
    device: 'phone',
    en: 'captures-2026-11/iphone-6.9/02-trace-partial.png',
    ja: 'captures-2026-11/ja-iphone-6.9/02-trace-partial.png',
  },
  guided: {
    device: 'phone',
    en: 'captures-2026-11/iphone-6.9/03-guided-indigo.png',
    ja: 'captures-2026-11/ja-iphone-6.9/06-guided-indigo.png',
  },
  copy: {
    device: 'phone',
    en: 'captures-2026-11/iphone-6.9/04-copy-complete.png',
    ja: 'captures-2026-11/ja-iphone-6.9/05-copy-complete.png',
  },
  order: {
    device: 'phone',
    en: 'captures-2026-11/iphone-6.9/07-wrong-order.png',
    ja: 'captures-2026-11/ja-iphone-6.9/04-wrong-order.png',
  },
  settings: {
    device: 'phone',
    en: 'captures-2026-11/iphone-6.9/09-settings-ink.png',
    ja: 'captures-2026-11/ja-iphone-6.9/08-settings.png',
  },
  'ipad-home': {
    device: 'ipad',
    en: 'captures-2026-11-v117/ipad-13/home-sidebar.png',
    ja: 'captures-2026-11-v117/ja-ipad-13/home-sidebar.png',
  },
  'ipad-levels': {
    device: 'ipad',
    en: 'captures-2026-11-v117/ipad-13/levels.png',
    ja: 'captures-2026-11-v117/ja-ipad-13/levels.png',
  },
  'ipad-review': {
    device: 'ipad',
    en: 'captures-2026-11-v117/ipad-13/review-mid.png',
    ja: 'captures-2026-11-v117/ja-ipad-13/review-mid.png',
  },
  'ipad-progress': {
    device: 'ipad',
    en: 'captures-2026-11-v117/ipad-13/progress.png',
    ja: 'captures-2026-11-v117/ja-ipad-13/progress.png',
  },
  'ipad-trace': {
    device: 'ipad',
    en: 'captures-2026-11/ipad-13/01-trace-partial.png',
    ja: 'captures-2026-11/ja-ipad-13/02-trace-partial.png',
  },
  'ipad-writing': {
    device: 'ipad',
    en: 'captures-2026-11/ipad-13/03-writing-mid.png',
    ja: 'captures-2026-11/ja-ipad-13/03b-writing-mid.png',
  },
  'ipad-writing-done': {
    device: 'ipad',
    en: 'captures-2026-11/ipad-13/04-writing-done.png',
    ja: 'captures-2026-11/ja-ipad-13/03-writing-done.png',
  },
  'ipad-notebook': {
    device: 'ipad',
    en: 'captures-2026-11/ipad-13/06-notebook.png',
    ja: 'captures-2026-11/ja-ipad-13/05-notebook.png',
  },
};

export const screenLocales = ['en', 'ja'];

export function screenPath(name, screensLocale, width) {
  return `/assets/screens/${screensLocale}/${name}-${width}.webp`;
}

export function screen(name, screensLocale) {
  const entry = screens[name];
  if (!entry) {
    throw new Error(`Unknown screen ${name}`);
  }
  const device = devices[entry.device];
  const [smallWidth] = device.widths;
  return {
    device: entry.device,
    src: screenPath(name, screensLocale, smallWidth),
    srcset: device.widths.map((width) => `${screenPath(name, screensLocale, width)} ${width}w`).join(', '),
    width: smallWidth,
    height: Math.round((smallWidth * device.sourceHeight) / device.sourceWidth),
  };
}
