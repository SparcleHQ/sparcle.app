export interface PlanPrice {
  selfHosted: string;
  managed: string;
}

export interface PlanTier {
  name: string;
  tagline: string;
  description?: string;
  highlight?: string;
  ctaLabel: string;
  ctaHref: string;
  price?: string;
  prices?: PlanPrice;
  note?: string;
  features: string[];
}

export interface FeaturePoint {
  title: string;
  detail: string;
  icon?: string;
}

export interface ProductPageContent {
  title: string;
  description: string;
  canonical: string;
  productName: string;
  productKicker: string;
  productHeadline: string;
  productIntro: string;
  primaryCtaLabel: string;
  primaryCtaHref: string;
  secondaryCtaLabel: string;
  secondaryCtaHref: string;
  tertiaryCtaLabel?: string;
  tertiaryCtaHref?: string;
  tertiaryCtaTarget?: string;
  badge?: string;
  videoUrl?: string;
  slidesUrl?: string;
  checklistHighlights?: string[];
  highlights: FeaturePoint[];
  agenticActions?: FeaturePoint[];
  faqs: FeaturePoint[];
  /** Optional raw HTML for an architecture diagram, rendered between hero
   *  and highlights. Premium positioning: a real architecture diagram is
   *  the page CTOs and CISOs read first. */
  architectureHtml?: string;
}

export interface PricingPageContent {
  title: string;
  description: string;
  canonical: string;
  pageKicker: string;
  headline: string;
  intro: string;
  schemaName: string;
  schemaDescription: string;
  includesCallout?: string;
  includesCalloutHref?: string;
  toggleLabelLeft?: string;
  toggleLabelRight?: string;
  plans: PlanTier[];
  compareHeaders: string[];
  compareRows: Array<{ feature: string; values: string[] }>;
  faqs: FeaturePoint[];
}

