---
name: aem-editorial-guide
description: Capture editorial guide for a component dialog in AEM — open editor, screenshot dialog, and write editor-friendly authoring guide. Use after /aem-verify or deploying changes to create editorial documentation.
argument-hint: "[component-name] (e.g., hero, card, banner)"
context: fork
agent: aem-editorial-guide-capture
---

**Platform note:** This skill uses `context: fork` + `agent: aem-editorial-guide-capture` for isolated execution. If subagent dispatch is unavailable (e.g., VS Code Chat), you may run inline but AEM MCP tools (`AEM/*`, `chrome-devtools-mcp/*`) must be available. If they are not, inform the user: "AEM demo capture requires AEM and Chrome DevTools MCP servers. Please use Claude Code or Copilot CLI."

## Task

Capture a demo of the AEM component **$ARGUMENTS** — open its dialog in the AEM editor, take a screenshot, and write an editor-friendly authoring guide.

If no component name was provided, check `.ai/specs/*-*/aem-after.md` or `.ai/specs/*-*/aem-before.md` to infer it. If unclear, state what you need and stop.

## Steps

### 1. Find the page and spec directory

Read `.ai/config.yaml` for `aem.author-url` (defaults to `http://localhost:4502`) and `aem.resource-type-pattern`.

Read the most recent `.ai/specs/*-*/aem-after.md` (or `aem-before.md`) to find:
- A page path where the component is authored
- The component name and new/changed fields

If no aem-after.md exists, use AEM MCP tools:
- `mcp__plugin_dx-aem_AEM__searchContent` with fulltext `$ARGUMENTS` under `/content`, limit 5
- Pick the most recently modified page

Also identify the spec directory path for saving output.

### 2. Ensure demo folder exists

Create `<spec-dir>/demo/` if it doesn't exist.

### 3. Open the page in AEM editor

Navigate Chrome to `<author-url>/editor.html<page-path>.html`.

**Check for login redirect:** After navigation, check if the URL contains `/libs/granite/core/content/login.html`. If so, log in:
1. Use `evaluate_script` to fill `#username` and `#password` with AEM credentials (default: `admin`/`admin`)
2. Dispatch `input` events after setting values so Coral UI registers them
3. Use `evaluate_script` to click `#submit-button`
4. Wait for the editor page to load (use `wait_for` with the page title or "Edit", timeout 15 seconds)

Wait for the editor to be ready — use `evaluate_script` to check:
```js
() => {
  return document.querySelector('.editor-GlobalBar') !== null
    && document.querySelector('iframe#ContentFrame') !== null;
}
```
Retry up to 15 seconds (poll every 1 second).

### 4. Open the component dialog

Read the resource type pattern from `.ai/config.yaml` `aem.resource-type-pattern`.

Use `evaluate_script` to find the component and trigger its EDIT action:
```js
() => {
  const editables = Granite.author.editables;
  const target = editables.find(e =>
    e.type && e.type.toLowerCase().includes('$ARGUMENTS')
  );
  if (target) {
    Granite.author.editableHelper.doSelectEditable(target);
    Granite.author.editableHelper.doAction(target, 'EDIT');
    return { found: true, path: target.path };
  }
  return { found: false, available: editables.map(e => e.type).filter(Boolean) };
}
```

If `found: false`, log the available editable types and try matching with the configured resource type pattern.

### 5. Wait for dialog to open

Poll for `coral-dialog` as a direct child of `<body>`:
```js
() => {
  const dialog = document.querySelector('body > coral-dialog[open]');
  if (!dialog) return { open: false };
  const title = dialog.querySelector('coral-dialog-header');
  return { open: true, title: title ? title.textContent.trim() : 'unknown' };
}
```
Retry every 500ms, up to 10 attempts (5 seconds total).

If the dialog doesn't open after retries, take a screenshot of the current state and note the issue.

### 6. Screenshot — relevant part only

