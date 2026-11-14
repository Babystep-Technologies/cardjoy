/**
 * The "Add to CardJoy registry" bookmarklet (#298). It runs on the product page the user is
 * already looking at, in their own browser, so it isn't blocked the way a server-side fetch is: it
 * reads the title, image and price the page itself declares (OpenGraph, then schema.org JSON-LD),
 * and opens our add-item page with them prefilled. Nothing is sent anywhere until the user confirms
 * there, and the bookmarklet only ever opens a page on this app's own origin.
 */
const SCRIPT = `
(function () {
  function meta(name) {
    var el = document.querySelector('meta[property="' + name + '"],meta[name="' + name + '"]');
    return (el && el.content) || '';
  }
  var title = meta('og:title');
  var image = meta('og:image');
  var price = meta('product:price:amount') || meta('og:price:amount');
  var scripts = document.querySelectorAll('script[type="application/ld+json"]');
  for (var i = 0; i < scripts.length; i++) {
    try {
      var data = JSON.parse(scripts[i].textContent);
      var nodes = Array.isArray(data) ? data : data['@graph'] || [data];
      for (var j = 0; j < nodes.length; j++) {
        var node = nodes[j];
        if ([].concat(node['@type'] || []).indexOf('Product') < 0) continue;
        title = title || node.name || '';
        var img = [].concat(node.image || [])[0];
        image = image || (img && img.url) || (typeof img === 'string' ? img : '');
        var offer = [].concat(node.offers || [])[0];
        if (offer && !price) {
          price = offer.price || offer.lowPrice || '';
          if (price && offer.priceCurrency === 'USD') price = '$' + price;
        }
      }
    } catch (e) {}
  }
  var query = new URLSearchParams({
    url: location.href,
    title: title || document.title,
    image: image || '',
    price: String(price || '')
  });
  window.open('__ORIGIN__/registry/add?' + query, '_blank');
})();
`;

/** The `javascript:` URL to bookmark, pointing back at the given app origin. */
export const buildBookmarklet = (origin: string): string =>
  'javascript:' +
  SCRIPT.replace('__ORIGIN__', origin)
    .replace(/\s+/g, ' ')
    .replace(/ ?([{}();,=<>+|&:?]) ?/g, '$1')
    .trim();

/** The product fields the bookmarklet passes along, from the add-item page's query string. */
export interface CapturedItem {
  url: string;
  title: string;
  imageUrl: string;
  price: string;
}

const httpUrl = (value: string | null): string => {
  if (!value) return '';
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:' ? parsed.toString() : '';
  } catch {
    return '';
  }
};

/**
 * Reads and sanitizes the query string: links must be http(s), text is capped. It serves both the
 * bookmarklet (`url`, `title`, `image`, `price`) and an Android share (`title`, `text`, `url`), where
 * the link is often inside `text` ("Cast iron pan https://…") and `url` is empty.
 */
export const parseCapturedItem = (params: URLSearchParams): CapturedItem | null => {
  const text = params.get('text') ?? '';
  const linkInText = text.match(/https?:\/\/\S+/i)?.[0] ?? null;
  const url = httpUrl(params.get('url')) || httpUrl(linkInText);
  if (!url) return null;

  const sharedTitle = params.get('title') ?? '';
  const textWithoutLink = linkInText ? text.replace(linkInText, '') : text;
  return {
    url,
    title: (sharedTitle || textWithoutLink).trim().slice(0, 200),
    imageUrl: httpUrl(params.get('image')),
    price: (params.get('price') ?? '').trim().slice(0, 40),
  };
};
