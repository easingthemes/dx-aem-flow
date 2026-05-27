#!/usr/bin/env node
// Replays an authoring-diff.json in reverse order, writing the "before"
// value back to each JCR path. Uses AEM HTTP API directly (POST to the
// node path with the property as a form field).
//
// Required env: AEM_QA_URL, AEM_QA_USER, AEM_QA_PASSWORD
// Exits non-zero if any revert fails.

const fs = require('fs');

const diffPath = process.argv[2];
if (!diffPath) {
  console.error('usage: aem-revert.js <authoring-diff.json>');
  process.exit(2);
}

const { AEM_QA_URL, AEM_QA_USER, AEM_QA_PASSWORD } = process.env;
if (!AEM_QA_URL || !AEM_QA_USER || !AEM_QA_PASSWORD) {
  console.error('ERROR: AEM_QA_URL, AEM_QA_USER, AEM_QA_PASSWORD env vars required');
  process.exit(2);
}

let diff;
try {
  diff = JSON.parse(fs.readFileSync(diffPath, 'utf8'));
} catch (err) {
  console.error(`ERROR: failed to read/parse ${diffPath}: ${err.message}`);
  process.exit(2);
}

const writes = (diff.writes || []).filter((w) => w && w.applied && w['jcr-path'] && w.property).reverse();

if (writes.length === 0) {
  console.error('No applied writes to revert.');
  process.exit(0);
}

const auth = Buffer.from(`${AEM_QA_USER}:${AEM_QA_PASSWORD}`).toString('base64');
let failures = 0;

async function revertOne(w) {
  const url = `${AEM_QA_URL.replace(/\/$/, '')}${w['jcr-path']}`;
  const body = new URLSearchParams();
  body.set(w.property, w.before ?? '');
  if ((w.before ?? '') === '') body.set(`${w.property}@Delete`, 'true');

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: body.toString(),
  });
  if (!res.ok) {
    console.error(`FAIL ${w['jcr-path']} (${w.property}): HTTP ${res.status}`);
    return false;
  }
  console.error(`OK ${w['jcr-path']} (${w.property}) <- "${w.before}"`);
  return true;
}

(async () => {
  for (const w of writes) {
    const ok = await revertOne(w);
    if (!ok) failures++;
  }
  process.exit(failures > 0 ? 1 : 0);
})();
