// @ts-check
import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  site: 'https://sparcle.app',
  redirects: {
    // Bolt Apps canonical home is /docs/utilities (admin + user tiers,
    // shared template, single trust contract). The earlier /apps and
    // /apps/trust URLs are kept as 301s so any links that landed after
    // the brief publish of those pages still resolve.
    '/apps': '/docs/utilities',
    '/apps/trust': '/docs/utilities#trust',
    // Trial flow was retired when Bolt became free for individuals.
    // Old links to the trial-quickstart doc redirect to the renamed
    // /docs/quickstart so any indexed pages keep working.
    '/docs/trial-quickstart': '/docs/quickstart',
  },
});
