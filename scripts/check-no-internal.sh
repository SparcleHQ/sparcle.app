#!/usr/bin/env bash
# Guard: fail the build if internal-marked content is present in publicly-served
# locations. Prevents a repeat of the "Sparcle-Internal agent-landscape" doc being
# published. Runs in prebuild, so a broken state fails the deploy.
#
# Deliberately NARROW markers (not bare "Confidential", which appears on legitimate
# customer-facing collateral like the compliance handbook):
#   - "Sparcle-Internal" / "Internal-Only" / "DO-NOT-PUBLISH"
#   - internal private-repo paths: "sparcle-LLC/business", "outreach/playbook"
set -uo pipefail

MARKERS='Sparcle[- ]Internal|Internal[- ]Only|DO[- ]NOT[- ]PUBLISH|sparcle-LLC/business|outreach/playbook'
PDF_MARKERS='Sparcle.?Internal|sparcle-LLC/business|outreach/playbook'
FAIL=0

# 1) Text/source under public/ and pdf-sources/
if grep -rInE "$MARKERS" public pdf-sources \
     --include='*.html' --include='*.astro' --include='*.md' \
     --include='*.txt' --include='*.js' --include='*.json' 2>/dev/null; then
  echo "ERROR: internal-marked content found in public source (above)." >&2
  FAIL=1
fi

# 2) PDFs under public/ (best-effort; needs pdftotext)
if command -v pdftotext >/dev/null 2>&1; then
  while IFS= read -r f; do
    if pdftotext "$f" - 2>/dev/null | grep -qiE "$PDF_MARKERS"; then
      echo "ERROR: internal-marked content in published PDF: $f" >&2
      FAIL=1
    fi
  done < <(find public -name '*.pdf' 2>/dev/null)
else
  echo "check-no-internal: WARN pdftotext not installed; PDF scan skipped." >&2
fi

if [ "$FAIL" -ne 0 ]; then
  echo "check-no-internal: FAILED — internal content must not ship. Move it out of public/ and pdf-sources/." >&2
  exit 1
fi
echo "check-no-internal: clean"
