#!/usr/bin/env node
// Reads summary.md files from writing-ste runs and prints readability numbers.
// The eval graders give pass/fail per run; this gives the size of the difference.
// Usage: node measure.js <file>...   (zero dependencies)
'use strict';
const fs = require('fs');

const FORMAL = /\b(utili[sz](e|es|ed|ing|ation)|initiat(e|es|ed|ing)|prior to|leverag(e|es|ed|ing)|facilitat(e|es|ed|ing)|in order to|subsequently|in the event that|by means of|commenc(e|es|ed|ing))\b/gi;
// Rough passive: a form of "be", an optional adverb, then a past participle.
const PASSIVE = /\b(is|are|was|were|be|been|being)\s+(\w+ly\s+)?(\w+ed|built|done|made|shown|given|kept|set|sent|run|written|taken|seen)\b/gi;

function sentences(text) {
  return text
    .replace(/```[\s\S]*?```/g, ' ')          // drop code blocks
    .split('\n')
    .map((l) => l.replace(/^\s*([-*+]|\d+\.|#+|\|)\s*/, '').trim())
    .filter((l) => l && !/^[-|: ]+$/.test(l)) // drop blank and table rule lines
    .flatMap((l) => l.split(/(?<=[.!?;])\s+/))
    .map((s) => s.split(/\s+/).filter((w) => /[A-Za-z0-9`]/.test(w)).length)
    .filter((n) => n > 0);
}

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('usage: node measure.js <summary.md>...');
  process.exit(2);
}
console.log(['file', 'words', 'sentences', 'avg', 'max', 'over25', 'passive', 'formal'].join('\t'));
for (const f of files) {
  const text = fs.readFileSync(f, 'utf8');
  const lens = sentences(text);
  const words = lens.reduce((a, b) => a + b, 0);
  console.log([
    f,
    words,
    lens.length,
    (words / Math.max(lens.length, 1)).toFixed(1),
    Math.max(0, ...lens),
    lens.filter((n) => n > 25).length,
    (text.match(PASSIVE) || []).length,
    (text.match(FORMAL) || []).length,
  ].join('\t'));
}