**Only screenshot the part relevant to the implementation.** This could be:
- A dialog tab or fieldset that was added/changed — scroll/navigate to that section first
- A section of the published page showing the component's rendered output

If it's not possible to isolate the relevant part, take **one screenshot only**.

**Check if the screenshot file already exists** before saving. Use `Glob` to check for `<spec-dir>/demo/*$ARGUMENTS*.png`:
- If no match: save as `dialog-$ARGUMENTS.png` or `page-$ARGUMENTS.png` (depending on what was captured)
- If exists: increment (`dialog-$ARGUMENTS-2.png`, etc.)

Use `take_screenshot` with:
- `filePath`: `<spec-dir>/demo/<chosen-filename>.png`
- Format: PNG

### 7. Close dialog if open

If a dialog is open, close it:
```js
() => {
  const dialog = document.querySelector('body > coral-dialog[open]');
  if (dialog) {
    const cancel = dialog.querySelector('[coral-close]');
    if (cancel) cancel.click();
  }
  return true;
}
```

### 8. Write the authoring guide

Read `<spec-dir>/implement.md` and `<spec-dir>/aem-after.md` (if they exist) to understand what was added.

Write `<spec-dir>/demo/authoring-guide.md`:

```markdown
# <Component Title> — Authoring Guide

## What Changed

<1-3 sentences explaining what's new in plain English, no code references>

## How to Use

### <Field or Feature Name>

<Plain English description of what this field does and when to use it>

### <Next Field or Feature>

<Description>

## Tips

- <Any conditional visibility: "Enable X to reveal additional fields">
- <Any gotchas: "Leave blank to use the default value">
- <Any recommendations: "Use short titles (under 50 characters) for best display">

## Dialog Screenshot

![Component Dialog](dialog-$ARGUMENTS.png)
```

Keep it **non-technical**:
- No JCR properties, no code paths, no Java class names
- Write for someone who authors pages in AEM, not a developer
- Focus on what they see in the dialog and what each field controls
- Mention any show/hide behavior ("check X to see Y fields")

### 9. Return summary

Return ONLY:
- Screenshot paths saved
- Authoring guide path
- Dialog title as seen in AEM
- Any issues encountered (dialog didn't open, component not found, etc.)
- Spec dir where files were saved

## Examples

1. `/aem-editorial-guide hero` — Opens the hero component dialog in AEM author, captures a screenshot of the dialog, navigates to QA publisher to screenshot the rendered component, and writes `demo/authoring-guide.md` with field descriptions, dialog screenshot, and publisher URL.

2. `/aem-editorial-guide card 2416553` — Captures demo for the card component tied to story #2416553. Finds existing demo page, screenshots the dialog with 3 tabs, takes a rendered screenshot on QA, and saves all artifacts to `.ai/specs/2416553-<slug>/demo/`.

3. `/aem-editorial-guide productlisting` (dialog won't open) — Attempts to open the dialog but the component isn't on the page. Falls back to writing a text-only authoring guide from spec files and dialog XML analysis. Notes "Dialog screenshot unavailable — component not found on demo page" in the guide.

## Troubleshooting

- **"Component not found on demo page"**
  **Cause:** The component hasn't been placed on any editable page, or the page path is wrong.
  **Fix:** Manually add the component to a test page in AEM author, then re-run `/aem-editorial-guide`. The skill will detect the page and capture screenshots.

- **Screenshots are blank or show loading state**
  **Cause:** The page hasn't fully rendered when the screenshot is taken, or the component loads content asynchronously.
  **Fix:** Re-run the skill — it uses a wait-for-render strategy. If the issue persists, the component may require user interaction to display content. The authoring guide will still be generated from dialog analysis.

- **QA publisher URL returns 404**
  **Cause:** The page hasn't been published to QA, or the publisher URL in config is wrong.
  **Fix:** Publish the page in AEM author first, then re-run. Check `aem.publisher-url` in `.ai/config.yaml`. The skill retries for up to 60 seconds waiting for the publisher.
