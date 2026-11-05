# wiki-sample — fictional multi-market wiki

Ground truth for wiki context in `dx-req` research (TODO-258). All content is invented: three fictional markets (Borealis = "ours", Alpinia, Coralia), one content platform ("ours") and two other stacks (storefront, CRM) that live in the same wiki.

It copies the **shape** of a real large-client wiki, not its content:

- **Flat, mixed top level.** Market wikis, platform wikis and one-off topics side by side.
- **Market pages outside their market's parent.** `Borealis-Legal-Disclaimers`, `Alpinia-Sync-History` sit at the root.
- **Market pages inside a platform subtree.** `AEM-Wiki/Coralia-DAM-Rollout` is platform content about one other market.
- **Other stacks with look-alike topics.** Storefront age verification vs the content age gate; CRM contact sync vs the contact form.
- **EN/DE mix and wording gaps.** "UAT" vs "staging", "Testumgebung", "store finder" vs "store locator".

## Files

| File | What it is |
|------|-----------|
| `wiki/` | Pages in the layout of an ADO wiki git clone: `<Page>.md`, a `<Page>/` folder for children, `.order` per level |
| `config.json` | Scope config the pages are classified against: `platform.ours`, `platform.other-stack`, `markets.mine`, `markets.others` (paths + keywords). A proposal, not a shipped schema |
| `expected-map.json` | Ground truth per page: `platform` (`ours` / `other-stack` / `general`) and `market` (`mine` / `other:<name>` / `global`). `override: true` marks pages a subtree-only rule gets wrong |
| `questions.json` | 18 retrieval questions with `relevant` pages, optional `must_not` distractors, and a `kind` (`keyword`, `synonym`, `language`, `cross-market`) |

Page ids are paths under `wiki/` without `.md`.

## Rules for changing it

- `wiki-sample-fixture.test.js` keeps the tree, the map and the questions consistent. Run it after every change.
- Keep the hard cases. Every `kind` needs questions, and at least three `override` pages must stay.
- Do not tune questions to make a retrieval mode look good. If vector search does not beat keyword search here, that is the result.
- No real client, market or product names, ever. This repo is public.
