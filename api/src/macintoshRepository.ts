// Macintosh Repository lookup — helps pre-fill the Add Software form
// (publisher, category, release year).
//
// There's no official search API, and the site's own free-text search form
// didn't behave as expected when driven directly by URL (it silently fell
// back to a generic alphabetical browse). What *does* work reliably is the
// "browse by starting letter" listing used by their own category pages:
//   https://www.macintoshrepository.org/<section>/software_search.php?b=<LETTER>&order_by=rating&order_dir=DESC&p=<PAGE>&stid=<STID>
//
// So search here works by: taking the first letter of the query, fetching
// (and caching) that letter's top-rated pages for Applications and Games,
// then filtering those titles by substring match. This means a search only
// finds titles that *start* with the same letter as the query — e.g.
// searching "Marathon" works, but searching "Durandal" for "Marathon 2:
// Durandal" won't. Good enough for the common case of typing a title's name
// from the start, not a general full-text search.
//
// This is screen-scraping a third-party site, not a documented API — the
// page structure could change at any time. If results look wrong, the
// selectors/regexes below are the first place to check against the site's
// current HTML.

import * as cheerio from 'cheerio';

const USER_AGENT = 'InventoryDifferent2 (personal collection software, non-commercial)';
const FETCH_TIMEOUT_MS = 8000;
const LETTER_CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours — this is a bigger crawl per letter, cache longer
const DETAILS_CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour
const PAGES_PER_LETTER = 8; // top-rated pages only — keeps the crawl bounded and biases toward well-known titles

interface CacheEntry<T> {
    value: T;
    expiresAt: number;
}

const letterCache = new Map<string, CacheEntry<MacintoshRepoSearchResult[]>>();
const detailsCache = new Map<string, CacheEntry<MacintoshRepoDetails | null>>();

export interface MacintoshRepoSearchResult {
    name: string;
    url: string;
    year?: number;
    sectionLabel: 'Applications' | 'Games';
}

export interface MacintoshRepoDetails {
    name: string;
    url: string;
    author?: string;
    type?: string;
    category?: string;
    categories?: string[];
    year?: number;
}

const DETAIL_FIELD_LABELS = ['Author', 'Publisher', 'Type', 'Category', 'Language', 'Shared by', 'Updated by', 'Other contributors', 'Rating', 'What is', 'Year', 'Download'];

// Robust against the field separators not actually being real line breaks in
// the underlying markup (flattening a page to plain text loses layout, so a
// field's value can run straight into the next label with no \n between them).
// Stops at whichever KNOWN label comes next, rather than assuming \n appears.
function extractDetailField(bodyText: string, label: string): string | undefined {
    const stopLabels = DETAIL_FIELD_LABELS.filter((l) => l !== label).map((l) => l.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    const re = new RegExp(`${label}:\\s*([\\s\\S]*?)(?:${stopLabels.join('|')}:|$)`, 'i');
    const m = bodyText.match(re);
    const value = m?.[1]?.replace(/\s+/g, ' ').trim();
    return value || undefined;
}

async function fetchWithTimeout(url: string): Promise<string> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
        const res = await fetch(url, {
            signal: controller.signal,
            headers: { 'User-Agent': USER_AGENT },
        });
        if (!res.ok) throw new Error(`Request failed: ${res.status}`);
        return await res.text();
    } finally {
        clearTimeout(timeout);
    }
}

function isAllowedHost(urlStr: string): boolean {
    try {
        const u = new URL(urlStr);
        return u.hostname === 'www.macintoshrepository.org' || u.hostname === 'macintoshrepository.org';
    } catch {
        return false;
    }
}

const SECTIONS: { path: string; stid: number; label: 'Applications' | 'Games' }[] = [
    { path: 'applications', stid: 1, label: 'Applications' },
    { path: 'games', stid: 2, label: 'Games' },
];

