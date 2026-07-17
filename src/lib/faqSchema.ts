/**
 * FAQPage structured-data helper: emits Google FAQ rich-snippet JSON-LD.
 *
 * Google's guideline: the schema Q&A text MUST match the visible FAQ
 * content on the page. Page-level FAQ arrays store answers as HTML
 * (e.g. "<p>...<kbd>Cmd+K</kbd>...</p>"), so we strip tags and decode
 * the handful of entities the FAQ copy actually uses to produce the
 * plain-text answer the schema requires. We do NOT paraphrase: the
 * text is the visible answer with markup removed.
 */
export interface FaqItem {
  question: string;
  answer: string;
}

/** Strip HTML tags and decode common entities to plain text. */
export function htmlToPlainText(html: string): string {
  return html
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&ldquo;|&rdquo;/g, '"')
    .replace(/&lsquo;|&rsquo;/g, "'")
    .replace(/&mdash;/g, "—")  // check-emdash:allow (this line handles the character itself)
    .replace(/&ndash;/g, "–")
    .replace(/&rarr;/g, "→")
    .replace(/&middot;/g, "·")
    .replace(/&hellip;/g, "…")
    .replace(/\s+/g, " ")
    .trim();
}

/** Build a schema.org FAQPage object from {question, answer(HTML)} items. */
export function buildFaqSchema(items: FaqItem[]) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map((item) => ({
      "@type": "Question",
      name: htmlToPlainText(item.question),
      acceptedAnswer: {
        "@type": "Answer",
        text: htmlToPlainText(item.answer),
      },
    })),
  };
}
