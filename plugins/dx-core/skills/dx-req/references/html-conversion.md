# HTML to Markdown Conversion Rules

This file contains the detailed HTML-to-markdown conversion rules for ADO content used by Phase 1 of `/dx-req`.

## Conversion Rules

ADO fields return HTML. When converting:

- `<br>` and `<br/>` → newlines
- `<b>`/`<strong>` → `**bold**`
- `<i>`/`<em>` → `*italic*`
- `<ul>/<li>` → markdown bullet lists
- `<ol>/<li>` → numbered lists
- `<a href="url">text</a>` → `[text](url)`
- `<img src="url" alt="text">` → `![text](url)` — BUT see "Image URL rewriting" below
- `<div>` and `<p>` → paragraph breaks
- `<table>` → markdown tables
- Strip all other HTML tags (keep display text from `data-vss-mention` spans)
- Trim excessive whitespace

## Image URL Rewriting (ADO)

ADO inline images use URLs like `https://{org}/{proj}/_apis/wit/attachments/{GUID}?fileName=image.png`. Those URLs are not directly fetchable without an authenticated session, so the bare `![](…)` markdown produced by the rule above would be unusable for a reader (human or AI) reviewing `raw-story.md` later.

Phase 1 step 8 downloads these images to `$SPEC_DIR/images/`. When converting description / acceptance criteria / other HTML fields, extract the GUID from each `<img src>` (pattern: `_apis/wit/attachments/([0-9a-fA-F-]{36})`), look it up in the GUID→local-path map built at step 8d, and rewrite the src to the relative local path:

- Input: `<img src="https://{org}/{proj}/_apis/wit/attachments/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee?fileName=image.png" alt="Image">`
- Output: `![Image](./images/description-1-aaaaaaaa.png)`

If a GUID appears in the HTML but isn't in the map (download failed, non-image file, size-skipped), leave the original URL in the markdown and add `<!-- image not downloaded -->` so later phases know the text references something they can't inspect.

## Jira Considerations

Jira Server/DC uses wiki markup rather than HTML. Convert wiki markup to markdown for raw-story.md consistency:

- `*bold*` → `**bold**`
- `_italic_` → `*italic*`
- `h1.` through `h6.` → `#` through `######`
- `{code}...{code}` → fenced code blocks
- `[link text|url]` → `[link text](url)`
- `!image.png!` → `![image](image.png)`

Jira Cloud uses ADF (Atlassian Document Format) — the MCP typically returns rendered text. Use as-is if already plain text.
