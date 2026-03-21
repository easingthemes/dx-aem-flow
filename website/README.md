# KAI Documentation Site

Static documentation site built with [Astro](https://astro.build/) + MDX + Tailwind CSS.

## Prerequisites

- Node.js 18+
- npm

## Quick Start

```bash
npm install
npm run dev
```

Open http://localhost:4321/

## Commands

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server with hot reload |
| `npm run build` | Build static site to `dist/` |
| `npm run preview` | Preview built site locally |

## Deploy to GitHub Pages

```bash
npm run build
```

Update `site` and `base` in `astro.config.mjs` to match your GitHub Pages URL.

## Site Structure

### Navigation

**Top nav** (9 items) selects the category. **Sidebar** appears within sections that have multiple pages. Full-width sections (Home, Overview, Demo) have no sidebar.

```
Home | Overview | Learn | Workflows | Reference | Architecture | Contributing | Setup | Demo
```

### Directories

```
src/
├── components/           # Reusable Astro components
├── content/tips/         # TLDR tips (content collection)
├── layouts/
│   ├── BaseLayout.astro  # Shell: nav, footer, side badge
│   └── SidebarLayout.astro # Wraps BaseLayout + left sidebar
├── pages/
│   ├── index.mdx         # Home (full-width)
│   ├── overview.mdx      # Overview + Costs (full-width)
│   ├── learn/            # AI Crash Course (sidebar: learn)
│   ├── workflows/        # Workflow pages (sidebar: workflows)
│   ├── reference/        # Catalogs & schemas (sidebar: reference)
│   ├── architecture/     # Architecture deep-dives (sidebar: architecture)
│   ├── contributing/     # Authoring guides (sidebar: contributing)
│   ├── setup/            # Installation guides (sidebar: setup)
│   └── demo/             # Demo scripts (full-width)
├── styles/global.css
public/
├── images/
└── videos/
```

## Adding a New Page

1. Create `src/pages/<section>/my-page.mdx`:

```mdx
---
layout: ../../layouts/SidebarLayout.astro
title: My Page
sidebar: section-name
---

import PageHero from '../../components/PageHero.astro';
import Section from '../../components/Section.astro';

<PageHero title="My Page" subtitle="Description." />

<Section>
  Content here.
</Section>
```

2. Add entry to the `sidebars` config in `src/layouts/SidebarLayout.astro`.

For full-width pages (no sidebar), use `BaseLayout.astro` instead and omit the `sidebar` field.

## Adding a TLDR Tip

Drop a `.md` file in `src/content/tips/`. It auto-appears on the TLDR page.

## Icons

Uses [astro-icon](https://github.com/natemoo-re/astro-icon) with Material Design Icons.
Browse: https://icon-sets.iconify.design/mdi/
Usage: `icon="mdi:rocket-launch"`
