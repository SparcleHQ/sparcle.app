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
  faqs: FeaturePoint[];
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
  title: "Bolt Product | Sparcle",
  description:
    "Bolt is the enterprise AI operating system that unifies search, chat, and actions across your tool stack.",
  canonical: "https://sparcle.app/products.html",
  productName: "Bolt",
  productKicker: "Enterprise AI Operating System",
  productHeadline: "One intelligence layer above every system your teams use.",
  productIntro:
    "Bolt eliminates app-hopping by grounding answers and actions in your enterprise systems with secure context and policy control.",
  primaryCtaLabel: "Schedule Enterprise Demo",
  primaryCtaHref: "#contact:Bolt Demo Request",
  secondaryCtaLabel: "Features and Pricing",
  secondaryCtaHref: "/pricing.html#bolt",
  tertiaryCtaLabel: "Learn More",
  tertiaryCtaHref: "/bolt-slides.html",
  tertiaryCtaTarget: "_blank",
  badge: "Enterprise",
  videoUrl: "/media/BoltSlides_compact.mp4",
  checklistHighlights: [
    "<strong>Enterprise integrations</strong> via open protocols (email, calendar, messaging, project management, and more)",
    "<strong>High cache hit rate</strong> – intelligent multi-tier caching dramatically reduces costs",
    "<strong>On-prem/VPC deployment</strong> – your data stays in your perimeter",
    "<strong>BYOL</strong> – use OpenAI, Anthropic, Google, or local models",
    "<strong>~$3M+ ROI</strong> for 1,000 employees (estimated at $50/hr loaded cost)",
  ],
  highlights: [
    {
      title: "Unified AI Workspace",
      detail:
        "Search, chat, and automation in one flow across email, calendar, docs, tickets, messaging, and code.",
      icon: "layers",
    },
    {
      title: "Enterprise Security",
      detail:
        "SSO, audit logging, policy controls, and privacy-first architecture for regulated environments.",
      icon: "shield",
    },
    {
      title: "Deployment Flexibility",
      detail:
        "Self-host in your perimeter or run with Sparcle-managed AI and hosting, depending on risk profile.",
      icon: "server",
    },
    {
      title: "Built for ROI",
      detail:
        "Designed to recover deep work time and reduce operational drag from fragmented workflows.",
      icon: "trending-up",
    },
  ],
  faqs: [
    {
      title: "Can Bolt run in our own environment?",
      detail:
        "Yes. Bolt supports self-hosted deployment and managed options. You can choose by compliance and operating model.",
    },
    {
      title: "Does Bolt require data migration?",
      detail:
        "No. Bolt connects to your systems through connectors and APIs. Teams keep working in existing tools.",
    },
  ],
};

export const aeiraProductContent: ProductPageContent = {
  title: "Aeira Product | Sparcle",
  description:
    "Aeira is the governed data plane behind enterprise search and grounding, from included catalog to federated scale.",
  canonical: "https://sparcle.app/products/aeira.html",
  productName: "Aeira",
  productKicker: "ACL-aware Enterprise Index",
  productHeadline: "Catalog to Federated, same contract and ACL semantics.",
  productIntro:
    "Aeira powers discovery and grounding with a consistent API and authorization model as customers scale from lightweight catalog to high-governance federation.",
  primaryCtaLabel: "Talk to Aeira Team",
  primaryCtaHref: "#contact:Aeira Architecture Discussion",
  secondaryCtaLabel: "Features & Pricing",
  secondaryCtaHref: "/pricing.html#aeira",
  tertiaryCtaLabel: "Learn More",
  tertiaryCtaHref: "/aeira-slides.html",
  tertiaryCtaTarget: "_blank",
  slidesUrl: "/aeira-slides.html",
  highlights: [
    {
      title: "Included Catalog Baseline",
      detail:
        "Every Bolt plan includes Aeira Catalog with 8 core categories and 2 custom categories.",
      icon: "database",
    },
    {
      title: "Stable API Contract",
      detail:
        "Keep one integration contract while upgrading between Catalog, Dynamic, Enhanced, and Federated.",
      icon: "code",
    },
    {
      title: "JWT + ACL Compatibility",
      detail:
        "Consistent authorization semantics across tiers for safer rollouts and fewer integration rewrites.",
      icon: "lock",
    },
    {
      title: "Scale Without Surprises",
      detail:
        "Move from directory-style indexing to larger ingestion and governance profiles with clear guardrails.",
      icon: "scale",
    },
  ],
  faqs: [
    {
      title: "Is Catalog included in all Bolt plans?",
      detail:
        "Yes. Catalog is bundled in all Bolt plans as the baseline data layer.",
    },
    {
      title: "What changes when we upgrade tiers?",
      detail:
        "Mostly scale, governance depth, and operations support. API contract and ACL semantics stay consistent.",
    },
  ],
};

export const boltPricingContent: PricingPageContent = {
  title: "Bolt Pricing | Sparcle",
  description:
    "Bolt pricing for enterprise teams: Absolute, Bundled, and Complete, with included Aeira Catalog in every plan.",
  canonical: "https://sparcle.app/pricing.html",
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
      price: "$10 / seat / month",
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
      price: "$20 / seat / month",
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
      price: "$25 / seat / month",
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
        selfHosted: "$99 / month",
        managed: "$99 / month",
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
        selfHosted: "$499 / month",
        managed: "$499 / month",
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
