# PDF collateral sources

Tracked HTML sources for the marketing PDFs under `public/docs/pdfs/`. These exist so the
PDFs never go "sourceless" and drift again (the reason the TCO and comparison PDFs carried
stale pricing/tier names).

## Regenerate a PDF

Self-contained HTML → PDF via headless Chrome (no puppeteer dependency):

```
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="public/docs/pdfs/<name>.pdf" \
  "file://$PWD/pdf-sources/<name>.html"
```

Each source sets its own `@page` size/orientation. Verify the output is the intended page
count before committing.

## Canonical facts to keep in sync (as of 2026-07)

- Bolt tiers (all self-hosted): **Authorize $30 / Backbone $60 / Certify $90** per seat/mo,
  plus a **free local** desktop tier. There is **no** managed-hosting tier (the old
  "Absolute / Bundled / Complete" names, and "Bolt Complete = Sparcle-managed hosting", are
  retired — Sparcle hosts no customer data).
- Aeira: Catalog (free w/ Bolt) → Dynamic $999/mo → Enhanced $4,999/mo → Federated from $500K/yr.
- Founding customers: 25% off, 24-month lock, first 50 customers.
