# sparcle.app DNS records

Source of truth for the zone records that are **not** managed automatically by Cloudflare Pages.
Pages owns the apex A/AAAA and the `www` CNAME; do not hand-edit those. Everything below is
domain-trust hygiene: email authentication, certificate authorization, and DNS integrity.

Zone is on Cloudflare (`alex.ns.cloudflare.com`, `alina.ns.cloudflare.com`). Registrar is Namecheap.
Mail is Zoho.

Why this file exists: several enterprise reputation and email-security systems read these records
as signals of whether a domain is actively managed. We were missing four of them. See
`/trust/network-allowlist` for the customer-facing side of the same problem.

---

## Current state, verified 2026-07-23

| Record | Status | Value |
|---|---|---|
| SPF | present | `v=spf1 include:zohomail.com ~all` |
| MX | present | `mx.zoho.com` (10), `mx2.zoho.com` (20), `mx3.zoho.com` (50) |
| DMARC | **MISSING** | no `_dmarc.sparcle.app` record at all |
| DKIM | **NOT FOUND** | not present at `zoho`, `zmail`, `default`, `selector1`, or `s1` |
| CAA | **MISSING** | any CA may currently issue for this domain |
| DNSSEC | **NOT ENABLED** | no DS at the registrar, no RRSIG in responses |
| MTA-STS | missing | optional, see below |

Re-verify any time with:

```sh
dig +short TXT _dmarc.sparcle.app
dig +short CAA sparcle.app
dig +short DS sparcle.app
dig +short TXT sparcle.app
```

---

## 1. DMARC (do this first)

Highest value, lowest risk. Start at `p=none`, which is **report-only** and changes nothing about
delivery. It only asks receivers to send you aggregate reports.

**Cloudflare → DNS → Records → Add record**

| Field | Value |
|---|---|
| Type | `TXT` |
| Name | `_dmarc` |
| Content | `v=DMARC1; p=none; rua=mailto:dmarc@sparcle.app; fo=1` |
| TTL | Auto |

Prerequisite: `dmarc@sparcle.app` must be able to receive mail. Create it in Zoho first, or point
`rua=` at an address that already exists. A DMARC record whose reporting address bounces is worse
than none, because it signals the record is unmaintained.

**Then wait two weeks and read the reports before tightening.** The progression is
`p=none` → `p=quarantine` → `p=reject`. Do not skip to `reject`: if any legitimate sending service
(Zoho, a transactional sender, a form handler) is not covered by SPF and DKIM, `reject` silently
destroys that mail. `p=none` cannot break anything, which is exactly why it goes in today.

---

## 2. DKIM

`dig` found no DKIM record at the five selectors we guessed, which most likely means DKIM was never
enabled in Zoho rather than that it is published under an exotic selector.

1. Zoho Mail Admin Console → Domains → sparcle.app → **Email Authentication** → DKIM.
2. If no selector exists, create one. Zoho generates the selector name and public key.
3. Publish exactly what Zoho displays:

| Field | Value |
|---|---|
| Type | `TXT` |
| Name | `<selector>._domainkey` |
| Content | `v=DKIM1; k=rsa; p=<the long public key Zoho gives you>` |
| Proxy | **DNS only** (gray cloud) |

4. Return to Zoho and click Verify.

DKIM matters more than it looks here: DMARC passes on SPF **or** DKIM alignment, and DKIM survives
forwarding while SPF does not. Without DKIM, forwarded mail fails DMARC once you move past `p=none`.

---

## 3. CAA

States which certificate authorities may issue for this domain. Free, and a hygiene signal.

**Careful: a hand-written CAA record can break Cloudflare certificate renewal.** Cloudflare
Universal SSL issues from more than one CA and rotates between them; pinning only the CA that
happens to be serving today (Google Trust Services, `pki.goog`) will cause a future renewal to fail
CAA validation and the site to go down when the current certificate expires.

**Preferred path.** Cloudflare dashboard → SSL/TLS → Edge Certificates → **Add CAA records**. This
generates the correct set for whichever CAs your zone actually uses, and Cloudflare maintains it.
Use this rather than hand-authoring.

**If you author manually**, cover every CA Cloudflare may use, not just the current one:

| Type | Name | Content |
|---|---|---|
| `CAA` | `@` | `0 issue "pki.goog; cansignhttpexchanges=yes"` |
| `CAA` | `@` | `0 issue "letsencrypt.org"` |
| `CAA` | `@` | `0 issue "ssl.com"` |
| `CAA` | `@` | `0 issue "digicert.com"` |
| `CAA` | `@` | `0 issue "sectigo.com"` |
| `CAA` | `@` | `0 iodef "mailto:security@sparcle.app"` |

The `iodef` line asks CAs to report issuance policy violations to us, and reuses the security
address already published in `/.well-known/security.txt`.

After adding, confirm the certificate still renews. Do not add `issuewild` restrictions unless you
have checked nothing depends on a wildcard certificate.

---

## 4. DNSSEC

Two steps across two systems, and the order matters.

1. **Cloudflare** → DNS → Settings → DNSSEC → Enable. Cloudflare shows a DS record
   (key tag, algorithm, digest type, digest).
2. **Namecheap** → Domain List → sparcle.app → Advanced DNS → DNSSEC → add the DS record exactly as
   Cloudflare displayed it.

Do not enable at the registrar first, and do not remove Cloudflare's DNSSEC while the registrar
still publishes the DS record. A DS record that does not match a live signed zone makes the domain
**fail to resolve entirely** for validating resolvers. If anything looks wrong, remove the DS at
Namecheap first, then disable at Cloudflare.

Verify after propagation:

```sh
dig +short DS sparcle.app
dig +dnssec sparcle.app | grep RRSIG
```

---

## 5. SPF tightening (only after DMARC reports are clean)

Current: `v=spf1 include:zohomail.com ~all` (softfail). Target: `-all` (hardfail).

Do **not** change this until two weeks of DMARC aggregate reports confirm no legitimate sender is
missing from SPF. `~all` → `-all` converts a soft signal into outright rejection, so a sender you
forgot about stops delivering the moment you flip it.

---

## 6. MTA-STS (optional, later)

Requires a policy file served over HTTPS at `mta-sts.sparcle.app/.well-known/mta-sts.txt` plus two
DNS records. Real value for inbound mail security, but it is more moving parts than the rest of
this file and it is not a categorization or reputation signal. Do items 1 through 5 first.

---

## Rollout order

1. Create `dmarc@sparcle.app` in Zoho, then add the DMARC record at `p=none`. Zero delivery risk.
2. Enable DKIM in Zoho and publish the selector.
3. Add CAA via the Cloudflare dashboard button.
4. Enable DNSSEC at Cloudflare, then add the DS at Namecheap.
5. Two weeks later, read the DMARC reports. If clean, move to `p=quarantine`, then `p=reject`, and
   tighten SPF to `-all`.

Steps 1 through 3 are safe to do in one sitting. Step 4 is the only one that can take the domain
offline if done out of order, so do it deliberately and verify before walking away.