export const boltProductContent: ProductPageContent = {
  title: "Bolt — Patent-pending Enterprise Agent Runtime | Sparcle",
  description:
    "Bolt is the patent-pending enterprise agent runtime — durable agents, MCP-native architecture, multi-tier caching, 8-layer security, priority scoring engine, and adaptive overlay UI. Deployed inside your perimeter.",
  canonical: "https://sparcle.app/products.html",
  productName: "Bolt",
  productKicker: "Enterprise Agent Platform",
  productHeadline: "The agent your security team will actually let you ship.",
  productIntro:
    "Bolt unifies your work — email, calendar, tasks, docs, tickets, code — through one AI agent that runs inside your own perimeter, with your own LLM, and your IP protected at every layer. Connected to 60+ enterprise systems out of the box. Patent-pending architecture; deep details under NDA.",
  primaryCtaLabel: "Schedule Architecture Review",
  primaryCtaHref: "#contact:Bolt Architecture Review",
  secondaryCtaLabel: "Pricing & Tiers",
  secondaryCtaHref: "/pricing#bolt",
  tertiaryCtaLabel: "Technical Slides",
  tertiaryCtaHref: "/bolt-slides.html",
  tertiaryCtaTarget: "_blank",
  badge: "Enterprise",
  videoUrl: "/media/BoltSlides_compact.mp4",
  checklistHighlights: [
    "<strong>Inside your perimeter, day one</strong> — self-host on AWS, Azure, GCP, on-prem, or fully air-gapped. Your data never leaves your network.",
    "<strong>Zero token markup</strong> — bring your own API keys; burn down your existing cloud commits without per-token surcharge",
    "<strong>60+ hrs/employee/year recovered</strong> — context-switching savings alone deliver a 10× return at $30/seat",
    "<strong>BYO LLM</strong> — OpenAI, Anthropic, Bedrock, Vertex, Ollama, NVIDIA NIM, or your own fine-tuned model. Hot-swappable.",
    "<strong>HIPAA / SOX / ITAR / GDPR deployable</strong> — architecture built for regulated environments from day one",
    "<strong>60+ enterprise integrations</strong> — open Model Context Protocol, no vendor lock-in",
    "<strong>Annual contracts, 25-seat minimum</strong> — Bolt Absolute starts at $30/seat/month. Founding Customer pricing available through 2026.",
  ],
  highlights: [
    {
      title: "Inside your perimeter, day one",
      detail:
        "Self-host on AWS, Azure, GCP, on-prem, or fully air-gapped. Identity integrates with SAML, OIDC, JWT, and your existing IdP. Architecture deployable for HIPAA, SOX, ITAR, and GDPR — your data never leaves your network.",
      icon: "shield",
    },
    {
      title: "Zero token markup. Real ROI.",
      detail:
        "Bring your own API keys (OpenAI, Anthropic, Bedrock, Vertex, Ollama, NVIDIA NIM, or your own fine-tuned model). No per-token surcharge. Customers recover an average of 60+ hours per employee per year — a 10× return at $30/seat.",
      icon: "trending-up",
    },
    {
      title: "Surfaces what matters, not what's loud",
      detail:
        "The One Thing™ patent-pending priority engine looks across email, calendar, tasks, and messages and tells you the single most important thing to do right now — with a human-readable reason for the call.",
      icon: "layers",
    },
    {
      title: "60+ integrations. No vendor lock-in.",
      detail:
        "Built on the open Model Context Protocol. Out-of-the-box connections to Slack, Jira, Confluence, Salesforce, GitHub, Notion, Drive, M365, and more. Sub-second responses, durable agents, three operating models from self-hosted to fully managed.",
      icon: "code",
    },
  ],
  agenticActions: [
    {
      title: "Send & Reply to Emails",
      detail:
        "\"Reply to John's proposal and CC the legal team.\" Bolt reads the thread, drafts contextual replies, and sends via Gmail or Outlook — with your confirmation.",
      icon: "mail",
    },
    {
      title: "Schedule Meetings",
      detail:
        "\"Set up a 30-min sync with Sarah tomorrow at 2pm.\" Bolt prepares the event, adds attendees, generates a video link, and presents the invite for your approval.",
      icon: "calendar",
    },
    {
      title: "Manage Tasks",
      detail:
        "\"Mark the auth PR task as done and create a follow-up for testing.\" Bolt stages the updates across Jira, Linear, or Tasks — you confirm and it executes.",
      icon: "check-square",
    },
    {
      title: "Control Your Desktop",
      detail:
        "Browse local files, run terminal commands, open applications — Bolt's native desktop agent gives AI direct access to your machine, sandboxed and permission-controlled.",
      icon: "monitor",
    },
    {
      title: "Phone → Desktop Bridge",
      detail:
        "On the train? Ask Bolt on your phone to find a file on your office MacBook, run a build, or check logs. Secure encrypted tunnel keeps your desktop connected.",
      icon: "smartphone",
    },
    {
      title: "Multi-Machine Routing",
      detail:
        "\"On my Windows PC, find the contract PDF.\" Bolt intelligently routes to the right machine when you have multiple computers connected.",
      icon: "shuffle",
    },
  ],
  faqs: [
    {
      title: "Can Bolt run inside our own perimeter?",
      detail:
        "Yes. Bolt Absolute and Bolt Bundled are self-hosted — Docker Compose for staging, Kubernetes for production HA. Bolt Complete is fully managed by Sparcle. All three tiers expose the same platform; you choose by operating model and compliance posture.",
    },
    {
      title: "What does Bolt save my team in real terms?",
      detail:
        "Customers report 60+ hours per employee per year recovered from context-switching alone. At $60/hr fully loaded labor, that's roughly $3,600/seat/year of recovered productivity vs $360/seat/year for Bolt Absolute — a 10× return. ROI math is conservative and excludes incident-prevention and compliance-cost avoidance.",
    },
    {
      title: "Does Bolt require data migration?",
      detail:
        "No. Bolt connects to your existing systems through 60+ MCP integrations and direct connectors. Teams keep working in their existing tools — Bolt is the unifying agent layer above them, not a replacement.",
    },
    {
      title: "How is our IP protected when we use external LLMs?",
      detail:
        "Bolt's security pipeline applies PII detection, policy guardrails, audit logging, and privacy-preserving context handling before any prompt leaves your perimeter. With BYOK and a covered LLM provider (DPA + zero-retention), you get the upside of frontier models without your IP entering training data. With BYO self-hosted LLM, nothing leaves at all.",
    },
    {
      title: "What's the seat minimum?",
      detail:
        "Bolt Absolute: 25 seats. Bolt Bundled: 50 seats. Bolt Complete: 100 seats. Annual contracts. Below those minimums, Bolt Personal is free with your own API key.",
    },
    {
      title: "What's the Founding Customer Program?",
      detail:
        "First 50 customers get 40% off published pricing locked for 24 months, direct founder access, weekly office hours, and roadmap influence. Open through end of 2026 or until 50 customers are signed.",
    },
    {
      title: "Can we see the architecture and security details?",
      detail:
        "Yes — under NDA. Detailed architecture briefs, security posture documentation, and patent claim summaries are shared during the pilot evaluation. Schedule an architecture review and we'll cover what's relevant to your environment.",
    },
  ],
};

