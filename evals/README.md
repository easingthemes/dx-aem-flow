# Skill evals (waza)

Regression tests for skills in this repo, built on [microsoft/waza](https://github.com/microsoft/waza).

## Why

Skills are pure markdown — there's no traditional test suite. Waza runs each skill against a model, captures the output and tool calls, and grades them with a configurable mix of graders (regex, Python assertions, action-sequence, behavior). CI uses the `mock` executor so PRs run free and offline.

## Layout

```
evals/
├── README.md                    # this file
├── waza.yaml                    # waza project config
└── <skill-name>/
    ├── eval.yaml                # graders + metric weights
    ├── tasks/*.yaml             # one task file per scenario
    └── fixtures/                # canned config / project files
```

## Running locally

```bash
# Install (one-time)
curl -fsSL https://raw.githubusercontent.com/microsoft/waza/main/install.sh | bash

# From repo root
waza run evals/dx-ticket-analyze/eval.yaml --executor mock
```

For live runs against a real model, switch to `--executor copilot-sdk` (requires a GitHub token). Cost estimate for `dx-ticket-analyze` (Haiku 4.5, 6 tasks × 3 trials): **~$0.50 per full live run**.

## Skill resolution

Waza expects `skill: <name>` in `eval.yaml` to resolve to a `SKILL.md`. Our skills live at `plugins/<plugin>/skills/<name>/SKILL.md`. The `waza.yaml` `skill_paths` list points waza at all four plugin skill dirs.

## Adding a new eval

1. `mkdir -p evals/<skill-name>/{tasks,fixtures}`
2. Copy `evals/dx-ticket-analyze/eval.yaml` as a template
3. Add task files under `tasks/` — one per scenario you want covered
4. Run `waza run evals/<skill-name>/eval.yaml --executor mock`
