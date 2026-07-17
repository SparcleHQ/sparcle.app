/**
 * Extracts readable prose from a persona deck so it can be server-rendered as a
 * real page.
 *
 * WHY EXTRACT INSTEAD OF EMBED
 * ----------------------------
 * The decks in public/decks are chrome-less HTML payloads that PersonaStrip
 * fetches and injects into a shadow DOM. Two consequences fall out of that:
 *
 *   1. Their prose is invisible to every crawler — 175k characters across 18
 *      decks that appear in no document a bot ever sees. Shadow DOM is exactly
 *      what makes the modal work and exactly what makes it unindexable.
 *   2. Their CSS declares `:root{--bg:#070b14;...}`, which would capture the
 *      site's theme variables if injected into a normal page. The shadow root
 *      is what contains it today.
 *
 * So a persona page cannot simply embed a deck: shadow DOM would keep it
 * unindexable, and no shadow DOM would break the site's theming. We take the
 * content and leave the presentation — the deck stays the deck (reachable via
 * the homepage modal at /#deck=<key>), and the page carries the same substance
 * as prose inside BaseLayout, where it gets nav, footer, canonical, a CTA and a
 * crawlable URL.
 *
 * The deck files stay the single source of the copy. Nothing is re-authored
 * here, so check-claims.sh keeps governing one body of text, not two.
 */

export interface PersonaSection {
  title: string;
  paragraphs: string[];
}

export interface PersonaContent {
  /** The deck's own <title> — already written for the persona. */
  title: string;
  /** First substantial paragraph, trimmed for a meta description. */
  description: string;
  sections: PersonaSection[];
}

const stripTags = (s: string): string => s.replace(/<[^>]+>/g, " ");

const decodeEntities = (s: string): string =>
  s
    .replace(/&#8220;|&#8221;|&ldquo;|&rdquo;/g, '"')
    .replace(/&#8217;|&rsquo;/g, "’")
    .replace(/&mdash;/g, "—")
    .replace(/&middot;/g, "·")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&quot;/g, '"');

const clean = (s: string): string => decodeEntities(stripTags(s)).replace(/\s+/g, " ").trim();

/** Deck titles carry [[...]] markers that the slide renderer uses for emphasis. */
const unmark = (s: string): string => s.replace(/\[\[|\]\]/g, "");

export function parseDeck(html: string): PersonaContent {
  const title = unmark(clean(/<title>([\s\S]*?)<\/title>/.exec(html)?.[1] ?? ""));

  // Slides are flat siblings, so split on the opening tag rather than trying to
  // balance nested divs with a regex.
  const chunks = html.split(/<div class="slide/).slice(1);
  const sections: PersonaSection[] = [];

  for (const chunk of chunks) {
    const heading = unmark(clean(/data-title="([^"]*)"/.exec(chunk)?.[1] ?? ""));

    const paragraphs: string[] = [];
    for (const m of chunk.matchAll(/<(?:p|h1|h2|h3)\b[^>]*>([\s\S]*?)<\/(?:p|h1|h2|h3)>/g)) {
      const text = clean(m[1]);
      // Drop UI fragments and single words — they read as noise out of the deck.
      if (text.length > 40 && text.split(" ").length > 6) paragraphs.push(text);
    }

    const deduped = [...new Set(paragraphs)];
    if (heading && deduped.length) sections.push({ title: heading, paragraphs: deduped });
  }

  return { title, description: buildDescription(sections), sections };
}

/**
 * Compose a meta description from the opening prose.
 *
 * A cover slide's first line is often a tagline ("Use AI on the contract. Keep
 * the privilege." — 43 chars). That is too thin to survive as a search snippet:
 * engines discard a description that short and write their own from the page,
 * so we lose control of what a buyer reads. Accumulate whole paragraphs until
 * there is enough substance, then cut on a sentence or word boundary rather
 * than mid-word.
 */
function buildDescription(sections: PersonaSection[]): string {
  const MAX = 158; // comfortably inside where Google truncates
  const MIN = 110;

  const pool = sections.flatMap((s) => s.paragraphs);
  let text = "";
  for (const p of pool) {
    text = text ? `${text} ${p}` : p;
    if (text.length >= MIN) break;
  }
  if (!text) return "";
  if (text.length <= MAX) return text;

  const window = text.slice(0, MAX + 1);
  // Prefer ending on a sentence; fall back to the last whole word.
  const sentence = Math.max(window.lastIndexOf(". "), window.lastIndexOf("? "), window.lastIndexOf("! "));
  if (sentence >= MIN) return window.slice(0, sentence + 1);
  return `${window.slice(0, window.lastIndexOf(" "))}…`;
}
