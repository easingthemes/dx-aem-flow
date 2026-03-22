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
- `<img src="url" alt="text">` → `![text](url)`
- `<div>` and `<p>` → paragraph breaks
- `<table>` → markdown tables
- Strip all other HTML tags (keep display text from `data-vss-mention` spans)
- Trim excessive whitespace

## Jira Considerations

Jira Server/DC uses wiki markup rather than HTML. Convert wiki markup to markdown for raw-story.md consistency:

- `*bold*` → `**bold**`
- `_italic_` → `*italic*`
- `h1.` through `h6.` → `#` through `######`
- `{code}...{code}` → fenced code blocks
- `[link text|url]` → `[link text](url)`
- `!image.png!` → `![image](image.png)`

Jira Cloud uses ADF (Atlassian Document Format) — the MCP typically returns rendered text. Use as-is if already plain text.
