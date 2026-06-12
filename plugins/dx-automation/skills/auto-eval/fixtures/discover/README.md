# Discovery eval fixtures (`--agent discover`)

Canonical fixtures for the `dx-discover-repos` cascade (KAI-HUB). At runtime the
eval framework reads them from `.ai/automation/eval/fixtures/discover/`; these are
the seed copies shipped with the plugin. All names are anonymized (no customer data).

## Fixture shape

```json
{
  "name": "explicit-two-repos",
  "agent": "discover",
  "tier": 0,
  "description": "human typed 'repos: a, b' after the @kai tag",
  "registry_aliases": ["brand-one", "brand-two", "platform-core", "aem-platform-core"],
  "input": { "kind": "comment", "text": "@kai-simple repos: brand-one, platform-core ..." },
  "expected_aliases": ["brand-one", "platform-core"]
}
```

`input.kind` is one of: `comment` (tier 0), `simple-block` (tier 1),
`crossrepo-table` (tier 2), `story` (tier 3).

## Scoring — alias-set match

A fixture **passes** when the discovery output's set of `alias` values equals
`expected_aliases` (order-independent, exact set). Formally:

```
sort(unique(output[].alias)) == sort(unique(expected_aliases))
```

- **Tiers 0/1/2 are deterministic** — `parse-explicit-repos.sh`,
  `route-targets.sh`, `parse-crossrepo-table.sh` (in `dx-hub`) produce the set
  offline, no LLM. These run in CI and must pass exactly. (They are also covered
  by `dx-hub/skills/dx-discover-repos/tests/run-tests.sh`.)
- **Tier 3 is LLM inference** — the `04-llm-inference` fixture documents the
  expected alias set; scoring tolerates it as a tier-2-style match but the result
  depends on the model. Treat a tier-3 miss as a prompt-tuning signal, not a hard
  gate.
