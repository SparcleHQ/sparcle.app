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
| CAA | absent **by decision** | any CA may issue. Deliberate, see section 3 |
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

## 3. CAA — DECIDED AGAINST, 2026-07-23. Do not add.

**Decision: we are not publishing CAA records.** Recorded here so nobody re-opens it as an easy win.

The reasoning. CAA states which certificate authorities may issue for this domain. It was originally
on this list as free hygiene, on the assumption it fed enterprise reputation scoring. It does not:
research on 2026-07-23 found **no verified evidence** that CAA moves URL categorization or reputation
at any gateway vendor. So the upside is close to zero, while the downside is a **silent, delayed site
outage**, which is a bad trade for a domain whose whole current problem is being trusted.

Why the downside is worse than it looks. CAA is enforced **only at certificate issuance**, never when
a browser connects. Add a record pinning the CA serving today (Google Trust Services, `pki.goog`) and
nothing happens: the existing certificate is untouched and the site is fine for weeks. Then Cloudflare
renews, picks a different CA from its pool, that CA reads the CAA record, refuses to issue, and the
certificate lapses. The site goes down with a browser interstitial, five or more weeks after the DNS
change that caused it, with no error in between to warn you.

**If this is ever revisited, the only safe path is the Cloudflare dashboard.** SSL/TLS → Edge
Certificates → the CAA section. Cloudflare knows its own current CA pool and maintains the set when
partners rotate. Do not hand-author, and do not add `issuewild` restrictions: with `issuewild` absent,
`issue` governs wildcards too, which is what we want, and a narrow `issuewild` would block the
`mta-sts.sparcle.app` certificate that section 6 would need.

If it is ever added, also set a calendar check before the then-current certificate expires:

```sh
echo | openssl s_client -connect sparcle.app:443 -servername sparcle.app 2>/dev/null \
  | openssl x509 -noout -issuer -dates
```

An unchanged `notAfter` as expiry approaches means renewal is failing.

<details>
<summary>Record set that would have been used (reference only, not applied)</summary>

Every CA Cloudflare may use, not just the one currently serving. Pinning a single CA is the bug;
listing the pool is the fix.

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

</details>

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
3. Enable DNSSEC at Cloudflare, then add the DS at Namecheap.
4. Two weeks later, read the DMARC reports. If clean, move to `p=quarantine`, then `p=reject`, and
   tighten SPF to `-all`.

CAA is deliberately not in this list. See section 3.

Steps 1 and 2 are safe to do in one sitting. Step 3 is the only one that can take the domain offline
if done out of order, so do it deliberately and verify before walking away.
