# Pre-Flight Validation Standard

Every skill and agent SHOULD validate prerequisites before starting work. Fail fast with clear instructions.

## Phase 0: Pre-Flight Checks

### 1. Shell Dependencies

For skills that invoke CLI tools (git, npm, mvn, zip, docker):

```
Check: `command -v <tool>` for every required CLI tool
Pass: Continue
Fail: STOP with "Required tool '<name>' not found. Install: <instructions>"
```

### 2. MCP Tool Availability

**Pre-loaded tools** (agent has explicit `tools:` in frontmatter):
- Tools are directly available. Call them directly.
- Do NOT use ToolSearch — it only finds deferred tools and returns nothing for pre-loaded ones.
- If a direct call fails with "tool not found", THEN try ToolSearch as fallback.

**Deferred tools** (skill runs inline, no agent `tools:` list):
- Use ToolSearch to discover tools before calling them.
- Pattern: `ToolSearch("+AEM")` or `ToolSearch("+chrome-devtools")`

**Decision rule:** Check your agent frontmatter. If `tools:` lists MCP tools → pre-loaded. If not → deferred.

### 3. Configuration Values

```
Check: .ai/config.yaml exists and has required keys for this skill
Required for all skills: scm.provider, scm.base-branch
Required for ADO skills: scm.org, scm.project, scm.repo-id
Required for AEM skills: aem.url, aem.component-path
Fail: STOP with "Missing config key '<key>'. Run /dx-init to configure."
```

### 4. Spec Directory

```
Check: .ai/specs/<id>-<slug>/ exists with required input files
Required input varies by skill (check SKILL.md header for prerequisites)
Fail: STOP with "Run <prerequisite skill> first. Expected: <file>"
```

### 5. Branch Safety

```
Check: Current branch is feature/* or bugfix/* (not main/master/development/develop)
Fail: STOP with "Cannot execute on protected branch. Create a feature branch first."
```
(Note: This is also enforced by the PreToolUse branch-guard hook for git commits.)
