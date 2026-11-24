export const config = {
  origin: 'https://write.thetango.org',
  appName: 'Kanji Write',
  developerName: 'Anastasiia Trofimova',
  appStoreId: '6760963794',
  playUrl: null,
  contactEmail: 'write@thetango.org',
  privacyPath: '/privacy',
  appVersion: '1.17',
  operatingSystem: 'iOS 16.0 or later, iPadOS 16.0 or later',
  price: '0',
  priceCurrency: 'USD',
  lastModified: '2026-11-24',
  defaultLocale: 'en',
  heroCharacter: '学',
  tryCharacters: ['永', '学', '日', '本', 'あ'],
  libraryCharacters: ['書', '字', '漢', '語', '水', '火', '木', '山', '川', '道', '愛', '夢', '花', '心', 'あ', 'ア'],
  locales: [
    {
      code: 'en',
      path: '/',
      htmlLang: 'en',
      hreflang: 'en',
      ogLocale: 'en_US',
      label: 'English',
      storefront: null,
      screens: 'en',
    },
    {
      code: 'ja',
      path: '/ja/',
      htmlLang: 'ja',
      hreflang: 'ja',
      ogLocale: 'ja_JP',
      label: '日本語',
      storefront: 'jp',
      screens: 'ja',
    },
    {
      code: 'ru',
      path: '/ru/',
      htmlLang: 'ru',
      hreflang: 'ru',
      ogLocale: 'ru_RU',
      label: 'Русский',
      storefront: null,
      screens: 'en',
    },
  ],
};

export function localeUrl(locale) {
  return `${config.origin}${locale.path}`;
}

export function appStoreUrl(locale) {
  const storefront = locale.storefront ? `${locale.storefront}/` : '';
  return `https://apps.apple.com/${storefront}app/id${config.appStoreId}`;
}

export function ogImagePath(locale) {
  return `/assets/og/${locale.code}.png`;
}

export function allCharacters() {
  return [...new Set([config.heroCharacter, ...config.tryCharacters, ...config.libraryCharacters])];
}
