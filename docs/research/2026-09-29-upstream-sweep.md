# Upstream + best-practice sweep — 2026-09-29

Window: 2026-07-29 → 2026-09-29. Three parallel research lanes (Claude Code, Copilot CLI,
general best practices), each deduped against `docs/todo/TODO.md` (#1–#220).
Delta to [2026-09-19-platform-state-sweep.md](2026-09-19-platform-state-sweep.md).

## Versions

| Dependency | Last intaken | Now | Date |
|---|---|---|---|
| Claude Code | v2.1.278 | **v2.1.285** | 2026-09-29 |
| Copilot CLI | v1.0.86 / 1.0.87-0 | **v1.0.89** | 2026-09-28 |
| `@azure-devops/mcp` | v2.10.0 | v2.10.0 (nightly `2.10.0-nightly.20260928`) | 2026-09-09 |
| `@playwright/mcp` | 0.0.75 (our pin) | 0.0.83 | 2026-09-28 |
| VS Code | — | 1.139 (nothing for agents/skills/hooks) | 2026-09-23 |

Models: Claude Opus 5.5 (2026-09-22) and Sonnet 5.5 (2026-09-28) are the new Claude Code defaults.
Copilot retires GPT-5.5/5.4/5.4 mini/5 mini, Grok 4.5, Gemini 3.7 Flash on 2026-10-19.

## Verdict

Current on the platform features, behind on execution. Biggest finding is not upstream:
webhook payload text is expanded into bash in two pipelines (#231), so a normal comment with an
apostrophe or backticks breaks the step. **Threat model (decided 2026-09-29):** every ADO user is
trusted and anyone may trigger an agent by comment — no commenter allowlist. #231 is robustness,
#232 is only the external-content rule for text that did not come from ADO users.

## New TODOs

| # | Item | Prio | Lane |
|---|---|---|---|
| 221 | AGENTS.md Bedrock/Vertex/Foundry caveat now false | High | CC |
| 222 | Re-verify tier strategy vs Opus 5.5 / Sonnet 5.5 | High | CC |
| 223 | Dangerous-`rm` prompt can stall bypass-mode pipelines | Medium | CC |
| 224 | Managed model/provider allowlists | Medium | CC |
| 225 | `/doctor prompt-audit` for #113 | Medium | CC |
| 226 | Small v2.1.280–285 notes for existing items | Low | CC |
| 227 | Copilot native `.claude/rules`; env var may never have worked | High | Copilot |
| 228 | Tier Copilot agents (`model`, `reasoning-effort`) | Medium | Copilot |
| 229 | v1.0.87–89 notes, re-anchor re-test to v1.0.89 | Low | Copilot |
| 230 | Tips use retiring Copilot models | Low | Copilot |
| 231 | Comment text breaks pipeline scripts (unquoted payload) | Medium | Practice |
| 232 | External-content rule in 3 writing coordinators (no allowlist) | Low | Practice |
| 233 | Pin + `-d` scope ADO MCP in pipelines | Medium | Practice |
| 234 | Bump Playwright MCP, disable WebMCP | Medium | Practice |
| 235 | Remote MCP endpoints (ADO, Adobe AEM) | Low | Practice |
| 236 | Plugin4Shell (watch) | Low | Practice |

## Already tracked (hits only noted)

#180 plugin validate, #199 userConfig, #200 headless flags, #201 managed MCP, #205 alwaysLoad,
#206/#208 evals, #209 MCP startup wait, #213 allowed-tools (now ignored under
`allowManagedPermissionRulesOnly`, v2.1.282/284), #214 claude.ai sync, #198 ADO tool names
(also in `ado-cli-simple.yml` `ALLOWED_TOOLS`), #119/#128 wide pipeline tool lists, #216/#217/#219.

Upstream Copilot bugs copilot-cli#4708, #4886, #4545 still open — #19–#22 stay blocked.
ADO MCP v2.10.0 `[UNTRUSTED ... CONTENT]` wrapping already handled in `fetch-raw-story.js`.

## Sources

- https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md
- https://www.anthropic.com/claude-opus-5-5
- https://raw.githubusercontent.com/github/copilot-cli/main/changelog.md
- https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions
- https://github.blog/changelog/2026-09-18-upcoming-deprecation-of-selected-github-copilot-models-in-mid-october
- https://learn.microsoft.com/en-us/azure/devops/pipelines/security/inputs
- https://github.com/anthropics/claude-code-action/blob/main/docs/security.md
- https://github.com/microsoft/azure-devops-mcp
- https://github.com/microsoft/playwright-mcp/releases
- https://devblogs.microsoft.com/devops/azure-devops-remote-mcp-server-ga/
- https://experienceleague.adobe.com/en/docs/experience-manager-cloud-service/content/ai-in-aem/mcp-support/using-mcp-with-aem-as-a-cloud-service
- https://thehackernews.com/2026/09/plugin4shell-lets-repository-owners.html