// Item detail pages follow /<numeric-id>-<slug>, relative or absolute.
function extractItemLinks($: cheerio.CheerioAPI): { href: string; name: string; year?: number }[] {
    const results: { href: string; name: string; year?: number }[] = [];
    const seen = new Set<string>();

    $('a[href]').each((_i, el) => {
        const hrefRaw = $(el).attr('href') || '';
        let pathname: string;
        try {
            pathname = new URL(hrefRaw, 'https://www.macintoshrepository.org').pathname;
        } catch {
            return;
        }
        const match = pathname.match(/^\/(\d+)-[a-z0-9-]+$/i);
        if (!match) return;
        const name = $(el).text().trim();
        if (!name || seen.has(pathname)) return;
        seen.add(pathname);

        // Year sometimes sits in a nearby sibling rather than the same parent —
        // search a reasonably wide surrounding context for "Year: NNNN".
        let context = $(el).closest('h1,h2,h3,li,div').parent().text();
        if (!/Year:/.test(context)) context = $(el).parent().parent().text();
        const yearMatch = context.match(/Year:\s*\n?\s*(\d{4})/) || context.match(/\((\d{4})\)/);

        results.push({
            href: `https://www.macintoshrepository.org${pathname}`,
            name,
            year: yearMatch ? parseInt(yearMatch[1], 10) : undefined,
        });
    });

    return results;
}

function letterBucket(query: string): string {
    const first = query.trim()[0]?.toUpperCase() ?? '';
    return /[A-Z]/.test(first) ? first : '__n';
}

async function fetchLetterSection(letter: string, section: typeof SECTIONS[number]): Promise<MacintoshRepoSearchResult[]> {
    const cacheKey = `${section.label}-${letter}`;
    const cached = letterCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) return cached.value;

    const pageUrls = Array.from({ length: PAGES_PER_LETTER }, (_, i) =>
        `https://www.macintoshrepository.org/${section.path}/software_search.php?b=${encodeURIComponent(letter)}&p=${i + 1}&stid=${section.stid}`
    );

    const pages = await Promise.all(
        pageUrls.map((u) => fetchWithTimeout(u).catch(() => null))
    );

    const results: MacintoshRepoSearchResult[] = [];
    const seen = new Set<string>();
    for (const html of pages) {
        if (!html) continue;
        const $ = cheerio.load(html);
        for (const item of extractItemLinks($)) {
            if (seen.has(item.href)) continue;
            seen.add(item.href);
            results.push({ name: item.name, url: item.href, year: item.year, sectionLabel: section.label });
        }
    }

    letterCache.set(cacheKey, { value: results, expiresAt: Date.now() + LETTER_CACHE_TTL_MS });
    return results;
}

export async function searchMacintoshRepository(query: string): Promise<MacintoshRepoSearchResult[]> {
    const trimmed = query.trim();
    if (!trimmed) return [];

    const letter = letterBucket(trimmed);
    const needle = trimmed.toLowerCase();

    const perSection = await Promise.all(
        SECTIONS.map((section) => fetchLetterSection(letter, section).catch(() => [] as MacintoshRepoSearchResult[]))
    );

    const merged = perSection.flat().filter((r) => r.name.toLowerCase().includes(needle));
    return merged.slice(0, 15);
}

export async function fetchMacintoshRepositoryDetails(url: string): Promise<MacintoshRepoDetails | null> {
    if (!isAllowedHost(url)) throw new Error('URL is not a macintoshrepository.org page');

    const cached = detailsCache.get(url);
    if (cached && cached.expiresAt > Date.now()) return cached.value;

    const html = await fetchWithTimeout(url);
    const $ = cheerio.load(html);

    const name = $('h1').first().text().trim() || $('title').text().split(' - ')[0].trim();
    const bodyText = $('body').text();

    const clean = (s: string | undefined) => s?.replace(/\s+/g, ' ').trim() || undefined;
    const authorRaw = extractDetailField(bodyText, 'Author');
    const publisherRaw = extractDetailField(bodyText, 'Publisher');
    const typeRaw = extractDetailField(bodyText, 'Type');
    const categoryRaw = extractDetailField(bodyText, 'Category');
    const yearRaw = extractDetailField(bodyText, 'Year');
    const yearMatch = yearRaw?.match(/(\d{4})/);

    const categories = categoryRaw ? categoryRaw.split(',').map((c) => c.trim()).filter(Boolean) : undefined;

    const details: MacintoshRepoDetails = {
        name: name || 'Unknown',
        url,
        // Prefer Publisher when present — Author is often the uploader/preservationist, not the software's maker
        author: clean(publisherRaw) ?? clean(authorRaw),
        type: clean(typeRaw),
        category: categoryRaw,
        categories,
        year: yearMatch ? parseInt(yearMatch[1], 10) : undefined,
    };

    detailsCache.set(url, { value: details, expiresAt: Date.now() + DETAILS_CACHE_TTL_MS });
    return details;
}
