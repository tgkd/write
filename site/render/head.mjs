import { appStoreUrl, localeUrl, ogImagePath } from '../config.mjs';
import { devices, screenPath, screens } from '../images/screens.mjs';
import { ogImageSize } from '../og/size.mjs';
import { escapeHtml, jsonForScript } from './escape.mjs';

const appLanguages = ['en', 'ja'];
const structuredScreens = ['home', 'review', 'ipad-writing-done'];

function meta(key, name, content) {
  return `<meta ${key}="${name}" content="${escapeHtml(content)}">`;
}

function link(rel, href, extra = '') {
  return `<link rel="${rel}" href="${escapeHtml(href)}"${extra}>`;
}

function defaultLocaleOf(ctx) {
  return ctx.locales.find((locale) => locale.code === ctx.config.defaultLocale);
}

function ogImageUrl(ctx) {
  return `${ctx.config.origin}${ogImagePath(ctx.locale)}`;
}

function screenshotUrls(ctx) {
  return structuredScreens.map((name) => {
    const device = devices[screens[name].device];
    const largestWidth = device.widths[device.widths.length - 1];
    return `${ctx.config.origin}${screenPath(name, ctx.locale.screens, largestWidth)}`;
  });
}

function structuredData(ctx) {
  const { config, locale, t, canonicalUrl } = ctx;
  const websiteId = `${config.origin}/#website`;
  const appId = `${config.origin}/#app`;
  const authorId = `${config.origin}/#author`;
  const storeUrl = appStoreUrl(locale);
  return {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'WebSite',
        '@id': websiteId,
        url: localeUrl(defaultLocaleOf(ctx)),
        name: config.appName,
        inLanguage: ctx.locales.map((other) => other.hreflang),
      },
      {
        '@type': 'WebPage',
        '@id': `${canonicalUrl}#webpage`,
        url: canonicalUrl,
        name: t.meta.title,
        description: t.meta.description,
        inLanguage: locale.hreflang,
        isPartOf: { '@id': websiteId },
        about: { '@id': appId },
        dateModified: config.lastModified,
        primaryImageOfPage: ogImageUrl(ctx),
      },
      {
        '@type': 'Person',
        '@id': authorId,
        name: config.developerName,
        email: config.contactEmail,
      },
      {
        '@type': 'MobileApplication',
        '@id': appId,
        name: config.appName,
        description: t.meta.description,
        url: canonicalUrl,
        applicationCategory: 'EducationalApplication',
        operatingSystem: config.operatingSystem,
        softwareVersion: config.appVersion,
        inLanguage: appLanguages,
        downloadUrl: storeUrl,
        installUrl: storeUrl,
        image: ogImageUrl(ctx),
        screenshot: screenshotUrls(ctx),
        author: { '@id': authorId },
        offers: {
          '@type': 'Offer',
          price: config.price,
          priceCurrency: config.priceCurrency,
          url: storeUrl,
        },
      },
      {
        '@type': 'FAQPage',
        '@id': `${canonicalUrl}#faq`,
        url: canonicalUrl,
        inLanguage: locale.hreflang,
        mainEntity: t.faq.items.map((item) => ({
          '@type': 'Question',
          name: item.q,
          acceptedAnswer: { '@type': 'Answer', text: item.a },
        })),
      },
    ],
  };
}

export function renderHead(ctx) {
  const { config, locale, locales, t, canonicalUrl } = ctx;
  const imageUrl = ogImageUrl(ctx);
  const alternates = [
    ...locales.map((other) => link('alternate', localeUrl(other), ` hreflang="${other.hreflang}"`)),
    link('alternate', localeUrl(defaultLocaleOf(ctx)), ' hreflang="x-default"'),
  ];
  const ogLocaleAlternates = locales
    .filter((other) => other.code !== locale.code)
    .map((other) => meta('property', 'og:locale:alternate', other.ogLocale));
  return [
    '<meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    `<title>${escapeHtml(t.meta.title)}</title>`,
    meta('name', 'description', t.meta.description),
    meta('name', 'robots', 'index, follow, max-image-preview:large'),
    meta('name', 'color-scheme', 'light dark'),
    '<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">',
    '<meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">',
    meta('name', 'apple-itunes-app', `app-id=${config.appStoreId}`),
    link('canonical', canonicalUrl),
    ...alternates,
    link('icon', '/icon.png', ' type="image/png" sizes="256x256"'),
    link('apple-touch-icon', '/apple-touch-icon.png'),
    link('stylesheet', ctx.asset('/assets/site.css')),
    meta('property', 'og:type', 'website'),
    meta('property', 'og:site_name', config.appName),
    meta('property', 'og:title', t.meta.ogTitle),
    meta('property', 'og:description', t.meta.ogDescription),
    meta('property', 'og:url', canonicalUrl),
    meta('property', 'og:locale', locale.ogLocale),
    ...ogLocaleAlternates,
    meta('property', 'og:image', imageUrl),
    meta('property', 'og:image:type', 'image/png'),
    meta('property', 'og:image:width', String(ogImageSize.width)),
    meta('property', 'og:image:height', String(ogImageSize.height)),
    meta('property', 'og:image:alt', t.meta.ogImageAlt),
    meta('name', 'twitter:card', 'summary_large_image'),
    meta('name', 'twitter:title', t.meta.ogTitle),
    meta('name', 'twitter:description', t.meta.ogDescription),
    meta('name', 'twitter:image', imageUrl),
    meta('name', 'twitter:image:alt', t.meta.ogImageAlt),
    `<script type="application/ld+json">${jsonForScript(structuredData(ctx))}</script>`,
  ].join('\n');
}
