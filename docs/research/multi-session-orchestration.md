# Multi-Session Orchestration Research

**Date:** 2026-03-28
**Context:** Improving dx-hub's multi-repo dispatch mechanism
**Branch:** claude/research-session-driver

## Problem Statement

dx-hub needs to coordinate work across multiple repos — each with its own Claude Code session, full plugin access, and independent working directory. Our current implementation uses vscode-automator (AppleScript-based VS Code terminal automation), which is macOS-only.

We researched three approaches:
1. **smux** — tmux pane communication layer
2. **claude-session-driver** — tmux-based session orchestration plugin
3. **Claude Code Agent Teams** — official Anthropic multi-agent feature

---

## 1. smux (ShawnPana/smux)

**What:** A tmux config + `tmux-bridge` CLI for cross-pane agent communication.

**Key facts:**
- Pure shell — bash scripts, no dependencies beyond tmux
- Cross-platform: Linux, macOS, WSL
- Pane communication via `tmux-bridge read/type/keys/message`
- Read guard: must `read` a pane before you can `type` into it
- Named panes with labels for easy targeting

**What it does NOT do:**
- Launch or manage sessions (no lifecycle management)
- Track completion or collect results
- Define tasks/prompts declaratively
- Any orchestration at all — it's purely a communication layer

**Assessment:** Useful building block for cross-pane messaging, but not an orchestrator. Would need significant wrapper code to serve as a dx-hub backend. Its main value is the cross-platform tmux-bridge primitive.

---

## 2. claude-session-driver (obra/claude-session-driver)

**What:** A Claude Code plugin that turns one session into a controller that launches/monitors/communicates with worker sessions via tmux.

**Author:** Jesse Vincent (obra/superpowers ecosystem)
**Version:** 1.0.1 (2026-02-22) | **Stars:** ~66 | **License:** MIT

### Architecture

```
Controller Session (Claude Code CLI)
    │
    ├── launch-worker.sh → tmux new-session + claude --session-id --plugin-dir
    ├── send-prompt.sh   → tmux send-keys (type prompt into worker terminal)
    ├── wait-for-event.sh → polls JSONL events file (0.5s interval)
    ├── converse.sh      → send-prompt + wait-for-stop + read-response
    ├── read-events.sh   → read/filter event stream
    ├── read-turn.sh     → format last turn as markdown
    ├── approve-tool.sh  → write allow/deny for pending tool calls
    └── stop-worker.sh   → graceful shutdown
```

### Communication channels

| Channel | Direction | Mechanism |
|---------|-----------|-----------|
| JSONL events | Worker → Controller | Hooks append to `/tmp/claude-workers/<sid>.events.jsonl` |
| Prompts | Controller → Worker | `tmux send-keys` (literal typing) |
| Tool approval | Bidirectional | `.tool-pending` + `.tool-decision` files |
| Data sharing | Worker ↔ Worker | Regular files on disk (no direct messaging) |

### Lifecycle events (via hooks)

- `session_start` — worker Claude session is alive
- `user_prompt_submit` — prompt was submitted
- `pre_tool_use` — tool call pending (with tool name + input)
- `stop` — Claude finished responding
- `session_end` — session terminated

### Orchestration patterns

1. **Delegate and wait** — single worker, single task
2. **Fan-out** — N workers on independent tasks, wait for all
3. **Pipeline** — chain workers, each builds on prior output (files on disk)
4. **Supervised** — multi-turn conversation with worker via `converse.sh`
5. **Hand-off** — transfer tmux session to a human

### Multi-repo support

Each worker launched with different CWD:
```bash
R1=$("$SCRIPTS/launch-worker.sh" worker-fe ~/repos/frontend)
R2=$("$SCRIPTS/launch-worker.sh" worker-be ~/repos/backend)
```

This is a key strength — workers are fully independent sessions in different directories.

### What's great

- Full Claude Code sessions (can modify files, run builds, commit)
- JSONL event stream is cleaner than screen-scraping
- Tool-call approval gives controller fine-grained oversight
- Multi-repo via `--workdir` per worker
- Simple — all shell scripts, no runtime

### Limitations and risks

