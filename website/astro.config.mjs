import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import tailwind from '@astrojs/tailwind';
import icon from 'astro-icon';
export default defineConfig({
    integrations: [mdx(), tailwind(), icon()],
    site: 'https://easingthemes.github.io',
    base: '/dx-aem-flow',
    redirects: {
        '/local-workflow/': '/usage/local/',
        '/figma/': '/usage/figma/',
        '/bug-flow/': '/usage/bug-flow/',
        '/aem/': '/usage/aem/',
        '/ado/': '/usage/ado/',
        '/automation/': '/architecture/automation/',
        '/architecture/': '/architecture/overview/'
    },
});