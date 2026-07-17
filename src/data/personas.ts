/**
 * Persona metadata. the single source for the icon, tag and short title of
 * each persona deck.
 *
 * This lived inside PersonaStrip while the homepage carousel was the only
 * consumer. The /personas/ hub needs exactly the same three fields, and the
 * copy is curated (the short titles are hand-written, not derived from the
 * decks), so the choice was to share it or to write it twice. Two hand-kept
 * lists of the same 18 personas would drift the first time one was edited.
 *
 * The deck FILE remains the source of the prose (see lib/deckContent.ts); this
 * is only the shelf label.
 */

export interface Persona {
  /** Deck filename stem, e.g. "persona-ciso". */
  file: string;
  /** Key in ICONS. */
  icon: string;
  /** Role + function, e.g. "CISO · Security". */
  tag: string;
  /** Short, curated headline. Not the deck's <title>. */
  title: string;
}

/** URL key for a persona: "persona-ciso" -> "ciso". */
export const personaKey = (p: Persona): string => p.file.replace("persona-", "");

export const ICONS: Record<string, string> = {
  zap: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h7l-1 8 10-12h-7z"/></svg>`,
  "shield-check": `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/></svg>`,
  server: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="8" x="2" y="2" rx="2" ry="2"/><rect width="20" height="8" x="2" y="14" rx="2" ry="2"/><line x1="6" x2="6.01" y1="6" y2="6"/><line x1="6" x2="6.01" y1="18" y2="18"/></svg>`,
  "dollar-sign": `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" x2="12" y1="2" y2="22"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>`,
  scale: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v18"/><path d="m19 8 3 8a5 5 0 0 1-6 0z"/><path d="m5 8 3 8a5 5 0 0 1-6 0z"/><path d="M7 21h10"/><path d="M3 7h2c2 0 5-1 7-2 2 1 5 2 7 2h2"/></svg>`,
  "scroll-text": `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 12h-5"/><path d="M15 8h-5"/><path d="M19 17V5a2 2 0 0 0-2-2H4"/><path d="M8 21h12a2 2 0 0 0 2-2v-1a1 1 0 0 0-1-1H11a1 1 0 0 0-1 1v1a2 2 0 1 1-4 0V5a2 2 0 1 0-4 0v2a1 1 0 0 0 1 1h3"/></svg>`,
  users: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><path d="M16 3.128a4 4 0 0 1 0 7.744"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><circle cx="9" cy="7" r="4"/></svg>`,
  "trending-up": `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 7h6v6"/><path d="m22 7-8.5 8.5-5-5L2 17"/></svg>`,
  plug: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22v-5"/><path d="M15 8V2"/><path d="M17 8a1 1 0 0 1 1 1v4a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1z"/><path d="M9 8V2"/></svg>`,
  code: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m16 18 6-6-6-6"/><path d="m8 6-6 6 6 6"/></svg>`,
  compass: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/></svg>`,
  calculator: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="16" height="20" x="4" y="2" rx="2"/><line x1="8" x2="16" y1="6" y2="6"/><line x1="16" x2="16" y1="14" y2="18"/><path d="M16 10h.01"/><path d="M12 10h.01"/><path d="M8 10h.01"/><path d="M12 14h.01"/><path d="M8 14h.01"/><path d="M12 18h.01"/><path d="M8 18h.01"/></svg>`,
  radio: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4.9 19.1C1 15.2 1 8.8 4.9 4.9"/><path d="M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5"/><circle cx="12" cy="12" r="2"/><path d="M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5"/><path d="M19.1 4.9C23 8.8 23 15.1 19.1 19"/></svg>`,
  "user-check": `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><polyline points="16 11 18 13 22 9"/></svg>`,
  headphones: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H4a1 1 0 0 1-1-1v-6a9 9 0 0 1 18 0v6a1 1 0 0 1-1 1h-2a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"/></svg>`,
  briefcase: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="14" x="2" y="7" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></svg>`,
  landmark: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 18v-7"/><path d="M11.119 2.205a2 2 0 0 1 1.762 0l7.84 3.846A.5.5 0 0 1 20.5 7h-17a.5.5 0 0 1-.22-.949z"/><path d="M14 18v-7"/><path d="M18 18v-7"/><path d="M3 22h18"/><path d="M6 18v-7"/></svg>`,
  "badge-check": `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z"/><path d="m9 12 2 2 4-4"/></svg>`,
};

export const PERSONAS: Persona[] = [
  { file: "persona-overview",          icon: "zap",          tag: "Overview · All roles",     title: "One surface for everything" },
  { file: "persona-governance",        icon: "badge-check",   tag: "Governance · Sovereignty", title: "Control it, see it, prove it" },
  { file: "persona-decision-makers",   icon: "landmark",      tag: "Decision Makers · Board",  title: "The exposure you already have, closed" },
  { file: "persona-ciso",              icon: "shield-check",  tag: "CISO · Security",          title: "No prompt leaves the building" },
  { file: "persona-cio",               icon: "server",        tag: "CIO · IT",                 title: "Nine tools, one surface" },
  { file: "persona-cfo",               icon: "dollar-sign",   tag: "CFO · Finance",            title: "Cut the AI bill" },
  { file: "persona-compliance",        icon: "scale",         tag: "Compliance · DPO",         title: "GDPR by architecture" },
  { file: "persona-legal",             icon: "scroll-text",   tag: "General Counsel",          title: "AI without waiving privilege" },
  { file: "persona-chro",              icon: "users",         tag: "CHRO · People",            title: "AI on HR data that HR can defend" },
  { file: "persona-vp-sales",          icon: "trending-up",   tag: "VP Sales · CRO",           title: "Deals move, the CRM stays put" },
  { file: "persona-platform",          icon: "plug",          tag: "Platform · Integrations",  title: "Connect anything" },
  { file: "persona-developer",         icon: "code",          tag: "Developer",                title: "One keystroke, 20 tabs closed" },
  { file: "persona-product-manager",   icon: "compass",       tag: "Product Manager",          title: "Tickets, docs, one box" },
  { file: "persona-finance-ops",       icon: "calculator",    tag: "Finance · Ops",            title: "Catch the typo before the wire" },
  { file: "persona-security-analyst",  icon: "radio",         tag: "Security · SOC",           title: "Triage in a keystroke" },
  { file: "persona-sales-rep",         icon: "user-check",    tag: "Account Executive",        title: "Spend the call closing, not typing" },
  { file: "persona-support",           icon: "headphones",    tag: "Support · CS",             title: "Answer from one box, not ten tabs" },
  { file: "persona-knowledge-worker",  icon: "briefcase",     tag: "Everyday",                 title: "Cut the busywork out of your day" },
];
