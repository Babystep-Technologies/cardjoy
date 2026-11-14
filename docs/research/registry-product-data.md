# Registry: product data, capture tools & affiliate (#257)

Research for #257, done 2026-11-13. It answers: how does Registry get accurate title, image and price
from arbitrary store URLs, should affiliate links fund it, and which capture tools and retailer
integrations are worth building, in what order.

**How much to trust this.** The probe in section 1 is first-hand. Everything else came from web
search, mostly secondary sources (vendor blogs, compliance trackers), and is marked **[unverified]**
where the primary document (Amazon's license text, the FTC FAQ, a pricing page) was not read. Check
those before committing money or legal exposure to them.

## Recommendation in one page

1. **Server-side fetching is a best-effort convenience, not the foundation.** In our probe most big
   retailers blocked or walled us. Keep manual entry first-class and never let enrichment block adding
   an item (already true).
2. **Capture in the user's own browser is what fixes the blocking.** A bookmarklet, share target or
   extension runs on a page the user's browser already loaded: no bot wall, JS already rendered, their
   region's price. Build these before paying for scraping.
3. **Affiliate: no-go for now.** Prerequisites are listed in section 3. The trust cost in a gift
   product and the compliance work outweigh revenue at our current scale.
4. **Order of work:** (a) bot-wall title fix (shipped, #295), (b) known-blocker handling, (c) bookmarklet,
   (d) paste several links at once, (e) Android share target, (f) browser extension, (g) paid
   extraction as a fallback only if volume justifies, (h) retailer APIs only alongside affiliate.

## 1. What we can extract from a URL: first-hand probe

We ran `WishListLinkPreview` (OpenGraph + schema.org JSON-LD, honest user agent) against 12 real
product URLs from a development machine, then re-checked HTTP status with `curl` using both our user
agent and a desktop Chrome one. Small sample, one residential IP, URLs picked by hand; read it as
direction, not a benchmark.

| Store | Our fetcher | Notes |
|---|---|---|
| Amazon | **wrong**: title "Amazon.com" | bot wall served as `200` |
| Walmart | **wrong**: title "Robot or human?" | bot wall served as `200` |
| Etsy | nothing | `403` for both user agents |
| eBay | nothing | `403` for both user agents |
| Crate & Barrel | nothing | `403` for both user agents |
| REI | nothing | `403` / connection failure |
| Best Buy | nothing | timeout (12 s) |
| Allbirds | nothing | `200` to our UA, `429` to a browser UA (rate limiting) |
| Lovevery | title only | `200`, but no JSON-LD in the served HTML |
| IKEA | title + image | no price |
| Nike | title + image | no price |
| Target | nothing | `404`: my URL was probably invalid, ignore |

What this says:

- **Blocking is by IP/fingerprint, not user agent.** Faking a browser user agent did not help, and a
  cloud server IP will do worse than a laptop. Spoofing is also against the grain of an honest
  fetcher. Don't chase it.
- **Price is rarely in the served HTML**, even where title and image are. It is usually rendered
  client-side or fetched separately. Price from a server fetch should be treated as a bonus.
- **A blocked fetch can look like success.** Two stores returned a `200` wall page, and we accepted its
  title as the item's name. Fixed in #295 (exact-match list of wall titles).
- Fast failure is good: most nils came back in under a second.

Background (secondary, **[unverified]**): schema.org `Product` markup is common but far from universal
on product pages, and adoption figures vary widely by source, so don't plan around coverage numbers.

### Metadata strategy options

| Option | Fixes blocking? | Cost | Verdict |
|---|---|---|---|
| Own fetcher (today) | No | Free | Keep as the default path; harden |
| Paid extraction API (Zyte, Diffbot) | Yes, their business | Reported ~$0.13-1.27 per 1k plain requests and ~$1-16 per 1k browser-rendered, monthly commitments from ~$100 (Zyte, pagecrawl.io 2026 summary); Diffbot credit-based, ~$299/mo plans quoted **[unverified]** | Later, as a fallback for refresh only, and only if volume justifies |
| Capture in the user's browser | Yes, by construction | Engineering only | **Build first** (section 4) |
| Retailer APIs | Yes, per retailer | Eligibility rules | Only with affiliate (section 3) |

Microlink and similar link-preview APIs were not researched; they mostly return OpenGraph, so they
would hit the same walls.

### Price and availability refresh

The daily bounded job (#292) plus the "price may have changed" marker (#284) is the right shape. It
degrades honestly: where a store blocks us, the price is never refreshed and the marker appears after
30 days. Two follow-ups:

- **Known blockers.** Keep a short list of hosts that reliably block (from the probe: amazon, walmart,
  etsy, ebay, crateandbarrel, rei, bestbuy). For them, skip the fetch at paste time and say plainly
  "this store blocks previews; add the details yourself or use the capture button", and skip them in
  the refresh job so we stop wasting requests. Needs a place for the list that is easy to edit.
- Availability ("out of stock") needs the same page data as price, so it has the same limits.

## 2. Retailer-specific APIs

- **Amazon.** PA-API 5 is being retired and replaced by the Creators API (OAuth 2.0; keys don't carry
  over). Sources disagree on the date (April 30 vs May 15, 2026): check Associates Central. Access
  needs an approved Associates account and, per several sources, at least 10 qualifying sales in the
  past 30 days, with access paused below that **[unverified: one vendor page mentions a different
  rule]**. That is a chicken-and-egg problem for a new product: no API data until there are
  affiliate sales, and no affiliate sales without traffic. There is no public API for Amazon wish
  lists. Amazon's terms bar automated collection, and its bot defences are heavy.
- **Walmart, Target, Etsy, eBay.** They run through affiliate networks (reports conflict on which:
  Impact, CJ, Awin, or eBay's own partner program) and each has its own API/data feed terms. Not
  researched beyond commission figures (section 3). eBay and Etsy both returned `403` to plain page
  fetches, so an API would be the only route for them.
- **Recommendation:** no retailer API until affiliate is a go. If we ever do one, Amazon first (it is
  where registries point), but only once the sales threshold is realistic.

## 3. Affiliate monetization

### Go/no-go: **no-go for now**

**Prerequisites before reconsidering**

1. Legal review of disclosure and of each program's terms for our use (below).
2. Per-link disclosure in the guest UI, at the link (not a footer or policy page).
3. A decision on neutrality: owners opt out, and guests are told whose link they are using.
4. An aggregator or program that explicitly accepts user-submitted links on a third-party site.
5. A volume trigger worth the work, for example sustained monthly claims, so there is revenue to
   weigh against the trust cost. (We chose not to build view/click analytics; affiliate networks
   report clicks themselves, so this does not need our own tracking.)

**Why not now**

- **Disclosure (FTC).** The 2023 Endorsement Guides treat affiliate links as a material connection that
  needs a clear and conspicuous disclosure at the point of the recommendation. Per the FTC's FAQ as
  summarized by law firms: "affiliate link" alone or a "buy" button is not enough, "paid link" beside the
  link is acceptable, "commissionable link" is not, and footers or separate pages generally fail
  **[unverified: read 16 CFR Part 255 and the FTC FAQ]**. For us that means a visible label on every
  rewritten link on the guest page.
- **Amazon's rules fit us badly** **[unverified: secondary sources; read the Operating Agreement]**:
  affiliate links in email are restricted, and our claim confirmation and reminder emails are exactly
  that; prices must come from Amazon's API with a date/time stamp beside them; images cannot be cached
  beyond a short window; a newer rule (effective April 14, 2026) requires purchase within 180 days to
  qualify.
- **Short cookie windows and low rates for a gift product** (blog figures, **[unverified]**): Target up
  to ~8% with ~7 days; Walmart ~1-4% with ~3 days; Etsy ~4% with ~30 days; eBay ~1-4% with ~24 hours.
  A guest often claims now and buys days later, so short cookies lose much of the credit.
- **Aggregators** (Skimlinks, Sovrn Commerce) rewrite links automatically for a revenue share
  (commonly reported as roughly 25%, **[unverified]**). Both approve publishers; Sovrn reviews each
  location separately. Neither source said whether links submitted by our users (user-generated
  content) are allowed. That is the question to ask them first.
- **Neutrality.** Owners often pick a specific store or a cheaper seller. Rewriting links, or nudging
  toward partner stores, cuts against "buy it anywhere".

**Does link rewriting break "buy it anywhere"?** Not if it is rewrite-in-place (same store, same
product, only a tag added) and opt-out. The risk is perception, not function.

## 4. Capture tools: what to build, in order

Babylist's "Add to Babylist" extension (Chrome, with roughly 300k users per its store listing) shows
the demand and the shape: one click on any product page adds it. Whether it earns affiliate revenue
was not found.

| Tool | Reaches | Effort | Notes |
|---|---|---|---|
| **Bookmarklet** | Any desktop browser, iOS Safari | Low | Runs in the page, reads title/image/price from the DOM and OpenGraph/JSON-LD, then opens our "add item" page with the fields prefilled in the query string. No CORS or cookie issues, no store review. Needs the user to sign in on our page. Weak UX to install. |
| **Paste several links** | Everyone | Low | Not capture, but covers the "I have 15 tabs open" case with no new platform. |
| **Android share target** | Android Chrome, installed PWA | Low-medium | Add `share_target` to the PWA manifest (the web app already uses `vite-plugin-pwa`). The app must be installed, and Android often puts the URL in the `text` field. **iOS Safari does not support it** (WebKit bug 194593, open since 2019). |
| **Browser extension** | Chrome/Edge/Firefox desktop | Medium | Best UX. Chrome Web Store review: single narrow purpose, minimum permissions; broad host permissions can slow review. Safari needs a separate wrapper app and an Apple developer account (**not researched**). |
| **Mobile share sheet on iOS** | iOS | High | No web route. Would need a native share extension; out of scope. |

On iOS the realistic options are the bookmarklet, pasting a link, or a future Safari extension.

## 5. Retailer registry imports

- **Amazon wish list:** no API, scraping barred by terms and bot defences. **No-go.**
- **Target, Babylist, others:** not researched; no public import APIs were found in passing. Treat as
  unavailable until someone checks.
- The practical substitute is capture-from-the-product-page plus paste-several-links.

## 6. Proposed follow-up issues

1. Known-blocker hosts: skip fetch at paste time, clear message, skip in refresh job (small).
2. Bookmarklet capture with a prefilled add-item page (small-medium).
3. Paste several links at once (small).
4. Android `share_target` in the PWA manifest (small).
5. Chrome/Edge extension (medium; revisit after the bookmarklet shows use).
6. Revisit affiliate when the section 3 prerequisites are met.

## Open questions this research did not close

- Primary-source confirmation of Amazon's current Creators API eligibility, price-display and email
  rules, and of the FTC disclosure wording.
- Skimlinks/Sovrn policy on user-submitted links.
- Safari extension and App Store requirements.
- Whether Babylist or competitors earn affiliate revenue from captured items.
- A larger, repeatable fetch probe: more stores, several IPs, including from our production host's
  network, since cloud IPs are blocked more than residential ones.