export const aeiraProductContent: ProductPageContent = {
  title: "Aeira — Air-Gap-Ready Hybrid Search for Regulated Industries | Sparcle",
  description:
    "Aeira is the 100% self-hosted enterprise data plane for regulated industries. 4-level ACL, KMS-enveloped storage with crypto-shred for GDPR/HIPAA erasure, weighted RRF hybrid search, license-validated tiers. Defense, finance, healthcare, federal.",
  canonical: "https://sparcle.app/products/aeira.html",
  productName: "Aeira",
  productKicker: "Compliance-Grade Search · Regulated Industries",
  productHeadline: "The data plane your CISO will actually approve.",
  productIntro:
    "Aeira is the 100% self-hosted enterprise data plane for regulated industries — defense, finance, healthcare, federal. Identity-bound search, provable erasure for GDPR / HIPAA obligations, audit-trail responses your compliance team can actually point to. Deploy on AWS, Azure, GCP, on-prem, or fully air-gapped — your data never leaves your perimeter. Architecture details available under NDA.",
  primaryCtaLabel: "Design Aeira Deployment",
  primaryCtaHref: "#contact:Aeira Deployment Design",
  secondaryCtaLabel: "Pricing & Tiers",
  secondaryCtaHref: "/pricing.html#aeira",
  tertiaryCtaLabel: "Architecture Slides",
  tertiaryCtaHref: "/aeira-slides.html",
  tertiaryCtaTarget: "_blank",
  slidesUrl: "/aeira-slides.html",
  checklistHighlights: [
    "<strong>Identity-bound access control</strong> — every query is filtered to what the calling user is entitled to see; the agent never sees what they can't",
    "<strong>Provable erasure for GDPR / HIPAA</strong> — cryptographically destroy the data, not just delete the row; auditor-acceptable proof",
    "<strong>100% self-hosted</strong> — AWS, Azure, GCP, on-prem, or fully air-gapped; data never leaves your perimeter",
    "<strong>Audit-trail responses</strong> — every result carries the why-filtered context regulators ask for during reviews",
    "<strong>Standalone or with Bolt</strong> — buy Aeira alone for ACL-aware regulated search, or get Catalog free with every Bolt plan",
    "<strong>Stable API across all tiers</strong> — start with Catalog, scale to Federated without integration rewrites",
    "<strong>License-validated</strong> — Catalog (free with Bolt) → Dynamic ($999/mo) → Enhanced ($4,999/mo) → Federated (from $500K/yr)",
  ],
  highlights: [
    {
      title: "Identity-bound access control",
      detail:
        "Every query is automatically filtered to what the calling user's identity is entitled to see — region, department, sensitivity clearance, and role, derived from your existing IdP. Your AI agents and your auditors see the same answer.",
      icon: "lock",
    },
    {
      title: "Provable erasure for GDPR / HIPAA",
      detail:
        "When a tenant invokes the Right to be Forgotten or you need HIPAA-compliant erasure, Aeira gives you cryptographic proof — not just a deleted row. Auditor-acceptable, independently verifiable.",
      icon: "shield",
    },
    {
      title: "Air-gap-ready by default",
      detail:
        "Deploy on AWS, Azure, GCP, on-prem, or fully air-gapped. All indexing, search, embedding, and AI retrieval run inside your security perimeter. No outbound calls, no telemetry, no surprises during a security review.",
      icon: "server",
    },
    {
      title: "Stable API. Standalone or with Bolt.",
      detail:
        "Same contract from Catalog (free with Bolt) through Federated (air-gapped enterprise). Scale tiers without integration rewrites. Customers with their own AI layer can buy Aeira alone; everyone else gets it bundled.",
      icon: "code",
    },
  ],
  faqs: [
    {
      title: "Is Aeira Catalog included in all Bolt plans?",
      detail:
        "Yes. Catalog is bundled free in every Bolt plan as the baseline data plane. Dynamic, Enhanced, and Federated are paid Aeira tiers for larger scale and stronger governance.",
    },
    {
      title: "What does air-gapped deployment mean in practice?",
      detail:
        "Federated-tier deployments run entirely inside your security perimeter — typically a VPC, on-prem cluster, or physically air-gapped network. No outbound calls, no telemetry, no third-party model API calls. License validation happens via an offline-signed token, refreshed on a customer-controlled schedule. Catalog and Dynamic also run fully on-prem; Federated adds dedicated cluster isolation and custom topology.",
    },
    {
      title: "How does Aeira help with GDPR / HIPAA erasure obligations?",
      detail:
        "Aeira gives you cryptographic erasure rather than just row-deletion — when an erasure obligation applies, the encrypted data becomes mathematically unreadable. The result is auditor-acceptable proof of erasure that satisfies GDPR Right to be Forgotten and HIPAA Right to Restrict Disclosure. We can walk through the specifics in an architecture review under NDA.",
    },
    {
      title: "Can we bring our own data, embedding model, and infrastructure?",
      detail:
        "Yes to all three. Customer pays for their own compute, storage, and infrastructure (except in Bolt Complete, which is fully managed). Aeira ships with sensible defaults but supports BYO embedding models for customers with specialized domain models. The access-control semantics stay consistent regardless of which embedder is used.",
    },
    {
      title: "What changes when we upgrade tiers?",
      detail:
        "Scale and governance depth — not the API. Catalog is keyword-only with hard record limits. Dynamic adds full hybrid search up to 10K records. Enhanced supports up to 100K records with high-throughput ingestion. Federated adds air-gap, multi-region, and dedicated cluster isolation. Applications written against Catalog scale up to Federated without rewrites.",
    },
    {
      title: "Pricing — what does each tier cost?",
      detail:
        "Catalog: free with every Bolt plan. Dynamic: $999/month (up to 10K records). Enhanced: $4,999/month (up to 100K records, high-throughput ingestion). Federated: custom annual contracts from $500K/year (defense / federal / regulated tier). All paid tiers include software updates, patches, and support — customer pays for their own compute, storage, and infrastructure.",
    },
    {
      title: "Can we see the architecture and security details?",
      detail:
        "Yes — under NDA. Detailed architecture briefs, encryption specifics, key management semantics, and audit-trail formats are shared during pilot evaluation. Schedule an Aeira deployment design call and we'll cover what's relevant to your environment.",
    },
  ],
};

