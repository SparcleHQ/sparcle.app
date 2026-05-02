# Cloudflare Pages migration runbook

Move sparcle.app from GitHub Pages → Cloudflare Pages, with a real form handler (Turnstile + Resend) and security headers.

DNS is already on Cloudflare. The rest is dashboard work plus pushing the code in this repo.

---

## Concept primer

- **Pages** — hosts static files; auto-deploys on push to `main`.
- **Pages Functions** — server scripts in `functions/` (already in this repo at `functions/api/contact.ts`). Becomes `https://sparcle.app/api/contact` automatically.
- **Workers** — same engine as Functions, but standalone. Not needed here.
- **Turnstile** — Cloudflare's free CAPTCHA. Replaces reCAPTCHA. Two keys: site key (public) + secret key (server only).
- **Resend** — third-party email service. Verifies your domain, gives you an API key, sends form submissions to `bolt@sparcle.app`.

---

## Phase 1 — Connect Pages to GitHub

1. `dash.cloudflare.com` → **Workers & Pages** → **Create** → **Pages** tab → **Connect to Git** → **Get started** under "Import an existing Git repository".
2. Authorize GitHub access to the `Sparcle-LLC` org.
3. Pick repo `Sparcle-LLC/sparcle.app` → **Begin setup**.
4. Build configuration:

   | Field | Value |
   |---|---|
   | Project name | `sparcle-app` (becomes `sparcle-app.pages.dev`) |
   | Production branch | `main` |
   | Framework preset | **Astro** |
   | Build command | `npm run build` |
   | Build output directory | `dist` |
   | Root directory | *(leave blank)* |

5. Expand **Environment variables (advanced)** → add `NODE_VERSION = 22`.
6. **Save and Deploy**. Wait 2–4 min. Open `https://sparcle-app.pages.dev` — site renders, form will fail to submit (env vars not set yet).

---

## Phase 2 — Create Turnstile widget

1. Cloudflare dashboard → **Turnstile** → **Add widget**.
2. Settings:
   - Widget name: `sparcle.app contact form`
   - Hostnames: `sparcle.app`, `www.sparcle.app`, `sparcle-app.pages.dev`
   - Widget mode: **Managed**
3. **Create**. Copy the **Site key** and **Secret key** somewhere safe.

---

## Phase 3 — Set up Resend

1. Sign up at `resend.com`. Free tier covers 3k emails/mo.
2. **Domains** → **Add Domain** → enter `sparcle.app`.
3. Resend shows ~3 DNS records (SPF, DKIM, return-path). For each:
   - In Cloudflare → DNS → add the record exactly as shown.
   - **Important:** set **Proxy status: DNS only** (gray cloud) for these records.
4. Back in Resend → **Verify**. Wait 1–10 min for green checkmarks.
5. Resend → **API Keys** → **Create API Key**. Name `sparcle-pages-contact-form`, scope `Sending access`. Copy the `re_...` key — shown once.

---

## Phase 4 — Wire env vars into Pages

Cloudflare → your `sparcle-app` Pages project → **Settings** → **Environment variables**.

Add to **Production** (and Preview if you want PR previews to work):

| Variable | Value | Type |
|---|---|---|
| `NODE_VERSION` | `22` | Plaintext |
| `PUBLIC_TURNSTILE_SITE_KEY` | site key from Phase 2 | Plaintext |
| `TURNSTILE_SECRET_KEY` | secret key from Phase 2 | **Encrypt / Secret** |
| `RESEND_API_KEY` | `re_...` from Phase 3 | **Encrypt / Secret** |
| `CONTACT_TO_EMAIL` | `bolt@sparcle.app` | Plaintext |
| `CONTACT_FROM_EMAIL` | `Sparcle Contact <forms@sparcle.app>` | Plaintext |

Then **Deployments** → **Retry deployment** so the new env vars take effect.

---

## Phase 5 — Smoke test on `pages.dev`

Open `https://sparcle-app.pages.dev`, trigger the contact modal, fill the form, solve the Turnstile, submit. Expected:

- Green "Request Sent!" confirmation.
- Email arrives at `bolt@sparcle.app` within ~30s, `reply-to` is the submitter.

If it fails: Pages project → **Functions** → **Real-time logs** → submit again → read the error code:

| Error code | Likely cause |
|---|---|
| `invalid_input` | empty/bad email field |
| `captcha_failed` | Turnstile keys mismatched, or hostname not whitelisted |
| `send_failed` | Resend domain unverified, key wrong, or sender address not on a verified domain |

---

## Phase 6 — Switch `sparcle.app` to Pages

Only after Phase 5 works.

1. Pages project → **Custom domains** → **Set up a custom domain** → enter `sparcle.app`.
2. Cloudflare detects DNS is on its network and offers to swap A/AAAA records → **Activate domain**. This is the cutover.
3. Repeat for `www.sparcle.app`.
4. Wait ~30s for cert issuance. Test `https://sparcle.app` and `https://www.sparcle.app`.

---

## Phase 7 — Decommission GitHub Pages

After Phase 6 is verified (give it a day).

1. GitHub → `Sparcle-LLC/sparcle.app` → **Settings** → **Pages** → Source → **None**.
2. Delete `CNAME` from the repo (it's only used by GitHub Pages).
3. (Optional) Delete `.github/workflows/deploy-site.yml` — it's already disabled (manual trigger only).

---

## What got changed in the repo

- `functions/api/contact.ts` — Pages Function: validates input, verifies Turnstile, sends via Resend.
- `public/_headers` — HSTS, CSP, X-Frame-Options, cache headers.
- `src/layouts/BaseLayout.astro` — loads Turnstile API script, exposes `window.SPARCLE_CONFIG.turnstileSiteKey`.
- `src/pages/why-sparcle.astro`, `src/fragments/index-body.html`, `src/fragments/pricing-body.html`, `public/js/shared-nav.js` — all four contact-form handlers now POST to `/api/contact` with a Turnstile token, and show the privacy one-liner.
- `public/css/styles.css` — styles for the Turnstile widget container and privacy note.
- `astro.config.mjs` — added `site: 'https://sparcle.app'`.
- `.github/workflows/deploy-site.yml` — disabled push trigger; manual-only.

---

## Costs

- Cloudflare Pages: free
- Cloudflare Turnstile: free
- Cloudflare Workers (Pages Functions invocations): free up to 100k req/day
- Resend: free up to 3k emails/mo, then $20/mo for 50k

Realistic monthly cost at current scale: **$0**.
