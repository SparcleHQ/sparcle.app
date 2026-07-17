#!/usr/bin/env bash
# Fails the build if an em-dash reaches copy or comments.
#
# WHY THIS EXISTS
# ---------------
# The founder's rule is permanent and was restated emphatically on 2026-06-30:
# no em-dashes anywhere. The reason is not taste alone. An em-dash reads as
# machine-generated, and this is a product that argues for itself on being
# trustworthy and human. The rule had no chokepoint, so the site accumulated 849
# of them across the decks, pages and fragments before anyone counted.
#
# That is the same story as the sitemap and the claims: a rule with no owner
# does not survive contact with 18 hand-maintained files. This script is the
# owner. It runs in prebuild next to check-no-internal.sh and check-claims.sh.
#
# SCOPE
# -----
# Markup, prose AND code comments in .astro/.html under decks, pages and
# fragments. The rule is explicit that comments count: "NO em-dashes in my chat
# replies, commit messages, code comments, pack titles/YAML, or anything else."
#
# <style>/<script> are covered too. They were excluded at first as "not
# reader-visible", but the rule says comments count, those blocks SHIP inside
# the HTML, and a `content: "..."` rule paints straight onto the page. The 125
# CSS comments that exclusion was hiding are gone, so nothing needs the carve-out.
#
# Code that must name the character (a decoder, this detector) marks its line
# with `check-emdash:allow`.
#
# WHEN THIS FIRES, fix the sentence, do not silence the guard. Replace the dash
# with what a careful writer would choose:
#   appositive / restatement          -> colon, or comma
#   two independent clauses           -> period, and capitalize the next word
#   parenthetical (no internal comma) -> commas on both sides
#   parenthetical WITH a comma list   -> colon + period; commas here make soup
#   short label chains                -> middot (·), the house style
# Do not swap every dash for the same character. A comma splice reads MORE
# machine-written than the dash it replaced, which defeats the point.

set -uo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Strip <style>/<script>, then report any remaining em-dash with its file:line.
# Scope is every directory that can put a character on the page. The first cut
# scanned only decks, pages and fragments, and reported the site clean while
# BaseLayout.astro (which renders into EVERY page) still carried three, and
# lib/faqSchema.ts decoded &mdash; straight into the JSON-LD that Google reads
# for rich results. A guard is only as good as the ground it covers.
find public/decks src/pages src/fragments src/layouts src/components src/lib src/data \
  -type f \( -name '*.html' -o -name '*.astro' -o -name '*.ts' \) \
  -not -path '*/legacy/*' -print0 2>/dev/null |
while IFS= read -r -d '' f; do
  python3 - "$f" <<'PY' >>"$tmp"
import re, sys
p = sys.argv[1]
raw = open(p, encoding="utf-8", errors="ignore").read()
src = raw
# Blank out style/script so their comments do not trip the guard, while keeping
# line numbers intact.
#
# Self-closing tags MUST be handled first. src/pages/download.astro carries
# <script type="application/ld+json" ... /> and a naive
# <script[\s\S]*?</script> then runs from that tag to the NEXT real </script>,
# blanking 239 of the file's 541 lines. The guard reported the page clean while
# three reader-visible em-dashes sat inside the hole.
def blank(m): return re.sub(r"[^\n]", " ", m.group(0))
# Nothing is blanked any more: style/script are in scope. Kept as a note because
# a naive <script[\s\S]*?</script> once ran from a self-closing
# <script type="application/ld+json" ... /> to the next real </script>, blanking
# 239 of download.astro's 541 lines while reporting the page clean.

# CSS `content:` IS reader-visible: content: "—" paints a literal em-dash onto
# the page. Those live inside <style>, which we just blanked, so pull them back
# out of the original source and check them on their own.
for i, line in enumerate(raw.split("\n"), 1):
    if re.search(r"content\s*:\s*[\"\']([^\"\']*—[^\"\']*)[\"\']", line):
        print(f"{p}:{i}: [css content, rendered to readers] {line.strip()[:80]}")

for i, line in enumerate(src.split("\n"), 1):
    if "check-emdash:allow" in line:
        continue  # a decoder/detector that must name the character
    if "—" in line or "&mdash;" in line:
        print(f"{p}:{i}: {line.strip()[:100]}")
PY
done

if [ -s "$tmp" ]; then
  n=$(wc -l <"$tmp" | tr -d ' ')
  echo "check-emdash: FAILED. $n line(s) carry an em-dash."
  echo "The founder's rule is: no em-dashes anywhere. Rewrite the sentence."
  echo
  head -40 "$tmp"
  [ "$n" -gt 40 ] && echo "  ... and $((n - 40)) more"
  exit 1
fi

echo "check-emdash: clean"