export const boltPricingContent: PricingPageContent = {
  title: "Bolt Pricing | Sparcle",
  description:
    "Bolt pricing for enterprise teams: Absolute, Bundled, and Complete, with included Aeira Catalog in every plan.",
  canonical: "https://sparcle.app/pricing",
  pageKicker: "Bolt Pricing",
  headline: "Simple, transparent pricing for the Bolt platform.",
  intro:
    "Choose your operating model. Every Bolt plan includes the core platform plus Aeira Catalog for governed discovery out of the box.",
  schemaName: "Bolt Pricing",
  schemaDescription:
    "Bolt platform pricing with three tiers and included Aeira Catalog.",
  includesCallout:
    "Aeira Catalog is included in every Bolt plan. Need higher scale or governance? View Aeira plans.",
  includesCalloutHref: "/pricing.html#aeira",
  plans: [
    {
      name: "Bolt Absolute",
      tagline: "Self-hosted platform with full data sovereignty",
      price: "$30 / seat / month",
      note: "Annual contract",
      ctaLabel: "Request Pilot",
      ctaHref: "#contact:Bolt Absolute Pilot",
      features: [
        "Self-hosted deployment",
        "BYOK and BYO LLM (private models)",
        "Unified search and AI chat",
        "Desktop and web clients",
      ],
    },
    {
      name: "Bolt Bundled",
      tagline: "Self-hosted platform with Sparcle-managed AI",
      price: "$60 / seat / month",
      note: "Annual contract",
      highlight: "Most popular",
      ctaLabel: "Request Pilot",
      ctaHref: "#contact:Bolt Bundled Pilot",
      features: [
        "Everything in Absolute",
        "Managed inference and routing",
        "Policy controls and analytics",
        "Priority support",
      ],
    },
    {
      name: "Bolt Complete",
      tagline: "Fully managed platform and hosting",
      price: "$90 / seat / month",
      note: "Annual contract",
      ctaLabel: "Talk to Sales",
      ctaHref: "#contact:Bolt Complete Inquiry",
      features: [
        "Everything in Bundled",
        "Managed hosting and scaling",
        "Mobile apps and enterprise SLA",
        "Dedicated onboarding support",
      ],
    },
  ],
  compareHeaders: ["Absolute", "Bundled", "Complete"],
  compareRows: [
    {
      feature: "Bolt platform (search, chat, actions)",
      values: ["Yes", "Yes", "Yes"],
    },
    {
      feature: "Aeira Catalog included",
      values: ["Yes", "Yes", "Yes"],
    },
    {
      feature: "Managed AI inference",
      values: ["No", "Yes", "Yes"],
    },
    {
      feature: "Managed hosting",
      values: ["No", "No", "Yes"],
    },
    {
      feature: "Support model",
      values: ["Email", "Priority", "24/7 + SRE"],
    },
    {
      feature: "Deployment setup",
      values: ["Docker / K8s", "Docker / K8s", "Fully managed"],
    },
  ],
  faqs: [
    {
      title: "Is Aeira Catalog included?",
      detail:
        "Yes. Aeira Catalog is included in all Bolt pricing tiers and highlighted as the default data baseline.",
    },
    {
      title: "Can we start self-hosted and move to managed later?",
      detail:
        "Yes. You can start with Absolute or Bundled and move to Complete as operational requirements change.",
    },
  ],
};