| Issue | Severity | Detail |
|-------|----------|--------|
| **Process leak (Issue #9)** | CRITICAL | `emit-event.sh` creates thousands of hanging bash/cat processes via `INPUT=$(cat)`. Exhausts macOS process limit (~5333) in ~30 min. **Unresolved.** |
| Claude Code only | Medium | Requires Claude Code hooks + CLI. No Copilot CLI support. |
| No peer-to-peer | Medium | Workers can't message each other, only controller. |
| `--dangerously-skip-permissions` | Medium | Workers bypass permission dialogs. PreToolUse hook provides alternative gating, but it's all-or-nothing. |
| Small project | Low | 7 commits, 1 maintainer, 66 stars. |
| No auto-retry | Low | Controller must implement retry logic itself. |
| tmux required | Low | No fallback for non-tmux environments. |

### Platform support

- Claude Code CLI: **Yes** (only supported platform)
- Copilot CLI: **No**
- VS Code Chat: **No**
- macOS: Yes | Linux: Yes | Windows: No (tmux)

---

## 3. Claude Code Agent Teams (Official Anthropic)

**What:** Built-in multi-agent coordination where one session (lead) delegates to teammates, each with independent context windows.

**Status:** Experimental (v2.1.32+, ~March 2026)

### How it works

- Lead session creates teammates via `TeamCreate` tool
- Teammates get their own context windows and tool access
- Communication via `SendMessage` (peer-to-peer supported)
- Shared `TaskList` for coordination
- Visual split panes via tmux or iTerm2

### Key differences from session-driver

| Dimension | Agent Teams | session-driver |
|-----------|------------|----------------|
| Communication | Built-in SendMessage + TaskList | JSONL file polling + tmux keystrokes |
| Peer-to-peer | Yes | No (controller/worker only) |
| Multi-repo | Limited (shared project dir) | Yes (per-worker workdir) |
| Tool approval | No granular control | Per-tool-call approve/deny |
| Persistence | Session-scoped, no resume | Workers persist, can re-engage |
| Maturity | Experimental, Anthropic-backed | Community, 1 maintainer |
| Platform | Claude Code only | Claude Code only |

### Critical gap for dx-hub

**Agent Teams teammates share the lead's project directory.** They cannot easily work in separate repos with separate plugin configs. This is a fundamental mismatch with dx-hub's multi-repo model where each repo has its own plugins, config, and working directory.

---

## Comparison Matrix

| Requirement | vscode-automator (current) | smux | session-driver | Agent Teams |
|-------------|---------------------------|------|----------------|-------------|
| Launch sessions in different repos | Yes | No (manual) | Yes | No (shared dir) |
| Inject prompts | Yes (AppleScript) | Yes (tmux-bridge) | Yes (tmux send-keys) | Yes (SendMessage) |
| Monitor completion | No (file-based) | No | Yes (JSONL events) | Yes (built-in) |
| Cross-platform | macOS only | Linux/macOS/WSL | Linux/macOS | Linux/macOS |
| Copilot CLI support | No | N/A | No | No |
| Full plugin access per repo | Yes | Yes (if manual) | Yes | No (shared context) |
| Tool-call oversight | No | No | Yes | No |
| Stability | Stable (simple) | Stable (simple) | Critical bug (Issue #9) | Experimental |
| Complexity to integrate | Medium | High (no orchestration) | Low (plugin install) | Low (built-in) |

---

## Recommendations

### Short-term: Keep vscode-automator + add tmux fallback

Our current approach (vscode-automator for VS Code users) is sound. The main gap is cross-platform support. We should add a **tmux-based dispatch backend** as an alternative for Linux/non-VS-Code users.

This is simpler than adopting session-driver wholesale because:
- session-driver has a critical unresolved bug (process leak)
- Our dispatch needs are simpler (launch + prompt + minimal status)
- We already have the orchestration logic in dx-hub-dispatch

### Medium-term: Adopt session-driver patterns

Once the process leak is fixed, session-driver's JSONL event stream and tool approval patterns are worth adopting:
- Replace file-polling status with JSONL events
- Add tool-call oversight for safety-critical repos
- Use `converse.sh` pattern for supervised multi-turn dispatch

### Long-term: Monitor Agent Teams

Agent Teams is the likely future standard, but its shared-directory limitation is a blocker for multi-repo. When Anthropic adds per-teammate workdir support, it becomes the natural choice.

### Integration approach: Soft-dependency pattern

Use the same pattern dx already uses for superpowers skills:

```markdown
If `claude-session-driver` plugin is installed, use its launch-worker.sh and
JSONL event stream for richer status tracking and tool-call oversight.

**Fallback:** Use direct tmux/vscode-automator dispatch with file-based status.
```

This keeps dx-hub working without session-driver while benefiting from it when available.

---

## Proposed dx-hub Improvements

### 1. Multi-backend dispatch (Priority: High)

Add a dispatch backend abstraction to `dx-hub-dispatch`:

```
dispatch-backend:
  vscode-automator  → macOS + VS Code users (current)
  tmux              → cross-platform fallback (new)
  session-driver    → when plugin installed (future)
  agent-teams       → when Anthropic adds workdir support (future)
```

Config in `.ai/config.yaml`:
```yaml
hub:
  dispatch-backend: auto  # auto-detect best available
  # or: vscode-automator | tmux | session-driver
```

### 2. JSONL event stream (Priority: Medium)

Adopt session-driver's event pattern regardless of backend:
- Each dispatched repo writes events to `state/<ticket-id>/<repo>.events.jsonl`
- Events: `started`, `planning`, `implementing`, `testing`, `blocked`, `done`, `failed`
- `dx-hub-status` reads these instead of simple status.json

### 3. tmux dispatch backend (Priority: High)

New script: `plugins/dx-hub/scripts/tmux-dispatch.sh`
- `tmux new-session -d -s <repo-name> -c <repo-path>`
- `tmux send-keys -t <repo-name> "claude" Enter`
- Sleep + `tmux send-keys -t <repo-name> "<delegation-prompt>" Enter`
- No dependency on vscode-automator or AppleScript

### 4. Backend auto-detection (Priority: Medium)

```
1. If VS Code terminal detected + macOS → vscode-automator
2. If tmux available → tmux
3. If session-driver plugin installed → prefer it over raw tmux
4. Error: no dispatch backend available
```

### 5. Soft-dependency on session-driver (Priority: Low)

When session-driver is installed:
- Use its JSONL event hooks for richer status
- Use tool-call approval for safety-critical operations
- Use `converse.sh` pattern for supervised dispatch

When not installed:
- Fall back to direct tmux + file-based status (current approach)
