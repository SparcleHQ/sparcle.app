# Sparcle

**Private enterprise AI that runs inside your own perimeter.**

Your people are already using AI on their most sensitive work. Today the closest option is
whatever cloud assistant is one tab away, and confidential data, source code, and customer
records go with it. Sparcle builds the governed alternative: an agent platform and an answer
engine that deploy on your infrastructure, use your own models and keys, and leave the
boundary decision to you.

Two products, one architecture:

| Product | What it is | Deployment |
|---|---|---|
| **Bolt** | Extensible, governed agentic platform for users, admins, and organizations | Self-hosted: Docker Compose, Kubernetes, on-prem, VPC, or air-gapped |
| **Aeira** | ACL-aware enterprise search and answer engine (the sovereign data plane) | Self-hosted: AWS, Azure, GCP, on-prem, or air-gapped |

Sparcle does not host your data. Every tier of both products is self-hosted.

## See it in 90 seconds

[![Bolt and Aeira in 90 seconds. Click to watch.](https://sparcle.app/images/enterprise-film-poster.jpg)](https://sparcle.app/media/bolt-aeira-90s.mp4)

*Bolt and Aeira in 90 seconds. The image opens the video on sparcle.app. More demos, the
product pages and downloads are on [sparcle.app](https://sparcle.app/).*

---

## Bolt

*Extensible and governed agentic platform. The agent your security team will actually let you ship.*

Bolt unifies work across email, calendar, tasks, docs, tickets, and code. It is agentic when a
task needs judgment and instant, deterministic, and token-free when it does not. Users build
their own Apps and bring anything to the launcher; admins provision and govern org-wide
capabilities through one MCP-native manifest; the organization keeps all of it inside its own
perimeter, identity-bound and audited.

- **Inside your perimeter, day one.** Self-host on AWS, Azure, GCP, on-prem, or fully
  air-gapped. Identity integrates with SAML, OIDC, JWT, and your existing IdP.
- **BYO LLM, no token markup.** OpenAI, Anthropic, Bedrock, Vertex, Ollama, NVIDIA NIM, or
  your own fine-tuned model, hot-swappable on your own keys. Recognition, decoding, lookups,
  and authorized tool calls run deterministically with zero LLM tokens.
- **Masked at the model boundary.** Detected identifiers are tokenized before a prompt leaves
  your boundary. Point Bolt at a self-hosted model and the rest stays inside it.
- **Governed extensibility.** Integrations, launcher recognition, and what agents may call are
  one MCP-native YAML manifest. Admin Apps win conflicts, entitlements are enforced
  server-side, calls are audited, and Apps never run arbitrary code.
- **Open integrations.** Built on the Model Context Protocol (HTTP transports), with
  connectors for Jira, Confluence, Salesforce, GitHub, Notion, Zendesk, and a growing roster.
- **Surfaces what matters.** The One Thing priority engine (patent pending) reads across
  email, calendar, tasks, and messages and names the single most important thing to do now,
  with a human-readable reason.

**Tiers.** Bolt Authorize $30/seat/month (10-seat minimum) · Bolt Backbone $60/seat/month
(25-seat minimum) · Bolt Certify $90/seat/month (50-seat minimum). Annual contracts; all three
are self-hosted and expose the same platform, so you choose by capability, not by who operates
it. Individuals below the seat minimums can download Bolt free and run it on their own API key.

Details: [sparcle.app/products.html](https://sparcle.app/products.html) ·
[pricing](https://sparcle.app/pricing) · [download](https://sparcle.app/download)

## Aeira

*The sovereign answer engine. Defensible answers your CISO will actually approve.*

Aeira organizes an organization's knowledge and turns it into answers that survive an audit:
filtered to the caller's identity, cited to their source, reproducible, and provably erasable.

- **Identity-bound access control.** Every query is filtered to what the calling identity is
  entitled to see (region, department, sensitivity, role) from your existing IdP. The agent
  never sees what the user cannot.
- **Provable erasure.** Cryptographic erasure rather than row deletion, designed to support
  GDPR Right to be Forgotten and HIPAA restriction obligations with auditor-acceptable proof.
- **Air-gap ready.** Indexing, search, embedding, and retrieval run inside your perimeter.
  Aeira makes no outbound model calls; generation, when you want it, runs on your own model.
- **Stable API across tiers.** Applications written against Catalog scale to Federated without
  integration rewrites.

**Tiers.** Catalog (free with every Bolt plan) → Dynamic $999/month (to 10K records) →
Enhanced $4,999/month (to 100K records) → Federated, custom annual contracts (air-gap,
multi-region, dedicated cluster isolation). Customers run their own compute and storage.

Details: [sparcle.app/products/aeira.html](https://sparcle.app/products/aeira.html)

---

## Who it is for

Built for regulated teams (defense, federal, finance, healthcare, legal) and for any
organization that wants its IP and customer data to stay inside the firewall. Deployable for
HIPAA, GDPR, DPDPA, SOX, and ITAR programs; compliance policy packs are configurable rather
than automatic, and an architecture review covers what applies to your environment.

- [Solutions by industry](https://sparcle.app/solutions)
- [Architecture](https://sparcle.app/architecture) and [security](https://sparcle.app/security)
- [Trust center](https://sparcle.app/trust): where the model runs, subprocessors, network
  allowlist, incident response, vulnerability disclosure, download verification
- [Docs](https://sparcle.app/docs) and the [pilot program](https://sparcle.app/pilot)

Architecture briefs, security posture documentation, and patent claim summaries are shared
under NDA during pilot evaluation.

## Contact

- Sales, security, and pilots: **bolt@sparcle.app**
- Vulnerability disclosure: [sparcle.app/trust/vulnerability-disclosure](https://sparcle.app/trust/vulnerability-disclosure)

---

## About this repository

This repository publishes Bolt. Every installer, the CLI binaries, the checksum manifest and
its signature are released here, and the installers people run point at exactly these URLs.

It is deliberately public and will stay that way. A private repository does not serve release
assets to an anonymous download: the URL returns 404 without a token, which would break
`curl | sh`, Homebrew, winget, and the update check compiled into every copy of Bolt already
installed. The website source moved to a private repository; the artifacts stay here, because
artifacts are what a download needs to be public.

Proprietary; see [LICENSE](LICENSE) and [NOTICE.txt](NOTICE.txt).

## Verify a download

A checksum proves a file arrived intact. It does not prove who made it, since anyone able to
replace an installer could replace the checksum list in the same action. So the checksum
manifest itself is signed, and the public key is published on our own domain rather than
beside the file it signs, which means forging a download requires compromising both.

```sh
curl -LO https://sparcle.app/releases/latest/SHA256SUMS
curl -LO https://sparcle.app/releases/latest/SHA256SUMS.minisig

# proves origin. If this fails, stop: the checksums cannot be trusted either.
minisign -Vm SHA256SUMS -P 'RWR074VTKBGzGWsQbnByhGrH9pQG5uHOJSgqL8rs5Zu4GQAxZ1C+JIza'

# only once the signature verifies
shasum -a 256 --ignore-missing -c SHA256SUMS
```

Each release also carries `VIRUSTOTAL.md`, a report link per installer, so you can read roughly
seventy independent scanners instead of taking our word for it.

Full instructions, including what we do not yet claim about Apple notarization and Windows
SmartScreen: [sparcle.app/trust/verify-download](https://sparcle.app/trust/verify-download/).

## Report a bug

Found something broken? [Open an issue](https://github.com/SparcleHQ/sparcle.app/issues/new/choose).
Bug reports and feature requests for Bolt and Aeira are tracked here, in public.

**Security vulnerabilities do not go in an issue.** Email <security@sparcle.app>; the policy,
including our response commitments and safe harbor for good-faith research, is at
[sparcle.app/trust/vulnerability-disclosure](https://sparcle.app/trust/vulnerability-disclosure/).
See [SECURITY.md](SECURITY.md).

Anything specific to your own deployment — self-hosting, licensing, procurement — goes to
<bolt@sparcle.app> rather than a public issue.
