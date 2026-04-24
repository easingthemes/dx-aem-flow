#!/usr/bin/env node
// One-shot: transform the interactive workflow-diagram HTML into 3 scoped files
// (styles.css, body.html, script.js) ready to be imported by the Astro page
// via Vite's `?raw` suffix. Run once; outputs land under
// src/pages/learn/_workflow-diagram/ (underscore prefix = excluded from routes).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');
const srcHtml = path.join(repoRoot, 'claude-code-agentic-workflow.html');
const outDir = path.join(__dirname, '..', 'src', 'pages', 'learn', '_workflow-diagram');

if (!fs.existsSync(srcHtml)) {
  console.error(`Source HTML not found at ${srcHtml}`);
  process.exit(1);
}

const raw = fs.readFileSync(srcHtml, 'utf-8');

const styleMatch = raw.match(/<style>([\s\S]*?)<\/style>/);
const bodyMatch = raw.match(/<body[^>]*>([\s\S]*?)<\/body>/);
const rawStyles = styleMatch?.[1] ?? '';
const rawBody = bodyMatch?.[1] ?? '';

const scriptSplit = rawBody.match(/^([\s\S]*?)<script>([\s\S]*?)<\/script>([\s\S]*)$/);
const bodyHtml = (scriptSplit?.[1] ?? rawBody).trim();
const rawScript = scriptSplit?.[2] ?? '';

// ---- CSS transform ----
// Keep `:root` untouched so getComputedStyle(document.documentElement) still works.
// Scope the 4 bare element selectors and the `*` universal rule to `.wd-scope`.
// Rewrite `body.no-diagram` → `.wd-scope.no-diagram` (class is toggled by JS).
// Widen the internal `.wrap` from 880px → 1440px so it fills the docs content column.
const scopedStyles = rawStyles
  .replace(/(^|\n)(\s*)\*\s*\{/g, '$1$2.wd-scope, .wd-scope * {')
  .replace(/(^|\n)(\s*)body\.no-diagram\b/g, '$1$2.wd-scope.no-diagram')
  .replace(/(^|\n)(\s*)body\s*\{/g, '$1$2.wd-scope {')
  .replace(/(^|\n)(\s*)header\s*\{/g, '$1$2.wd-scope > .wrap > header {')
  .replace(/(^|\n)(\s*)h1\s*\{/g, '$1$2.wd-scope h1 {')
  .replace(/(^|\n)(\s*)footer\s*\{/g, '$1$2.wd-scope > .wrap > footer {')
  .replace(/\.wrap\s*\{\s*max-width:\s*880px/, '.wrap { max-width: 1440px')
  .trim();

// ---- JS transform ----
// The class `no-diagram` must toggle on the scope element, not document.body,
// because CSS rules now match `.wd-scope.no-diagram` (not `body.no-diagram`).
// Wrap whole script in an IIFE that resolves the scope element once.
const scopedScript = rawScript.replace(
  /document\.body\.classList\.toggle\(\s*'no-diagram'/g,
  "document.querySelector('.wd-scope').classList.toggle('no-diagram'",
).trim();

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'styles.css'), scopedStyles + '\n');
fs.writeFileSync(path.join(outDir, 'body.html'), bodyHtml + '\n');
fs.writeFileSync(path.join(outDir, 'script.js'), scopedScript + '\n');

const bytes = (p) => fs.statSync(p).size;
console.log(`✓ Wrote ${outDir}/`);
console.log(`  styles.css  ${bytes(path.join(outDir, 'styles.css'))} bytes`);
console.log(`  body.html   ${bytes(path.join(outDir, 'body.html'))} bytes`);
console.log(`  script.js   ${bytes(path.join(outDir, 'script.js'))} bytes`);
