# Test Plan — Shared Reference

Test targets and verification used by both local and remote plans.

## Test Work Items

Before testing, identify or create in ADO:

```
TEST_USER_STORY_ID=       # User Story with acceptance criteria + Figma URL
TEST_BUG_ID=              # Bug with repro steps + AEM URL
TEST_PR_ID=               # PR with open comment threads
TEST_PR_REPO=             # Repo name for PR tests
```

## Verification

| Check | How |
|-------|-----|
| ADO comment posted | Open work item → Comments tab |
| PR review posted | Open PR → check review threads + vote |
| Branch + PR created | ADO Repos → Branches / Pull Requests |
| Bug tickets created | ADO Boards → linked child bugs |
| Wiki page created | ADO Wiki → search agent output |
| No regressions | Re-run `/auto-eval --all` after any prompt/rule change |

## Policy Gates (all agents)

Every pipeline agent enforces before acting:

- **Capability gate** — action must be in `allowed_actions` list
- **Rate limit** — under daily cap per agent
- **Token budget** — under monthly cap
- **Push policy** (PR Answer only) — `agree-will-fix` + unique old code + lint passes + scanner risk low
