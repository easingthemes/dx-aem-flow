import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import tailwind from '@astrojs/tailwind';
import icon from 'astro-icon';

export default defineConfig({
  integrations: [mdx(), tailwind(), icon()],
  site: 'https://easingthemes.github.io',
  base: '/dx-aem-flow',
  redirects: {
    '/local-workflow/': '/workflows/local/',
    '/figma/': '/workflows/figma/',
    '/bug-flow/': '/workflows/bug-flow/',
    '/aem/': '/workflows/aem/',
    '/ado/': '/workflows/ado/',
    '/automation/': '/architecture/automation/',
    '/architecture/': '/architecture/overview/',
    '/costs/': '/overview/',
    '/demo-guide/': '/demo/guide/',
    '/demo-short/': '/demo/short/',
    '/demo-long/': '/demo/long/',
    '/figma-demo/': '/demo/figma/',
  },
});
