#!/usr/bin/env node
// Generates dist/sitemap.xml from the built output, as a postbuild step.
//
// The sitemap used to be hand-maintained in public/sitemap.xml. It drifted:
// by the time it was replaced it listed 15 URLs while the site built 40+,
// omitting the whole /trust/ and /solutions/ trees, and 14 of its 15 lastmod
// dates had been frozen at the same stale day for months. A generated sitemap
// cannot drift, so the set of indexable URLs has one owner: the build.
//
// Ground truth is dist/, not src/pages, so whatever actually shipped is what
// gets listed. A page is excluded when it says so itself via noindex (the
// BaseLayout robots chokepoint) or when it is only a redirect stub.

import { readFileSync, writeFileSync } from "node:fs";
import { readdir } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { join, relative } from "node:path";

const SITE = "https://sparcle.app";
const DIST = "dist";

// Never list these, regardless of what they declare.
//   legacy/ — superseded copies kept only so old deep links resolve.
//   decks/  — persona decks are hand-shared into conversations, not search
//             surfaces, and they are raw HTML under public/ that never passes
//             through BaseLayout, so they cannot declare noindex themselves.
//             Listing them is a deliberate call; until it is made, match the
//             hand-maintained sitemap this replaced and leave them out.
//   404     — an error page is not a destination.
const EXCLUDED_PREFIXES = ["legacy/", "decks/", "404.html"];

async function* walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(path);
    else if (entry.name.endsWith(".html")) yield path;
  }
}

// dist/foo/index.html -> /foo/   ·   dist/index.html -> /
//
// The trailing slash is load-bearing, not cosmetic. Cloudflare Pages serves
// directory-format output at /foo/ and 308s /foo to it, so a sitemap listing
// /foo names a redirect rather than a destination. Google asks for the final
// URL; the earlier hand-maintained sitemap listed the redirect form for every
// entry and this generator faithfully reproduced it. Verified against the live
// site: /pricing -> 308 -> /pricing/, and /products.html -> 308 ->
// /products.html/, so the rule is uniform across every shape we emit.
function toRoute(file) {
  const rel = relative(DIST, file).replace(/index\.html$/, "");
  return "/" + rel;
}

// Map a route back to the .astro page that produced it, so lastmod can be the
// real date that page's content last changed. An honest date is the entire
// point: a sitemap that stamps everything with today's build time gets its
// lastmod ignored, which is how the stale one lost its credibility.
function sourceFor(route) {
  // Routes carry a trailing slash (see toRoute); strip it before joining a path
  // or "/pricing/" resolves to "src/pages/pricing/.astro" and every lastmod
  // silently falls back to null.
  const base = route === "/" ? "index" : route.slice(1).replace(/\/$/, "");

  // /personas/<key>/ is rendered by a dynamic route from a deck file, so there
  // is no src/pages/personas/<key>.astro to date. The deck IS the content —
  // when its copy changes, the page changes — so date the page by the deck.
  const persona = /^personas\/(.+)$/.exec(base);
  if (persona) return [`public/decks/persona-${persona[1]}.html`];

  return [
    `src/pages/${base}.astro`,
    `src/pages/${base}/index.astro`,
  ];
}

function git(args) {
  return execFileSync("git", args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
}

// Per-file history is the whole basis for lastmod here, and a shallow clone has
// none: `git log -1 -- <file>` falls back to the single cloned commit, so every
// page would claim it changed at build time. Cloudflare Pages clones shallow by
// default, which is exactly how the first cut of this script shipped a sitemap
// whose 48 URLs all read the same day. Deepen if we can; if we cannot, drop
// lastmod entirely rather than emit 48 identical lies.
function ensureFullHistory() {
  try {
    if (git(["rev-parse", "--is-shallow-repository"]) !== "true") return true;
  } catch {
    return false; // no git at all (e.g. a tarball build)
  }
  try {
    execFileSync("git", ["fetch", "--unshallow", "--quiet"], { stdio: "ignore" });
    return git(["rev-parse", "--is-shallow-repository"]) !== "true";
  } catch {
    return false;
  }
}

const haveHistory = ensureFullHistory();
if (!haveHistory) {
  console.warn(
    "sitemap: shallow clone and could not deepen; emitting without lastmod.\n" +
      "         Crawlers ignore a lastmod that is always the build date, so no\n" +
      "         date is strictly better than a uniform one.",
  );
}

function lastmodFor(route) {
  if (!haveHistory) return null;
  for (const candidate of sourceFor(route)) {
    try {
      const date = git(["log", "-1", "--format=%cs", "--", candidate]);
      if (date) return date;
    } catch {
      // not a tracked path; try the next candidate
    }
  }
  // lastmod is optional per the sitemap spec. Omitting it beats inventing one.
  return null;
}

const urls = [];
for await (const file of walk(DIST)) {
  const rel = relative(DIST, file);
  if (EXCLUDED_PREFIXES.some((p) => rel.startsWith(p))) continue;

  const html = readFileSync(file, "utf8");
  if (/<meta[^>]+name=["']robots["'][^>]+noindex/i.test(html)) continue;
  if (/<meta[^>]+http-equiv=["']refresh["']/i.test(html)) continue;

  const route = toRoute(file);
  urls.push({ loc: `${SITE}${route === "/" ? "/" : route}`, lastmod: lastmodFor(route) });
}

urls.sort((a, b) => a.loc.localeCompare(b.loc));

const body = urls
  .map(({ loc, lastmod }) =>
    ["  <url>", `    <loc>${loc}</loc>`, lastmod && `    <lastmod>${lastmod}</lastmod>`, "  </url>"]
      .filter(Boolean)
      .join("\n"),
  )
  .join("\n");

writeFileSync(
  join(DIST, "sitemap.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${body}\n</urlset>\n`,
);

console.log(`sitemap: ${urls.length} urls -> ${DIST}/sitemap.xml`);
