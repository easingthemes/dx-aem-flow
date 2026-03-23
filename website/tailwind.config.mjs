import typography from '@tailwindcss/typography';
/** @type {import('tailwindcss').Config} */
export default {
    content: ['./src/**/*.{astro,html,js,jsx,md,mdx,ts,tsx}'],
    theme: {
        extend: {
            colors: {
                brand: {
                    900: '#000048',   // deep navy — hero, footer
                    700: '#2d308d',   // primary indigo — nav, headings, accent
                    500: '#4a4db5',   // lighter indigo
                    300: '#9798c8',   // soft purple — hover, secondary
                    100: '#f5f5fa',   // background alt
                },
                cyan: {
                    DEFAULT: '#36C0CF', // links, interactive
                    dark: '#1E728C',    // info accent
                    light: '#6dd8e3',
                },
            },
            fontFamily: {
                sans: ["'Open Sans'", 'system-ui', '-apple-system', 'sans-serif'],
                mono: ["'JetBrains Mono'", "'Fira Code'", 'monospace'],
            },
            typography: ({ theme }) => ({
                DEFAULT: {
                    css: {
                        '--tw-prose-body': theme('colors.gray.700'),
                        '--tw-prose-headings': theme('colors.brand.900'),
                        '--tw-prose-links': theme('colors.brand.700'),
                        '--tw-prose-code': theme('colors.brand.700'),
                        code: {
                            backgroundColor: 'rgba(45,48,141,0.06)',
                            padding: '0.15rem 0.4rem',
                            borderRadius: '0.125rem',
                            fontWeight: '400',
                            fontSize: '0.85em',
                        },
                        'code::before': { content: '""' },
                        'code::after': { content: '""' },
                        a: {
                            textDecoration: 'none',
                            '&:hover': { color: theme('colors.cyan.DEFAULT') },
                        },
                        maxWidth: 'none',
                    },
                },
            }),
        },
    },
    plugins: [typography],
};
Colla