export const aeiraPricingContent: PricingPageContent = {
  title: "Aeira Pricing | Sparcle",
  description:
    "Aeira pricing: free Catalog directory with every Bolt plan, paid tiers for full enterprise search platform — index any corporate data with hybrid AI search.",
  canonical: "https://sparcle.app/pricing/aeira.html",
  pageKicker: "Aeira Pricing",
  headline: "Index anything. Find everything. Your infrastructure.",
  intro:
    "Start free with Bolt Catalog — a curated company directory included in every Bolt plan. Need to index wiki pages, runbooks, knowledge base articles, or any corporate data? Aeira is a full enterprise search platform with hybrid AI search and ACL enforcement.",
  schemaName: "Aeira Pricing",
  schemaDescription:
    "Aeira pricing with free Catalog directory and paid enterprise search platform tiers.",
  toggleLabelLeft: "Monthly",
  toggleLabelRight: "Annual",
  plans: [
    {
      name: "Catalog",
      tagline: "Curated company directory included with Bolt",
      prices: {
        selfHosted: "Free w/ Bolt",
        managed: "Free w/ Bolt",
      },
      note: "8 core + 2 custom categories · 50 records each · fair-use limits",
      ctaLabel: "Included with Bolt",
      ctaHref: "/pricing.html",
      features: [
        "8 core categories (offices, holidays, benefits, apps, IT, HR, travel, security)",
        "Up to 2 custom categories",
        "50 records per category · link-centric entries",
        "4-level ACL (public, department, group, user)",
        "Browse + keyword search with ACL filtering",
        "Import via CSV, JSON, or YAML templates",
        "Integrated with Bolt AI chat",
        "Fair-use query and storage limits",
      ],
    },
    {
      name: "Dynamic",
      tagline: "Index any corporate data. Hybrid AI search across everything.",
      prices: {
        selfHosted: "$999 / month",
        managed: "$999 / month",
      },
      note: "Up to 10K records · Private Instance License",
      ctaLabel: "Start Dynamic",
      ctaHref: "#contact:Aeira Dynamic",
      features: [
        "Everything in Catalog",
        "Ingest any document — wikis, runbooks, guides, KB articles, and more",
        "Hybrid search (keyword + semantic vector)",
        "20 ready-made entity templates + custom types via API",
        "4-level ACL (public, department, group, user)",
        "Bulk ingestion API (CSV, YAML, JSON)",
        "Up to 10K indexed records",
        "Operational metrics (Prometheus)",
        "Email support (5-day SLA)",
      ],
    },
    {
      name: "Enhanced",
      tagline: "Production-scale search with async ingestion and enterprise controls",
      prices: {
        selfHosted: "$4,999 / month",
        managed: "$4,999 / month",
      },
      note: "Up to 100K records · Private Instance License",
      highlight: "Data Leader",
      ctaLabel: "Talk to Aeira Team",
      ctaHref: "#contact:Aeira Enhanced",
      features: [
        "Everything in Dynamic",
        "Up to 100K indexed records",
        "Async Kafka ingestion — high-throughput, guaranteed delivery",
        "Per-user daily quotas with soft & hard limits",
        "30 QPS rate limiting with burst & sliding window",
        "Region-aware ACL filtering",
        "Dedicated namespace isolation",
        "50K queries/day included",
        "Priority support (1-business-day SLA)",
      ],
    },
  ],
  compareHeaders: ["Catalog", "Dynamic", "Enhanced", "Federated"],
  compareRows: [
    {
      feature: "What you can index",
      values: ["10 directory categories", "Any document or data", "Any document or data", "Any document or data"],
    },
    {
      feature: "Entity templates",
      values: ["8 core + 2 custom", "20 + custom via API", "20 + custom via API", "20 + custom via API"],
    },
    {
      feature: "Records",
      values: ["500 (50/cat)", "Up to 10K", "Up to 100K", "Negotiated"],
    },
    {
      feature: "Search",
      values: ["Keyword", "Hybrid", "Hybrid", "Hybrid"],
    },
    {
      feature: "ACL model",
      values: ["4-level", "4-level", "4-level + region", "4-level + region"],
    },
    {
      feature: "Ingestion",
      values: ["Manual templates", "Bulk API", "Bulk + async", "Bulk + async"],
    },
    {
      feature: "Query volume",
      values: ["Fair-use", "10K/day", "50K/day", "Negotiated"],
    },
    {
      feature: "Rate limiting",
      values: ["—", "30 QPS", "30 QPS + burst", "Custom profile"],
    },
    {
      feature: "Per-user quotas",
      values: ["—", "—", "Soft + hard limits", "Custom"],
    },
    {
      feature: "Support",
      values: ["Platform", "Standard", "Priority + advisory", "Dedicated team"],
    },
  ],
  faqs: [
    {
      title: "What's the difference between Catalog and Dynamic?",
      detail:
        "Catalog is a curated directory with keyword search and manual updates. Dynamic is a full enterprise search platform: ingest any document, search with hybrid AI, use 20 templates or custom types, and enforce 4-level ACL.",
    },
    {
      title: "Can I index any type of corporate data?",
      detail:
        "Yes. On Dynamic and above, you can ingest any document — wiki pages, runbooks, onboarding guides, KB articles, and more. The 20 built-in entity templates are a starting point, not a limit.",
    },
  ],
};
