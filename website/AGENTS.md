# Agent Maintenance Guide

Instructions for AI agents maintaining this Astro + MDX + Tailwind documentation site.

## Tech Stack

- **Astro 5.x** — static site generator, zero JS shipped to browser
- **MDX** — markdown with JSX component support
- **Tailwind CSS 3.x** — utility-first CSS with `@tailwindcss/typography`
- **astro-icon** — Iconify icons (Material Design Icons: `@iconify-json/mdi`)

## Navigation Architecture

**Top nav** (9 items in `BaseLayout.astro`) selects the category. Each points to the first page of its section.

**Sidebar** (`SidebarLayout.astro`) shows page list for the current section. Config is in the `sidebars` object inside `SidebarLayout.astro`.

**Sections with sidebar:** Learn, Workflows, Reference, Architecture, Contributing, Setup
**Sections without sidebar (full-width):** Home, Overview, Demo

### Adding a page to a section

1. Create `src/pages/<section>/my-page.mdx` with frontmatter:
   ```yaml
   layout: ../../layouts/SidebarLayout.astro
   title: My Page
   sidebar: section-name
   ```
2. Add an entry to the `sidebars[section-name]` array in `SidebarLayout.astro`

## Key Files

| File | Purpose |
|------|---------|
| `src/layouts/BaseLayout.astro` | Shell: top nav (9 items), footer, side badge, mobile drawer |
| `src/layouts/SidebarLayout.astro` | Wraps BaseLayout, adds left sidebar from `sidebars` config |
| `src/content.config.ts` | Schema for TLDR tips content collection |
| `tailwind.config.mjs` | Brand colors, fonts, typography plugin |
| `astro.config.mjs` | Integrations + redirects for old URLs |
| `src/styles/global.css` | Tailwind directives, global code/link styles, print styles |

## Components

All in `src/components/`. Props typed in frontmatter fence.

| Component | Props | Notes |
|-----------|-------|-------|
| `PageHero` | `title`, `subtitle?` | Dark gradient banner. One per page. |
| `Section` | `bg?: 'default'\|'alt'\|'primary'` | Content wrapper with max-width. |
| `SectionHeading` | `badge?`, `badgeColor?`, `title`, `subtitle?`, `bg?` | Section header with badge pill. |
| `ContentCard` | `icon?`, `iconColor?`, `title?`, `tags?`, `horizontal?` | Card. Icon = `mdi:*` string. |
| `PipelineBlock` | `label?`, `command?`, `description?`, `steps?` | Flow diagram with arrows. |
| `HighlightBox` | `severity?`, `title?` | Tinted callout. No border, no icon. |
| `CommandBlock` | `label?` | Code block with cyan left accent. |

### Icon Colors (ContentCard `iconColor` prop)

| Semantic | Class |
|----------|-------|
| primary | `bg-brand-700` |
| secondary | `bg-cyan` |
| success | `bg-emerald-600` |
| warning | `bg-amber-500` |
| error | `bg-red-500` |
| info | `bg-cyan-dark` |

## Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `brand-900` | `#000048` | Hero, footer |
| `brand-700` | `#2d308d` | Nav, headings, primary accent |
| `brand-100` | `#f5f5fa` | Alt section background |
| `cyan` | `#36C0CF` | Links, interactive |
| `cyan-dark` | `#1E728C` | Info accent |

Text: primary `#1a1a2e`, secondary `#4a4a5a`, muted `#7a7a8a`

## MDX Gotchas — WILL BREAK BUILD

1. **Tilde `~`** — `~text~` = strikethrough. Use `≈` for approximate values, `{"~"}` for paths.
2. **Asterisk `*`** — `*text*` = emphasis. Use `&#42;` inside HTML elements.
3. **Double underscore `__`** — `__text__` = bold. Wrap in JSX: `{"mcp__ado__tool"}` inside `<code>`.
4. **Curly braces `{}`** — JSX expressions. Wrap JSON in: `{'{"key":"value"}'}`
5. **Angle brackets `<>`** — Use `&lt;`/`&gt;` in text (not in JSX tags).

## Design Constraints

- **No special borders** on HighlightBox — just tinted background
- **Full colored border** on architecture layer cards (all sides)
- **Font sizes**: h1=2.5rem, h2=2rem, h3=1.1rem, body=0.95rem
- **Fonts**: Open Sans (400-800) + JetBrains Mono (400,600) via Google Fonts
- **Border radius**: `rounded` (4px) on cards, badges

## Redirects

Old URLs redirect to new locations (configured in `astro.config.mjs`). When moving pages, always add a redirect for the old URL.

## Content Source

Plugin docs at `dx-aem-flow/dx/docs/` are the source of truth for reference content. The website should be kept in sync when plugin docs change.

The original React + MUI version is at `internal/presentations/web copy/` for visual reference only.
