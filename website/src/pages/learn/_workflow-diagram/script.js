(function () {
  const W = 720;
  const CX = 360;
  const BOX_W = 320;
  const BOX_X = CX - BOX_W / 2;
  const ARROW_LEN = 26;

  // colors via CSS vars resolved at draw time
  function cssVar(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  function defs() {
    return `
      <defs>
        <marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M 0 0 L 10 5 L 0 10 z" fill="${cssVar('--text-300')}"/>
        </marker>
        <marker id="arrLoop" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M 0 0 L 10 5 L 0 10 z" fill="${cssVar('--model-stroke')}"/>
        </marker>
      </defs>`;
  }

  function styleFor(kind) {
    if (kind === 'hook')    return { fill: cssVar('--hook-fill'),    stroke: cssVar('--hook-stroke') };
    if (kind === 'model')   return { fill: cssVar('--model-fill'),   stroke: cssVar('--model-stroke') };
    if (kind === 'context') return { fill: cssVar('--context-fill'), stroke: cssVar('--context-stroke') };
    if (kind === 'tool')    return { fill: cssVar('--tool-fill'),    stroke: cssVar('--tool-stroke') };
    return { fill: cssVar('--step-fill'), stroke: cssVar('--step-stroke') };
  }

  function box(y, h, kind, title, subtitle, bullets) {
    const s = styleFor(kind);
    let body = '';
    body += `<rect x="${BOX_X}" y="${y}" width="${BOX_W}" height="${h}" rx="8" fill="${s.fill}" stroke="${s.stroke}"/>`;
    body += `<text x="${CX}" y="${y + 22}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">${escapeXml(title)}</text>`;
    if (subtitle) {
      body += `<text x="${CX}" y="${y + 39}" text-anchor="middle" font-size="11" fill="${cssVar('--text-200')}">${escapeXml(subtitle)}</text>`;
    }
    if (bullets && bullets.length) {
      let by = y + (subtitle ? 56 : 42);
      for (const b of bullets) {
        body += `<text x="${BOX_X + 16}" y="${by}" font-size="11" fill="${cssVar('--text-200')}">${escapeXml(b)}</text>`;
        by += 18;
      }
    }
    return body;
  }

  function diamond(y, label, sublabel) {
    const s = styleFor('model');
    const w = 200, h = 110;
    const top = y, bottom = y + h, left = CX - w/2, right = CX + w/2, midY = y + h/2;
    let body = `<polygon points="${CX},${top} ${right},${midY} ${CX},${bottom} ${left},${midY}" fill="${s.fill}" stroke="${s.stroke}"/>`;
    body += `<text x="${CX}" y="${midY - 4}" text-anchor="middle" font-size="13" font-weight="600" fill="${cssVar('--text-100')}">${escapeXml(label)}</text>`;
    if (sublabel) body += `<text x="${CX}" y="${midY + 14}" text-anchor="middle" font-size="10" fill="${cssVar('--text-200')}">${escapeXml(sublabel)}</text>`;
    return body;
  }

  const HOOK_EXAMPLES = {
    UserPromptSubmit: {
      title: 'UserPromptSubmit hook',
      subtitle: 'Block, modify, or augment prompt',
      code: [
        '// .claude/settings.json',
        '{ "UserPromptSubmit": [{',
        '   "hooks": [{ "type": "command",',
        '              "command": "pii.sh" }] }]}',
        '',
        '# pii.sh — reads JSON from stdin',
        'PROMPT=$(cat | jq -r ".prompt")',
        'if grep -qE "SSN|credit card" <<< "$PROMPT"; then',
        '  echo "blocked: PII detected" >&2',
        '  exit 2     # block + feedback to Claude',
        'fi',
        'exit 0       # allow'
      ]
    },
    PreToolUse: {
      title: 'PreToolUse hook',
      subtitle: 'Approve, deny, or rewrite call',
      includePermissionGate: true,
      exampleNote: 'static permission rules in settings.json',
      code: [
        '// .claude/settings.json',
        '{ "permissions": {',
        '    "allow": [ "Bash(npm run *)",',
        '               "Bash(git:*)",',
        '               "Read(~/.zshrc)" ],',
        '    "deny":  [ "Bash(curl:*)", "Read(./.env)" ],',
        '    "ask":   [ "Bash(git push *)" ]',
        '}}',
        '',
        '// evaluated: deny → ask → allow (first match wins)',
        '// settings precedence (low → high):',
        '//   ~/.claude/settings.json  (user defaults)',
        '//   → .claude/settings.json  (project, committed)',
        '//   → .claude/settings.local.json  (personal, gitignored)',
        '//   → CLI flags / managed settings  (highest)'
      ]
    },
    PostToolUse: {
      title: 'PostToolUse hook',
      subtitle: 'Inspect or transform result',
      code: [
        '// .claude/settings.json',
        '{ "PostToolUse": [{ "matcher": "Edit|Write",',
        '   "hooks": [{ "type": "command",',
        '              "command": "format.sh" }] }]}',
        '',
        '# format.sh',
        'FILE=$(cat | jq -r ".tool_input.file_path")',
        'if [[ "$FILE" == *.ts ]]; then',
        '  prettier --write "$FILE"',
        'fi',
        'exit 0'
      ]
    },
    Stop: {
      title: 'Stop hook',
      subtitle: 'Final cleanup, run validators',
      code: [
        '// .claude/settings.json',
        '{ "Stop": [{',
        '   "hooks": [{ "type": "command",',
        '              "command": "auto-commit.sh" }] }]}',
        '',
        '# auto-commit.sh',
        'git add -A',
        'if git diff --cached --quiet; then',
        '  exit 0     # nothing to commit',
        'fi',
        'git commit -m "claude: $(date +%H:%M)"',
        'exit 0'
      ]
    }
  };

  function hookDetailBox(y, hookKey) {
    // Preserves original title + subtitle, adds EXAMPLE group with JSON config + bash.
    // For PreToolUse: also adds a PERMISSION GATE group above the EXAMPLE group.
    const def = HOOK_EXAMPLES[hookKey];
    const W = 440;
    const X = CX - W / 2;
    const titleH = 44; // title + subtitle line

    const gateRows = [
      { label: 'static deny rule',  result: '→ blocked',              color: '#c43c3c' },
      { label: 'static ask rule',   result: '→ prompt user',           color: '#c96442' },
      { label: 'PreToolUse hook',   result: '→ allow | ask | deny',   color: '#5b7cc7' },
      { label: 'static allow rule', result: '→ proceed',               color: '#5e8d76' }
    ];
    const gateH = def.includePermissionGate ? (28 + gateRows.length * 18 + 22) : 0;

    const codeBlockH = def.code.length * 13 + 12;
    const exampleH = 28 + codeBlockH + 8;

    const padBottom = 10;
    const H = titleH + gateH + exampleH + padBottom;

    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="${cssVar('--hook-fill')}" stroke="${cssVar('--hook-stroke')}"/>`;
    body += `<text x="${CX}" y="${y + 20}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">${escapeXml(def.title)}</text>`;
    body += `<text x="${CX}" y="${y + 36}" text-anchor="middle" font-size="11" fill="${cssVar('--text-200')}">${escapeXml(def.subtitle)}</text>`;

    let sy = y + titleH;

    if (def.includePermissionGate) {
      body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
      body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${gateH - 10}" rx="1.5" fill="${cssVar('--hook-stroke')}"/>`;
      body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="${cssVar('--hook-stroke')}">PERMISSION GATE</text>`;
      body += `<text x="${X + W - 18}" y="${sy + 14}" text-anchor="end" font-size="9" fill="${cssVar('--text-300')}" font-style="italic">precedence — first match wins</text>`;
      let ry = sy + 28;
      gateRows.forEach(r => {
        body += `<rect x="${X + 26}" y="${ry + 1}" width="3" height="14" rx="1.5" fill="${r.color}"/>`;
        body += `<text x="${X + 36}" y="${ry + 12}" font-size="11" font-weight="600" fill="${r.color}">${escapeXml(r.label)}</text>`;
        body += `<text x="${X + W - 18}" y="${ry + 12}" text-anchor="end" font-size="11" fill="${cssVar('--text-200')}">${escapeXml(r.result)}</text>`;
        ry += 18;
      });
      body += `<text x="${X + 22}" y="${ry + 16}" font-size="10" fill="${cssVar('--text-300')}" font-style="italic">↳ hook exit-code 2 → hard block (overrides all rules)</text>`;
      sy += gateH;
    }

    // EXAMPLE group: JSON config + bash with if/else + exit codes
    body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
    body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${exampleH - 10}" rx="1.5" fill="#7a7a7a"/>`;
    body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="#7a7a7a">EXAMPLE</text>`;
    body += `<text x="${X + W - 18}" y="${sy + 14}" text-anchor="end" font-size="9" fill="${cssVar('--text-300')}" font-style="italic">${escapeXml(def.exampleNote || 'config + bash with exit codes')}</text>`;
    const cb = codeBlock(X + 22, sy + 24, W - 22 - 18, def.code, cssVar('--hook-stroke'));
    body += cb.svg;

    return { svg: body, height: H };
  }

  function subagentForkBox(y) {
    // Visualizes Task tool spawning subagents in fresh isolated contexts.
    const W = 480;
    const X = CX - W / 2;
    const accent = '#5e8d76';

    const titleH = 44;
    const callH  = 38;
    const forkH  = 22;
    const subH   = 108;
    const subY   = titleH + callH + forkH;
    const fanH   = 30;
    const footerH = 22;
    const padBottom = 10;
    const H = subY + subH + fanH + footerH + padBottom;

    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="#f1f7f3" stroke="${accent}"/>`;
    body += `<text x="${CX}" y="${y + 20}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">Subagent fan-out · context fork</text>`;
    body += `<text x="${CX}" y="${y + 36}" text-anchor="middle" font-size="11" fill="${cssVar('--text-200')}">Task tool spawns subagents in fresh, isolated contexts</text>`;

    // Parent Task call snippet
    const callY = y + titleH + 2;
    body += `<text x="${X + 18}" y="${callY + 14}" font-size="10" fill="${cssVar('--text-200')}" font-family="ui-monospace, SF Mono, Menlo, monospace">parent: Task(subagent_type: "Explore", prompt: "...")</text>`;
    body += `<text x="${X + 18}" y="${callY + 28}" font-size="10" fill="${cssVar('--text-200')}" font-family="ui-monospace, SF Mono, Menlo, monospace">        Task(subagent_type: "code-reviewer", prompt: "...")</text>`;

    // Fork arrow
    const forkY = y + titleH + callH;
    body += `<line x1="${CX}" y1="${forkY}" x2="${CX}" y2="${forkY + 16}" stroke="${cssVar('--text-300')}" stroke-width="1.5" marker-end="url(#arr)"/>`;
    body += `<text x="${CX + 8}" y="${forkY + 13}" font-size="9" fill="${cssVar('--text-300')}" font-style="italic">fork — fresh context per subagent</text>`;

    // Two subagent context boxes side by side
    const sBoxY = y + subY;
    const sBoxW = (W - 36) / 2;
    const sBoxGap = 12;
    const s1X = X + 12;
    const s2X = X + 12 + sBoxW + sBoxGap;

    function renderSub(sx, name, bullets) {
      let s = '';
      s += `<rect x="${sx}" y="${sBoxY}" width="${sBoxW}" height="${subH}" rx="5" fill="white" stroke="${accent}" stroke-width="0.7"/>`;
      s += `<text x="${sx + 8}" y="${sBoxY + 14}" font-size="10.5" font-weight="700" fill="${accent}">${escapeXml(name)}</text>`;
      s += `<line x1="${sx + 8}" y1="${sBoxY + 18}" x2="${sx + sBoxW - 8}" y2="${sBoxY + 18}" stroke="${accent}" stroke-width="0.4" opacity="0.5"/>`;
      let by = sBoxY + 32;
      bullets.forEach(b => {
        s += `<text x="${sx + 10}" y="${by}" font-size="9.5" fill="${cssVar('--text-200')}">• ${escapeXml(b)}</text>`;
        by += 14;
      });
      s += `<text x="${sx + sBoxW - 12}" y="${sBoxY + subH - 8}" text-anchor="end" font-size="9" fill="${accent}" font-style="italic">own tool-use loop ↻</text>`;
      return s;
    }

    body += renderSub(s1X, 'subagent: Explore', [
      'own system prompt',
      'tools: Read · Grep · Glob',
      'fresh context window',
      'inherits parent cwd',
      'cannot spawn subagents'
    ]);
    body += renderSub(s2X, 'subagent: code-reviewer', [
      'own system prompt',
      'tools: Read · Grep · Bash',
      'optional own model (haiku)',
      'optional MEMORY.md',
      'isolation: worktree (opt)'
    ]);

    // Fan-in arrows
    const fanY = sBoxY + subH;
    const meetY = fanY + 16;
    body += `<line x1="${s1X + sBoxW / 2}" y1="${fanY}" x2="${CX}" y2="${meetY}" stroke="${cssVar('--text-300')}" stroke-width="1" stroke-dasharray="3 2"/>`;
    body += `<line x1="${s2X + sBoxW / 2}" y1="${fanY}" x2="${CX}" y2="${meetY}" stroke="${cssVar('--text-300')}" stroke-width="1" stroke-dasharray="3 2"/>`;
    body += `<line x1="${CX}" y1="${meetY}" x2="${CX}" y2="${meetY + 12}" stroke="${cssVar('--text-300')}" stroke-width="1.5" marker-end="url(#arr)"/>`;
    body += `<text x="${CX + 8}" y="${meetY + 10}" font-size="9" fill="${cssVar('--text-300')}" font-style="italic">only final message returns — intermediate calls hidden</text>`;

    // Footer
    const footerY = y + H - padBottom - 8;
    body += `<text x="${X + 18}" y="${footerY}" font-size="10" fill="${cssVar('--text-200')}">parent receives: <tspan font-family="ui-monospace, SF Mono, Menlo, monospace">[tool_result, tool_result]</tspan> — runs in parallel</text>`;

    return { svg: body, height: H };
  }

  function toolExecDetailBox(y) {
    // Preserves the original tool-types bullet list and adds CONCURRENCY BATCHES below.
    const W = 420;
    const X = CX - W / 2;
    const titleH = 28;

    const typeItems = [
      'Read · Write · Edit · Grep · Glob',
      'Bash (sandboxed)',
      'MCP tools (Slack, GitHub, Asana, chrome-devtools…)',
      'Subagents — isolated context, run in parallel'
    ];
    const typesH = 28 + typeItems.length * 16 + 8;

    const batches = [
      { tools: ['Read', 'Read', 'Read'], type: 'parallel',         color: '#5e8d76' },
      { tools: ['Bash'],                  type: 'serial (unsafe)',  color: '#c96442' },
      { tools: ['Read'],                  type: 'parallel',         color: '#5e8d76' }
    ];
    const blockH = 20;
    const blockW = 54;
    const blockGap = 4;
    const batchH = 28 + 16 + batches.length * (blockH + 6) + 20;

    const padBottom = 10;
    const H = titleH + typesH + batchH + padBottom;

    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="${cssVar('--tool-fill')}" stroke="${cssVar('--tool-stroke')}"/>`;
    body += `<text x="${CX}" y="${y + 19}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">Tool execution</text>`;

    // Group 1: TOOL TYPES (preserves original bullet list)
    let sy = y + titleH;
    body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${typesH - 10}" rx="1.5" fill="#7a7a7a"/>`;
    body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="#7a7a7a">TOOL TYPES</text>`;
    let by = sy + 28;
    typeItems.forEach(item => {
      body += `<text x="${X + 26}" y="${by}" font-size="11" fill="${cssVar('--text-200')}">• ${escapeXml(item)}</text>`;
      by += 16;
    });

    // Divider + Group 2: CONCURRENCY BATCHES
    sy += typesH;
    body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
    body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${batchH - 10}" rx="1.5" fill="#5b7cc7"/>`;
    body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="#5b7cc7">CONCURRENCY BATCHES</text>`;
    body += `<text x="${X + 22}" y="${sy + 28}" font-size="10" fill="${cssVar('--text-200')}" font-style="italic">assistant returned 5 tool_use blocks → partitioned</text>`;

    let cy = sy + 38;
    batches.forEach(batch => {
      let bx = X + 36;
      body += `<text x="${bx - 8}" y="${cy + 14}" font-size="14" fill="${cssVar('--text-300')}">[</text>`;
      batch.tools.forEach(tool => {
        body += `<rect x="${bx}" y="${cy}" width="${blockW}" height="${blockH}" rx="3" fill="white" stroke="${cssVar('--border')}"/>`;
        body += `<text x="${bx + blockW / 2}" y="${cy + 14}" text-anchor="middle" font-size="10" fill="${cssVar('--text-100')}" font-family="ui-monospace, SF Mono, Menlo, monospace">${escapeXml(tool)}</text>`;
        bx += blockW + blockGap;
      });
      body += `<text x="${bx}" y="${cy + 14}" font-size="14" fill="${cssVar('--text-300')}">]</text>`;
      bx += 12;
      body += `<text x="${bx}" y="${cy + 14}" font-size="11" fill="${batch.color}" font-weight="600">${escapeXml(batch.type)}</text>`;
      cy += blockH + 6;
    });

    body += `<text x="${X + 22}" y="${cy + 14}" font-size="10" fill="${cssVar('--text-300')}" font-style="italic">↳ adjacent concurrency-safe tools merge into one batch</text>`;
    return { svg: body, height: H };
  }

  function generateHistoryLines(fillPct, isCompacted) {
    if (isCompacted) {
      return [
        '[',
        '  { role: "user", content:',
        '    "<summary>compacted ~15 prior turns: explored repo,',
        '       ran tests, fixed types, refactored helper…</summary>" },',
        '  { role: "user",      content: "current task continues" },',
        '  { role: "assistant", content: [text, tool_use(Edit)] },',
        '  { role: "user",      content: [...tool_result] }',
        ']'
      ];
    }
    const turnCount = Math.max(1, Math.round((fillPct - 9) / 4));
    const descs = ['explored repo', 'ran tests', 'fixed types', 'refactored helper',
                   'wrote docs', 'edited file', 'searched code', 'applied diff',
                   'ran linter', 'inspected logs', 'read config', 'patched bug'];
    const lines = ['['];
    for (let i = 1; i < turnCount; i++) {
      lines.push(`  /* turn ${i}: ${descs[(i - 1) % descs.length]} */`);
    }
    lines.push('  { role: "user",      content: "…in-progress task" },');
    lines.push('  { role: "assistant", content: [text, tool_use(Edit)] },');
    lines.push(']');
    return lines;
  }

  function scrollableCodeBlock(x, y, w, lines, accent, maxVisibleLines) {
    const padX = 8, padY = 6, lineH = 13;
    const viewportH = padY * 2 + maxVisibleLines * lineH;
    const overflow = lines.length > maxVisibleLines;

    let svg = '';
    svg += `<rect x="${x}" y="${y}" width="${w}" height="${viewportH}" rx="3" fill="#fafaf9" stroke="${accent}" stroke-width="0.6" stroke-dasharray="2 2" opacity="0.9"/>`;

    // Visible content (anchored to top — first N lines)
    const visibleLines = Math.min(lines.length, maxVisibleLines);
    let ly = y + padY + 10;
    for (let i = 0; i < visibleLines; i++) {
      svg += `<text x="${x + padX}" y="${ly}" font-family="ui-monospace, SF Mono, Menlo, Consolas, monospace" font-size="9.5" fill="#3a3a3a">${escapeXml(lines[i])}</text>`;
      ly += lineH;
    }

    // Scrollbar (when content overflows)
    if (overflow) {
      const sbW = 4;
      const sbX = x + w - 8;
      const sbY = y + 4;
      const sbH = viewportH - 8;
      svg += `<rect x="${sbX}" y="${sbY}" width="${sbW}" height="${sbH}" rx="2" fill="#e5e3e0"/>`;
      const thumbH = Math.max(10, sbH * (maxVisibleLines / lines.length));
      const thumbY = sbY; // anchored at top because content is anchored at top
      svg += `<rect x="${sbX}" y="${thumbY}" width="${sbW}" height="${thumbH}" rx="2" fill="#9a9a9a"/>`;
    }

    return { svg, height: viewportH, overflow, totalLines: lines.length };
  }

  function budgetBar(x, y, w, fillPct, isCompacted) {
    // Fixed segments — tools/instructions/skills (cache hierarchy left to right).
    const segs = [
      { pct: 5, color: '#5b7cc7' }, // tools
      { pct: 4, color: '#c96442' }, // instructions
      { pct: 2, color: '#5e8d76' }  // skills/subagents
    ];
    const fixedUsed = 11;            // 5 + 4 + 2
    const bufferPct = 16.5;
    const threshPct = 83.5;

    // History portion is driven by the slider.
    let summaryPct = 0, historyPct;
    if (isCompacted) {
      summaryPct = 3;   // <summary> block
      historyPct = 5;   // recent turns kept post-compaction
    } else {
      historyPct = Math.max(0, fillPct - fixedUsed);
    }
    const totalUsed = fixedUsed + summaryPct + historyPct;
    const freePct = Math.max(0, 100 - totalUsed - bufferPct);

    const titleY = y + 10;
    const barY = y + 24;
    const barH = 18;
    const noteY = barY + barH + 14;
    const totalH = noteY - y + 4;

    let svg = '';
    svg += `<text x="${x}" y="${titleY}" font-size="9" font-weight="700" letter-spacing="0.6" fill="${cssVar('--text-300')}">TOKEN BUDGET</text>`;
    let titleText = `~200K (Sonnet 4.6)  ·  current fill ${Math.round(totalUsed)}%  ·  auto-compact at 83.5%`;
    if (isCompacted) titleText += '  ·  ✓ compacted';
    svg += `<text x="${x + 92}" y="${titleY}" font-size="10" fill="${cssVar('--text-200')}">${escapeXml(titleText)}</text>`;

    // Stacked bar
    let cx = x;
    for (const s of segs) {
      const sw = (s.pct / 100) * w;
      svg += `<rect x="${cx}" y="${barY}" width="${sw}" height="${barH}" fill="${s.color}"/>`;
      cx += sw;
    }
    if (summaryPct > 0) {
      const sw = (summaryPct / 100) * w;
      svg += `<rect x="${cx}" y="${barY}" width="${sw}" height="${barH}" fill="#5a5a5a"/>`;
      cx += sw;
    }
    const histW = (historyPct / 100) * w;
    svg += `<rect x="${cx}" y="${barY}" width="${histW}" height="${barH}" fill="#7a7a7a"/>`;
    cx += histW;
    const freeW = (freePct / 100) * w;
    svg += `<rect x="${cx}" y="${barY}" width="${freeW}" height="${barH}" fill="#eaeaea"/>`;
    cx += freeW;
    const bufW = (bufferPct / 100) * w;
    svg += `<rect x="${cx}" y="${barY}" width="${bufW}" height="${barH}" fill="#bfbfbf" opacity="0.35"/>`;

    // Outline
    svg += `<rect x="${x}" y="${barY}" width="${w}" height="${barH}" fill="none" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;

    // 83.5% threshold marker
    const thx = x + (threshPct / 100) * w;
    svg += `<line x1="${thx}" y1="${barY - 5}" x2="${thx}" y2="${barY + barH + 5}" stroke="#c96442" stroke-width="1" stroke-dasharray="3 2"/>`;
    svg += `<polygon points="${thx - 3},${barY - 5} ${thx + 3},${barY - 5} ${thx},${barY - 1}" fill="#c96442"/>`;

    // Annotations
    if (isCompacted) {
      svg += `<text x="${x}" y="${noteY}" font-size="9" fill="${cssVar('--text-300')}">← cached prefix</text>`;
      svg += `<text x="${x + w / 2}" y="${noteY}" text-anchor="middle" font-size="9" fill="${cssVar('--hook-stroke')}" font-weight="600">summary + recent turns</text>`;
      svg += `<text x="${x + w}" y="${noteY}" text-anchor="end" font-size="9" fill="${cssVar('--text-300')}">16.5% buffer</text>`;
    } else {
      svg += `<text x="${x}" y="${noteY}" font-size="9" fill="${cssVar('--text-300')}">← cached prefix (stable)</text>`;
      svg += `<text x="${x + w / 2}" y="${noteY}" text-anchor="middle" font-size="9" fill="${cssVar('--text-300')}">messages grow →</text>`;
      svg += `<text x="${x + w}" y="${noteY}" text-anchor="end" font-size="9" fill="${cssVar('--text-300')}">16.5% buffer reserved</text>`;
    }

    return { svg, height: totalH };
  }

  function codeBlock(x, y, w, lines, accent) {
    const padX = 8, padY = 6, lineH = 13;
    const h = padY * 2 + lines.length * lineH;
    let svg = `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="3" fill="#fafaf9" stroke="${accent}" stroke-width="0.6" stroke-dasharray="2 2" opacity="0.9"/>`;
    let ly = y + padY + 10;
    for (const line of lines) {
      svg += `<text x="${x + padX}" y="${ly}" font-family="ui-monospace, SF Mono, Menlo, Consolas, monospace" font-size="9.5" fill="#3a3a3a">${escapeXml(line)}</text>`;
      ly += lineH;
    }
    return { svg, height: h };
  }

  function contextBox(y, expanded, fillPct, isCompacted) {
    const W = expanded ? 520 : BOX_W;
    const X = CX - W / 2;

    const groups = [
      {
        label: 'INSTRUCTIONS',
        items: [
          'System prompt · CLAUDE.md · rules · imports',
          'auto MEMORY.md (Claude writes)'
        ],
        color: '#c96442',
        detail: {
          type: 'codes',
          blocks: [
            {
              title: '.claude/rules/*.md — frontmatter scopes by path glob',
              code: [
                '---',
                'paths:',
                '  - "src/api/**/*.ts"',
                '  - "lib/**/*.{ts,tsx}"',
                '---',
                '# rules in markdown — only injected when',
                '# Claude reads a file matching one of paths'
              ]
            },
            {
              title: 'auto memory — Claude writes/maintains, not you',
              code: [
                '~/.claude/projects/<repo>/memory/MEMORY.md',
                '  • loaded at session start (first 200 lines / 25 KB)',
                '  • acts as an index Claude reads every session',
                '~/.claude/projects/<repo>/memory/<topic>.md',
                '  • topic files (debugging, architecture, build-commands)',
                '  • Claude creates them when MEMORY.md gets long',
                '  • read on demand when relevant'
              ]
            }
          ]
        }
      },
      {
        label: 'HISTORY',
        items: 'Prior turns · grows until auto-compact fires at ~83.5%',
        color: '#7a7a7a',
        detail: {
          type: 'history',
          title: 'messages[] — drag the slider to grow / compact this block'
        }
      },
      {
        label: 'TOOLS',
        items: 'JSON schemas: built-in · MCP · Task (subagents)',
        color: '#5b7cc7',
        detail: {
          type: 'mixed',
          rows: [
            { label: 'Built-in', value: 'Read · Write · Edit · Grep · Glob · Bash · WebFetch · WebSearch · TodoWrite' },
            { label: 'MCP',      value: 'chrome-devtools · aem-mcp · slack · github · linear · figma · …' },
            { label: 'Task',     value: 'built-in tool that spawns a subagent (subagent_type enum lists each one)' }
          ],
          codeTitle: 'example MCP server — chrome-devtools (26 tools, 6 categories)',
          code: [
            '// registered as mcp__chrome-devtools__<tool_name>',
            'navigate_page              — Open a URL in the controlled tab',
            'take_snapshot              — Accessibility-tree snapshot of the page',
            'list_network_requests      — Requests since last navigation',
            'list_console_messages      — Console logs since last navigation',
            'performance_start_trace    — Begin recording a performance trace',
            'performance_analyze_insight — Extract LCP, blocking time, …',
            '… plus 20 more (input · evaluate · DOM · emulation)'
          ]
        }
      },
      {
        label: 'SKILLS & SUBAGENTS',
        items: [
          'Frontmatter only — body loads on demand',
          'Subagents may keep their own MEMORY.md'
        ],
        color: '#5e8d76',
        detail: {
          type: 'codes',
          blocks: [
            {
              title: 'skill — only this is in context (invocability flags shown)',
              code: [
                '---',
                'name: pdf',
                'description: Use when the user wants to read,',
                '  merge, split, or fill PDF forms.',
                'disable-model-invocation: false  # default — Claude can auto-invoke',
                'user-invocable: true             # default — appears in / menu',
                '---'
              ]
            },
            {
              title: 'subagent — same shape; opt into persistent memory',
              code: [
                '---',
                'name: code-reviewer',
                'description: Reviews PRs for security & style.',
                'tools: [Read, Grep, Bash]',
                'memory: project   # or "user" — stores its own MEMORY.md',
                '---'
              ]
            },
            {
              title: 'agent-memory paths (subagent reads/writes its own, not yours)',
              code: [
                '.claude/agent-memory/<name>/MEMORY.md      # memory: project',
                '~/.claude/agent-memory/<name>/MEMORY.md    # memory: user'
              ]
            }
          ]
        }
      }
    ];

    const titleH = 28;
    const padBottom = 12;
    const detailLeftIndent = 22;
    const detailRightPad = 14;

    // Header area = label line + N item lines + bottom pad. items can be string or array.
    function itemLines(g) { return Array.isArray(g.items) ? g.items : [g.items]; }
    function headerHeight(g) { return 14 + itemLines(g).length * 13 + 7; }

    function detailHeight(g) {
      if (!expanded || !g.detail) return 0;
      if (g.detail.type === 'code') {
        return 6 + 12 + (g.detail.code.length * 13 + 12) + 6;
      }
      if (g.detail.type === 'codes') {
        let h = 6;
        for (const b of g.detail.blocks) {
          h += 12 + (b.code.length * 13 + 12) + 8;
        }
        return h - 2;
      }
      if (g.detail.type === 'list') {
        return 6 + g.detail.rows.length * 16 + 4;
      }
      if (g.detail.type === 'mixed') {
        const rowsH = 6 + g.detail.rows.length * 16 + 4;
        const codeH = 12 + (g.detail.code.length * 13 + 12) + 6;
        return rowsH + codeH;
      }
      if (g.detail.type === 'history') {
        // 6 (top pad) + 12 (title) + viewport (12 + 7*13 = 103) + 6 (bottom pad)
        return 6 + 12 + 103 + 6;
      }
      return 0;
    }

    const groupHeights = groups.map(g => headerHeight(g) + detailHeight(g));
    const H = titleH + groupHeights.reduce((a, b) => a + b, 0) + padBottom;

    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="${cssVar('--context-fill')}" stroke="${cssVar('--context-stroke')}"/>`;
    body += `<text x="${CX}" y="${y + 19}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">Context assembly</text>`;

    let gy = y + titleH;
    groups.forEach((g, i) => {
      const gh = groupHeights[i];
      if (i > 0) {
        body += `<line x1="${X + 14}" y1="${gy - 1}" x2="${X + W - 14}" y2="${gy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
      }
      // accent bar spanning full group height
      body += `<rect x="${X + 12}" y="${gy + 5}" width="3" height="${gh - 14}" rx="1.5" fill="${g.color}"/>`;
      // header — label + 1+ item lines (multi-line if items is an array)
      body += `<text x="${X + 22}" y="${gy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="${g.color}">${escapeXml(g.label)}</text>`;
      let _iy = gy + 27;
      itemLines(g).forEach(line => {
        body += `<text x="${X + 22}" y="${_iy}" font-size="10.5" fill="${cssVar('--text-200')}">${escapeXml(line)}</text>`;
        _iy += 13;
      });

      // expanded detail
      if (expanded && g.detail) {
        const dx = X + detailLeftIndent;
        const dw = W - detailLeftIndent - detailRightPad;
        let dy = gy + headerHeight(g);
        if (g.detail.type === 'code') {
          body += `<text x="${dx}" y="${dy + 8}" font-size="9" font-style="italic" fill="${cssVar('--text-300')}">${escapeXml(g.detail.title)}</text>`;
          dy += 12;
          const cb = codeBlock(dx, dy, dw, g.detail.code, g.color);
          body += cb.svg;
        } else if (g.detail.type === 'codes') {
          dy += 0;
          for (const blk of g.detail.blocks) {
            body += `<text x="${dx}" y="${dy + 8}" font-size="9" font-style="italic" fill="${cssVar('--text-300')}">${escapeXml(blk.title)}</text>`;
            dy += 12;
            const cb = codeBlock(dx, dy, dw, blk.code, g.color);
            body += cb.svg;
            dy += cb.height + 8;
          }
        } else if (g.detail.type === 'list') {
          dy += 4;
          for (const row of g.detail.rows) {
            body += `<text x="${dx}" y="${dy + 11}" font-size="10" font-weight="600" fill="${g.color}">${escapeXml(row.label)}</text>`;
            body += `<text x="${dx + 64}" y="${dy + 11}" font-size="10" fill="${cssVar('--text-200')}">${escapeXml(row.value)}</text>`;
            dy += 16;
          }
        } else if (g.detail.type === 'history') {
          body += `<text x="${dx}" y="${dy + 8}" font-size="9" font-style="italic" fill="${cssVar('--text-300')}">${escapeXml(g.detail.title)}</text>`;
          dy += 12;
          const lines = generateHistoryLines(fillPct, isCompacted);
          const cb = scrollableCodeBlock(dx, dy, dw, lines, g.color, 7);
          body += cb.svg;
        } else if (g.detail.type === 'mixed') {
          dy += 4;
          for (const row of g.detail.rows) {
            body += `<text x="${dx}" y="${dy + 11}" font-size="10" font-weight="600" fill="${g.color}">${escapeXml(row.label)}</text>`;
            body += `<text x="${dx + 64}" y="${dy + 11}" font-size="10" fill="${cssVar('--text-200')}">${escapeXml(row.value)}</text>`;
            dy += 16;
          }
          dy += 6;
          body += `<text x="${dx}" y="${dy + 8}" font-size="9" font-style="italic" fill="${cssVar('--text-300')}">${escapeXml(g.detail.codeTitle)}</text>`;
          dy += 12;
          const cb = codeBlock(dx, dy, dw, g.detail.code, g.color);
          body += cb.svg;
        }
      }

      gy += gh;
    });

    return { svg: body, height: H };
  }

  function modelDetailBox(y) {
    const W = 520;
    const X = CX - W / 2; // 100
    const H = 200;
    const s = styleFor('model');
    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="${s.fill}" stroke="${s.stroke}"/>`;
    body += `<text x="${CX}" y="${y + 22}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">Claude model — request payload</text>`;
    body += `<text x="${CX}" y="${y + 39}" text-anchor="middle" font-size="11" fill="${cssVar('--text-200')}">Cache hierarchy: tools → system → messages</text>`;

    const colY = y + 56;
    const colW = 160;
    const gap = 14;
    const totalCols = 3 * colW + 2 * gap;
    const startX = X + (W - totalCols) / 2;
    const blockH = 26;
    const blockGap = 6;

    const cachedFill = '#e6f4ee';
    const cachedStroke = '#7ab096';
    const cachedText = '#365e4d';
    const newFill = '#ffffff';
    const newStroke = '#d6d3d1';
    const newText = '#525252';

    const cols = [
      { label: 'tools[ ]',     cached: 'Read, Bash, Grep, MCP…', fresh: '(rarely changes)' },
      { label: 'system[ ]',    cached: 'system prompt + CLAUDE.md', fresh: 'session env / dynamic' },
      { label: 'messages[ ]',  cached: 'prior conversation turns', fresh: 'incoming user message' }
    ];

    cols.forEach((col, i) => {
      const cx = startX + i * (colW + gap);
      // column header
      body += `<text x="${cx + colW / 2}" y="${colY}" text-anchor="middle" font-size="11" font-weight="600" fill="${cssVar('--text-200')}">${escapeXml(col.label)}</text>`;

      let by = colY + 12;
      // cached block (vector element)
      body += `<rect x="${cx}" y="${by}" width="${colW}" height="${blockH}" rx="4" fill="${cachedFill}" stroke="${cachedStroke}"/>`;
      body += `<text x="${cx + 8}" y="${by + 11}" font-size="9" fill="${cachedText}" font-weight="600">cached context</text>`;
      body += `<text x="${cx + 8}" y="${by + 22}" font-size="10" fill="${cachedText}">${escapeXml(col.cached)}</text>`;
      // placeholder cache marker (right edge) — to light up later
      body += `<circle cx="${cx + colW - 7}" cy="${by + blockH / 2}" r="3.5" fill="none" stroke="#9a9a9a" stroke-dasharray="1.5 1.5" opacity="0.6"/>`;

      by += blockH + blockGap;

      // new block (vector element)
      body += `<rect x="${cx}" y="${by}" width="${colW}" height="${blockH}" rx="4" fill="${newFill}" stroke="${newStroke}"/>`;
      body += `<text x="${cx + 8}" y="${by + 11}" font-size="9" fill="${newText}" font-weight="600">new context</text>`;
      body += `<text x="${cx + 8}" y="${by + 22}" font-size="10" fill="${newText}">${escapeXml(col.fresh)}</text>`;
      body += `<circle cx="${cx + colW - 7}" cy="${by + blockH / 2}" r="3.5" fill="none" stroke="#9a9a9a" stroke-dasharray="1.5 1.5" opacity="0.4"/>`;

      // small "vector" arrow under the column
      const vy = by + blockH + 14;
      body += `<line x1="${cx + 6}" y1="${vy}" x2="${cx + colW - 6}" y2="${vy}" stroke="${cssVar('--text-300')}" stroke-width="0.8" marker-end="url(#arr)"/>`;
      body += `<text x="${cx + colW / 2}" y="${vy + 12}" text-anchor="middle" font-size="9" fill="${cssVar('--text-300')}" font-style="italic">array order →</text>`;
    });

    // mini-legend inside the box
    const legY = y + H - 14;
    const legX = X + 16;
    body += `<rect x="${legX}" y="${legY - 8}" width="10" height="10" rx="2" fill="${cachedFill}" stroke="${cachedStroke}"/>`;
    body += `<text x="${legX + 14}" y="${legY}" font-size="10" fill="${cssVar('--text-200')}">cached</text>`;
    body += `<rect x="${legX + 60}" y="${legY - 8}" width="10" height="10" rx="2" fill="${newFill}" stroke="${newStroke}"/>`;
    body += `<text x="${legX + 74}" y="${legY}" font-size="10" fill="${cssVar('--text-200')}">new</text>`;
    body += `<circle cx="${legX + 115}" cy="${legY - 3}" r="3.5" fill="none" stroke="#9a9a9a" stroke-dasharray="1.5 1.5"/>`;
    body += `<text x="${legX + 124}" y="${legY}" font-size="10" fill="${cssVar('--text-200')}">cache_control marker (placeholder)</text>`;

    return { svg: body, height: H };
  }

  function arrow(fromY, toY) {
    return `<line x1="${CX}" y1="${fromY}" x2="${CX}" y2="${toY}" stroke="${cssVar('--text-300')}" stroke-width="1.5" marker-end="url(#arr)"/>`;
  }

  function loopArrow(fromY, toY, modelRightX, loopRegionRightX) {
    // From right edge of last loop element back up to right edge of model
    const xFromOut = BOX_X + BOX_W;        // 520 — right edge of normal boxes
    const xToOut = modelRightX || xFromOut; // right edge of model (may be wider)
    const xRegion = loopRegionRightX || xFromOut; // rightmost box in the loop region
    const xRight = Math.max(xFromOut, xToOut, xRegion) + 28;
    const path = `M ${xFromOut} ${fromY} L ${xRight} ${fromY} L ${xRight} ${toY} L ${xToOut} ${toY}`;
    let svg = `<path d="${path}" fill="none" stroke="${cssVar('--model-stroke')}" stroke-width="1.5" stroke-dasharray="5 3" marker-end="url(#arrLoop)"/>`;
    const midY = (fromY + toY) / 2;
    svg += `<text x="${xRight + 14}" y="${midY}" text-anchor="middle" font-size="11" fill="${cssVar('--model-stroke')}" font-style="italic" transform="rotate(90 ${xRight + 14} ${midY})">agentic loop — feed result back</text>`;
    return svg;
  }

  function escapeXml(s) {
    return String(s).replace(/[<>&"']/g, c => ({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;',"'":'&#39;'}[c]));
  }

  function render() {
    const showHooks = document.getElementById('t-hooks').checked;
    const showLoop = document.getElementById('t-loop').checked;
    const showContext = document.getElementById('t-context').checked;
    const showInterface = document.getElementById('t-interface').checked;
    const showContextDetails = document.getElementById('t-context-details').checked;
    const showLoopDetails = document.getElementById('t-loop-details').checked;
    const showHooksDetails = document.getElementById('t-hooks-details').checked;
    const showSubagentFork = document.getElementById('t-subagent-fork').checked;
    const fillSlider = document.getElementById('fill-slider');
    const fillPct = parseFloat(fillSlider.value);
    const isCompacted = fillPct >= 83.5;
    document.getElementById('fill-value').textContent = Math.round(fillPct) + '%';
    document.getElementById('compact-badge').classList.toggle('active', isCompacted);

    // Show simulator panel only when Context details is on
    document.querySelector('.simulator').classList.toggle('hidden', !showContextDetails);

    // Render the Token Budget bar in its dedicated SVG above the diagram
    const budgetSvg = document.getElementById('budget-svg');
    const budgetW = 800;
    const budgetPadX = 8;
    const bb = budgetBar(budgetPadX, 0, budgetW - budgetPadX * 2, fillPct, isCompacted);
    budgetSvg.setAttribute('viewBox', `0 0 ${budgetW} ${bb.height + 4}`);
    budgetSvg.innerHTML = `${defs()}${bb.svg}`;

    let y = 24; // top padding
    let parts = [];
    let modelMidY = 0;
    let skipNextGap = false;

    function push(svg, advance) { parts.push(svg); y += advance; }
    function gap() {
      const fromY = y;
      const toY = y + ARROW_LEN;
      parts.push(arrow(fromY, toY));
      y = toY;
    }
    function tag(section, svg) { return `<g data-section="${section}">${svg}</g>`; }

    // 1. User prompt (always)
    push(tag('user-prompt', box(y, 48, 'step', '1. User types prompt', 'Submitted to Claude Code')), 48);

    // Hooks: UserPromptSubmit
    if (showHooks) {
      gap();
      if (showHooksDetails) {
        const hd = hookDetailBox(y, 'UserPromptSubmit');
        parts.push(tag('hook-userPromptSubmit', hd.svg));
        y += hd.height;
      } else {
        push(tag('hook-userPromptSubmit', box(y, 48, 'hook', 'UserPromptSubmit hook', 'Block, modify, or augment')), 48);
      }
    }

    // Context assembly — grouped layout is the default.
    // The "Context details" toggle is reserved for future deeper expansion (cache markers, sizes, etc.).
    if (showContext) {
      gap();
      const ctx = contextBox(y, showContextDetails, fillPct, isCompacted);
      parts.push(tag('context-box', ctx.svg));
      y += ctx.height;
    }

    // Claude model (always)
    gap();
    const modelTopY = y;
    if (showInterface) {
      const detail = modelDetailBox(y);
      parts.push(tag('model-interface', detail.svg));
      y += detail.height;
      modelMidY = modelTopY + 30; // top band of expanded box
    } else {
      push(tag('claude-model', box(y, 56, 'model', 'Claude model inference', 'Generates text or tool calls')), 56);
      modelMidY = modelTopY + 28;
    }

    // Tool use loop
    let loopReturnY = null;
    if (showLoop) {
      gap();
      const diaTop = y;
      const diamondMidY = diaTop + 55;
      push(diamond(y, 'Tool use?', 'stop_reason'), 110);
      // Label the "yes" branch on the down arrow leaving the diamond
      parts.push(`<text x="${CX + 6}" y="${diaTop + 124}" font-size="10" fill="${cssVar('--text-300')}" font-style="italic">"tool_use" — loop</text>`);

      // PreToolUse hook
      if (showHooks) {
        gap();
        if (showHooksDetails) {
          const hd = hookDetailBox(y, 'PreToolUse');
          parts.push(tag('hook-preToolUse', hd.svg));
          y += hd.height;
        } else {
          push(tag('hook-preToolUse', box(y, 48, 'hook', 'PreToolUse hook', 'Approve, deny, or rewrite call')), 48);
        }
      }

      // Tool execution
      gap();
      if (showLoopDetails) {
        const te = toolExecDetailBox(y);
        parts.push(tag('tool-execution', te.svg));
        y += te.height;
      } else {
        push(tag('tool-execution', box(y, 130, 'tool', 'Tool execution', null, [
          '• Read / Write / Edit / Grep / Glob',
          '• Bash (sandboxed)',
          '• MCP tools (Slack, GitHub, Asana…)',
          '• Subagents — isolated context, parallel',
          '  Many calls can run concurrently'
        ])), 130);
      }

      // Subagent fan-out (context fork) — sits between Tool execution and PostToolUse,
      // representing what happens inside the Task tool when subagents are spawned.
      if (showSubagentFork) {
        gap();
        const sf = subagentForkBox(y);
        parts.push(tag('subagent-fork', sf.svg));
        y += sf.height;
      }

      let lastBoxBottom = y;

      // PostToolUse hook
      if (showHooks) {
        gap();
        const postTop = y;
        if (showHooksDetails) {
          const hd = hookDetailBox(y, 'PostToolUse');
          parts.push(tag('hook-postToolUse', hd.svg));
          y += hd.height;
          loopReturnY = postTop + 24;
        } else {
          push(tag('hook-postToolUse', box(y, 48, 'hook', 'PostToolUse hook', 'Inspect or transform result')), 48);
          loopReturnY = postTop + 24;
        }
      } else {
        loopReturnY = lastBoxBottom - 65; // middle of tool exec box
      }

      // loop arrow back to model — account for any expanded boxes in the loop / model region
      const modelRightX = showInterface ? (CX + 260) : (CX + BOX_W / 2);
      const loopRegionRightX = (showSubagentFork)
        ? (CX + 240)
        : ((showLoopDetails || showHooksDetails) ? (CX + 220) : (CX + BOX_W / 2));
      parts.push(loopArrow(loopReturnY, modelMidY, modelRightX, loopRegionRightX));

      // "no" branch — bypass arrow from diamond left around the loop to the next box.
      // Concept: the loop only exits when the model returns stop_reason: "end_turn"
      // (or max_tokens / stop_sequence). PostToolUse always loops back to the model.
      const nextBoxTopY = y + ARROW_LEN;
      const bypassPath = `M ${CX - 100} ${diamondMidY} L 80 ${diamondMidY} L 80 ${nextBoxTopY - 8} L ${CX} ${nextBoxTopY - 8} L ${CX} ${nextBoxTopY}`;
      parts.push(`<path d="${bypassPath}" stroke="${cssVar('--text-300')}" stroke-width="1.5" stroke-dasharray="4 3" fill="none" marker-end="url(#arr)"/>`);
      parts.push(`<text x="86" y="${diamondMidY - 6}" font-size="10" fill="${cssVar('--text-300')}" font-style="italic">"end_turn" — exit loop</text>`);
      // Suppress the next implicit gap arrow: PostToolUse does NOT lead straight down to Stop;
      // the loop exits via the bypass above.
      y = nextBoxTopY;
      skipNextGap = true;
    }

    // Stop hook
    if (showHooks) {
      if (skipNextGap) { skipNextGap = false; } else { gap(); }
      if (showHooksDetails) {
        const hd = hookDetailBox(y, 'Stop');
        parts.push(tag('hook-stop', hd.svg));
        y += hd.height;
      } else {
        push(tag('hook-stop', box(y, 48, 'hook', 'Stop hook', 'Final cleanup, run validators')), 48);
      }
    }

    // Response (always)
    if (skipNextGap) { skipNextGap = false; } else { gap(); }
    push(tag('response', box(y, 48, 'step', 'Response streamed to user', 'Token-by-token in terminal')), 48);

    const totalH = y + 24;

    const svg = document.getElementById('diagram');
    svg.setAttribute('viewBox', `0 0 ${W} ${totalH}`);
    svg.setAttribute('width', W);
    svg.setAttribute('height', totalH);
    svg.innerHTML = `
      <title id="diag-title">Claude Code agentic workflow diagram</title>
      <desc id="diag-desc">Interactive flowchart from user prompt to response.</desc>
      ${defs()}
      ${parts.join('\n')}
    `;
  }

  document.getElementById('t-hooks').addEventListener('change', render);
  document.getElementById('t-loop').addEventListener('change', render);
  document.getElementById('t-context').addEventListener('change', render);
  document.getElementById('t-interface').addEventListener('change', render);
  document.getElementById('t-context-details').addEventListener('change', render);
  document.getElementById('t-loop-details').addEventListener('change', render);
  document.getElementById('t-hooks-details').addEventListener('change', render);
  document.getElementById('t-subagent-fork').addEventListener('change', render);
  document.getElementById('fill-slider').addEventListener('input', () => {
    // Auto-enable Context details so the slider effect is visible
    const cd = document.getElementById('t-context-details');
    if (!cd.checked) cd.checked = true;
    render();
  });
  render();

  // ====================================================================
  // .claude/ DIRECTORY TREE — left column
  // Each leaf maps to a section in the diagram (target) and the toggles
  // that need to be on for that section to be visible (enables).
  // ====================================================================
  const TREE = {
    project: {
      label: 'your-project/',
      children: [
        {
          id: 'p-package-json', label: 'package.json', type: 'file', color: 'neutral', badge: 'committed',
          oneLiner: 'Node manifest — declares build script and dependencies',
          description: 'Standard npm manifest. Not part of Claude\'s workflow, but Claude reads it to understand the project and run build/test commands.',
          target: null,
          sample: `{
  "name": "my-app",
  "version": "1.0.0",
  "scripts": {
    "build": "vite build"
  }
}`
        },
        {
          id: 'p-src', label: 'src/', type: 'folder', color: 'neutral',
          oneLiner: 'Application source — read on demand when Claude needs a file',
          description: 'Your project code. Files enter context only when Claude reads them (not all at once).',
          target: null,
          children: [
            {
              id: 'p-src-index-js', label: 'index.js', type: 'file', color: 'neutral', badge: 'committed',
              oneLiner: 'App entry point',
              description: 'Imports styles and mounts to #app. Claude reads this when asked about app initialization.',
              target: null,
              sample: `import './index.scss';

document.querySelector('#app').textContent = 'Hello world';`
            },
            {
              id: 'p-src-index-scss', label: 'index.scss', type: 'file', color: 'neutral', badge: 'committed',
              oneLiner: 'Root stylesheet',
              description: 'Sass source compiled by the build step into a single CSS bundle.',
              target: null,
              sample: `$brand: #36c0cf;

#app {
  color: $brand;
  font-family: system-ui;
}`
            },
            {
              id: 'p-src-index-html', label: 'index.html', type: 'file', color: 'neutral', badge: 'committed',
              oneLiner: 'HTML shell loaded by the dev server',
              description: 'Vite entry point. Loads the module that drives the app.',
              target: null,
              sample: `<!DOCTYPE html>
<html>
  <head><title>Demo</title></head>
  <body>
    <div id="app"></div>
    <script type="module" src="./index.js"><\/script>
  </body>
</html>`
            }
          ]
        },
        {
          id: 'p-claude-md', label: 'CLAUDE.md', type: 'file', color: 'context', badge: 'committed',
          oneLiner: 'Project instructions Claude reads every session',
          when: 'Loaded into context at session start',
          description: 'Project-specific instructions: conventions, common commands, architectural context. Lives in INSTRUCTIONS in the diagram.',
          target: 'context-box', enables: ['t-context', 't-context-details']
        },
        {
          id: 'p-mcp-json', label: '.mcp.json', type: 'file', color: 'context', badge: 'committed',
          oneLiner: 'Project-scoped MCP servers, shared with the team',
          when: 'Servers connect at session start; tool schemas deferred',
          description: 'MCP server config. Each server\'s tools become available under TOOLS. Personal MCPs go in ~/.claude.json.',
          target: 'context-box', enables: ['t-context', 't-context-details']
        },
        {
          id: 'p-worktree', label: '.worktreeinclude', type: 'file', color: 'subagent', badge: 'committed',
          oneLiner: 'Gitignored files to copy into new worktrees',
          when: 'When a subagent runs with isolation: worktree',
          description: 'Lists gitignored files (like .env) to copy when Claude creates a worktree for an isolated subagent.',
          target: 'subagent-fork', enables: ['t-loop', 't-subagent-fork']
        },
        {
          id: 'p-claude-dir', label: '.claude/', type: 'folder', children: [
            {
              id: 'p-settings', label: 'settings.json', type: 'file', color: 'hook', badge: 'committed',
              oneLiner: 'Permissions + hooks + enforced configuration',
              when: 'Session start; overrides ~/.claude/settings.json',
              description: 'Enforced (vs CLAUDE.md which is guidance). Defines static permission rules (allow/deny/ask) and hook scripts.',
              target: 'hook-preToolUse', enables: ['t-hooks', 't-hooks-details']
            },
            {
              id: 'p-settings-local', label: 'settings.local.json', type: 'file', color: 'hook', badge: 'gitignored',
              oneLiner: 'Personal settings overrides (not committed)',
              when: 'Session start; overrides project settings.json',
              description: 'Same JSON shape as settings.json but personal. Higher precedence than project settings; lower than CLI flags.',
              target: 'hook-preToolUse', enables: ['t-hooks', 't-hooks-details']
            },
            {
              id: 'p-rules', label: 'rules/', type: 'folder', children: [
                {
                  id: 'p-rules-testing', label: 'testing.md', type: 'file', color: 'context', badge: 'committed',
                  oneLiner: 'Topic rule scoped by paths: glob',
                  when: 'When Claude reads a file matching paths:',
                  description: 'Path-scoped rule. Frontmatter paths: ["**/*.test.ts"] keeps it out of context until a matching file is read.',
                  target: 'context-box', enables: ['t-context', 't-context-details']
                },
                {
                  id: 'p-rules-api', label: 'api-design.md', type: 'file', color: 'context', badge: 'committed',
                  oneLiner: 'API conventions scoped to backend code',
                  when: 'When a file under src/api/ enters context',
                  description: 'Another path-scoped rule example. Conventions only loaded when relevant.',
                  target: 'context-box', enables: ['t-context', 't-context-details']
                }
              ]
            },
            {
              id: 'p-skills', label: 'skills/', type: 'folder', children: [
                {
                  id: 'p-skill-dir', label: 'security-review/', type: 'folder', children: [
                    {
                      id: 'p-skill-md', label: 'SKILL.md', type: 'file', color: 'context', badge: 'committed',
                      oneLiner: 'Skill entrypoint (frontmatter + body)',
                      when: 'Frontmatter at session start; body loads when invoked',
                      description: 'Only frontmatter (name, description) is in context. Body loads on demand when /security-review fires or Claude auto-invokes.',
                      target: 'context-box', enables: ['t-context', 't-context-details']
                    },
                    {
                      id: 'p-skill-checklist', label: 'checklist.md', type: 'file', color: 'context', badge: 'committed',
                      oneLiner: 'Bundled support file',
                      when: 'Read on demand while running the skill',
                      description: 'Skills can bundle supporting files (templates, scripts, refs). Claude reads them via $CLAUDE_SKILL_DIR.',
                      target: 'context-box', enables: ['t-context', 't-context-details']
                    }
                  ]
                }
              ]
            },
            {
              id: 'p-commands', label: 'commands/', type: 'folder', children: [
                {
                  id: 'p-cmd-fix', label: 'fix-issue.md', type: 'file', color: 'context', badge: 'committed',
                  oneLiner: 'Single-file command (legacy — prefer skills/)',
                  when: 'User types /fix-issue <num>',
                  description: 'Single-file prompt. Skills supersede commands; new workflows should use skills/ instead.',
                  target: 'context-box', enables: ['t-context', 't-context-details']
                }
              ]
            },
            {
              id: 'p-output-styles', label: 'output-styles/', type: 'folder',
              oneLiner: 'Project-shared output styles',
              description: 'Modify the system prompt. Most output styles live in ~/.claude/output-styles/ — only put one here if your team shares it.',
              target: 'context-box', enables: ['t-context', 't-context-details'],
              children: []
            },
            {
              id: 'p-agents', label: 'agents/', type: 'folder', children: [
                {
                  id: 'p-agent-cr', label: 'code-reviewer.md', type: 'file', color: 'subagent', badge: 'committed',
                  oneLiner: 'Subagent: isolated context, own tools',
                  when: 'Spawned via Task tool or @-mention',
                  description: 'Frontmatter (name, description, tools, model, memory) registers the subagent. Body becomes its system prompt when spawned.',
                  target: 'subagent-fork', enables: ['t-loop', 't-subagent-fork']
                }
              ]
            },
            {
              id: 'p-agent-mem', label: 'agent-memory/', type: 'folder', children: [
                {
                  id: 'p-agent-mem-name', label: '<agent-name>/', type: 'folder', children: [
                    {
                      id: 'p-agent-mem-md', label: 'MEMORY.md', type: 'file', color: 'subagent', badge: 'claude-writes',
                      oneLiner: 'Subagent persistent memory (project-scoped)',
                      when: 'Loaded when subagent starts (≤25 KB)',
                      description: 'Subagent with memory: project reads/writes its own MEMORY.md here. Distinct from main session auto-memory.',
                      target: 'context-box', enables: ['t-context', 't-context-details']
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    },
    global: {
      label: '~/',
      children: [
        {
          id: 'g-claude-json', label: '.claude.json', type: 'file', color: 'neutral', badge: 'local-only',
          oneLiner: 'App state + UI preferences (not workflow)',
          when: 'Session start; mostly managed by /config',
          description: 'Holds OAuth, theme, trust decisions, personal MCP servers, UI toggles. Not part of the per-session workflow shown in the diagram.',
          target: null
        },
        {
          id: 'g-claude-dir', label: '.claude/', type: 'folder', children: [
            {
              id: 'g-claude-md', label: 'CLAUDE.md', type: 'file', color: 'context', badge: 'local-only',
              oneLiner: 'Personal instructions across every project',
              when: 'Session start; loaded with project CLAUDE.md',
              description: 'Your global instruction file. Project CLAUDE.md takes priority on conflict.',
              target: 'context-box', enables: ['t-context', 't-context-details']
            },
            {
              id: 'g-settings', label: 'settings.json', type: 'file', color: 'hook', badge: 'local-only',
              oneLiner: 'Default settings for all projects',
              when: 'Session start; lowest precedence',
              description: 'Your defaults. Project settings.json and settings.local.json override these.',
              target: 'hook-preToolUse', enables: ['t-hooks', 't-hooks-details']
            },
            {
              id: 'g-keybindings', label: 'keybindings.json', type: 'file', color: 'neutral', badge: 'local-only',
              oneLiner: 'Custom keyboard shortcuts (not workflow)',
              when: 'Session start; hot-reloaded',
              description: 'UI-only. Run /keybindings to edit. Not part of the workflow diagram.',
              target: null
            },
            {
              id: 'g-themes', label: 'themes/', type: 'folder', color: 'neutral',
              oneLiner: 'Custom color themes (not workflow)',
              description: 'UI-only. Each .json defines a theme. Not part of the workflow diagram.',
              target: null,
              children: []
            },
            {
              id: 'g-projects', label: 'projects/', type: 'folder', children: [
                {
                  id: 'g-proj-mem-dir', label: '<project>/memory/', type: 'folder', children: [
                    {
                      id: 'g-auto-memory', label: 'MEMORY.md', type: 'file', color: 'context', badge: 'claude-writes',
                      oneLiner: 'Auto-memory — Claude writes, you read',
                      when: 'Session start (first 200 lines / 25 KB)',
                      description: 'Claude maintains this across sessions itself. Acts as an index pointing to topic files Claude creates when MEMORY.md grows.',
                      target: 'context-box', enables: ['t-context', 't-context-details']
                    },
                    {
                      id: 'g-debug-md', label: 'debugging.md', type: 'file', color: 'context', badge: 'claude-writes',
                      oneLiner: 'Topic file Claude split out of MEMORY.md',
                      when: 'Read on demand when relevant',
                      description: 'Auto-split topic file. Claude picks the filename (debugging, architecture, build-commands, …).',
                      target: 'context-box', enables: ['t-context', 't-context-details']
                    }
                  ]
                }
              ]
            },
            {
              id: 'g-rules', label: 'rules/', type: 'folder', color: 'context',
              oneLiner: 'User-level rules across every project',
              description: 'Same as project .claude/rules/ but applies everywhere. Personal style, commit format, etc.',
              target: 'context-box', enables: ['t-context', 't-context-details'],
              children: []
            },
            {
              id: 'g-skills', label: 'skills/', type: 'folder', color: 'context',
              oneLiner: 'Personal skills available in every project',
              description: 'Same structure as project skills/, scoped to your user account.',
              target: 'context-box', enables: ['t-context', 't-context-details'],
              children: []
            },
            {
              id: 'g-output-styles', label: 'output-styles/', type: 'folder', children: [
                {
                  id: 'g-teaching', label: 'teaching.md', type: 'file', color: 'context', badge: 'local-only',
                  oneLiner: 'Output style — modifies the system prompt',
                  when: 'Active when outputStyle setting selects it',
                  description: 'Appends to the system prompt AND by default drops the built-in coding instructions. Lets you repurpose Claude Code for teaching/review/non-coding modes.',
                  target: 'context-box', enables: ['t-context', 't-context-details']
                }
              ]
            },
            {
              id: 'g-agents', label: 'agents/', type: 'folder', color: 'subagent',
              oneLiner: 'Personal subagents available in every project',
              description: 'Same format as project agents/. Available across all your projects.',
              target: 'subagent-fork', enables: ['t-loop', 't-subagent-fork'],
              children: []
            },
            {
              id: 'g-agent-mem', label: 'agent-memory/', type: 'folder', children: [
                {
                  id: 'g-agent-mem-name', label: '<agent-name>/', type: 'folder', children: [
                    {
                      id: 'g-agent-mem-md', label: 'MEMORY.md', type: 'file', color: 'subagent', badge: 'claude-writes',
                      oneLiner: 'Subagent memory (user-scoped)',
                      when: 'Loaded when subagent starts',
                      description: 'Subagent with memory: user stores knowledge here that persists across all projects.',
                      target: 'context-box', enables: ['t-context', 't-context-details']
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  };

  const BADGE_LABELS = {
    'committed': 'committed',
    'gitignored': 'gitignored',
    'local-only': 'local only',
    'claude-writes': 'Claude writes'
  };
  const BADGE_COLORS = {
    'committed': '',
    'gitignored': '',
    'local-only': '',
    'claude-writes': 'color-subagent'
  };

  let activeTab = 'project';
  let selectedNodeId = 'p-src';
  const expandedFolders = new Set(['p-src']);

  function findNode(nodes, id) {
    for (const node of nodes) {
      if (node.id === id) return node;
      if (node.children) {
        const found = findNode(node.children, id);
        if (found) return found;
      }
    }
    return null;
  }

  function escHtml(s) {
    return String(s).replace(/[<>&"']/g, c => ({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;',"'":'&#39;'}[c]));
  }

  function renderTreeNodes(nodes, depth) {
    return nodes.map(node => {
      const isFolder = node.type === 'folder';
      const isExpanded = isFolder && expandedFolders.has(node.id);
      const isSelected = node.id === selectedNodeId;
      const color = node.color || 'neutral';
      const indent = depth * 12;
      const chev = isFolder ? (isExpanded ? '▾' : '▸') : ' ';
      let html = '<li>';
      html += `<div class="tree-row color-${color}${isSelected ? ' selected' : ''}" data-id="${node.id}" data-type="${node.type}" style="padding-left:${indent + 4}px">`;
      html += `<span class="tree-chevron">${chev}</span>`;
      html += `<span class="tree-dot"></span>`;
      html += `<span class="tree-label">${escHtml(node.label)}</span>`;
      if (node.badge) html += `<span class="tree-badge">${BADGE_LABELS[node.badge] || node.badge}</span>`;
      html += '</div>';
      if (isFolder && isExpanded && node.children && node.children.length) {
        html += `<ul class="tree-list">${renderTreeNodes(node.children, depth + 1)}</ul>`;
      }
      html += '</li>';
      return html;
    }).join('');
  }

  function buildPath(nodes, id, prefix) {
    for (const node of nodes) {
      const here = prefix + node.label;
      if (node.id === id) return here;
      if (node.children) {
        const sub = buildPath(node.children, id, here);
        if (sub) return sub;
      }
    }
    return null;
  }

  function renderDetails() {
    const root = TREE[activeTab];
    const node = findNode(root.children, selectedNodeId);
    const panel = document.getElementById('detail-panel');
    if (!node) { panel.innerHTML = ''; return; }
    const path = buildPath(root.children, selectedNodeId, root.label) || node.label;
    const badgeHtml = node.badge
      ? `<div class="detail-badge-row"><span class="detail-badge ${BADGE_COLORS[node.badge] || ''}">${BADGE_LABELS[node.badge] || node.badge}</span></div>`
      : '';
    const whenHtml = node.when ? `<div class="detail-when">${escHtml(node.when)}</div>` : '';
    const linkHtml = node.target
      ? `<button class="detail-link-btn" id="see-in-diagram" data-target="${node.target}" data-enables="${(node.enables || []).join(',')}" type="button">→ See in diagram</button>`
      : '<span class="detail-when">Not part of the workflow diagram.</span>';
    const sampleHtml = node.sample ? `<pre class="detail-sample">${escHtml(node.sample)}</pre>` : '';
    panel.innerHTML = `
      <p class="detail-path">${escHtml(path)}</p>
      ${badgeHtml}
      <div class="detail-oneliner">${escHtml(node.oneLiner || '')}</div>
      ${whenHtml}
      <div class="detail-description">${escHtml(node.description || '')}</div>
      ${sampleHtml}
      ${linkHtml}
    `;
    const btn = document.getElementById('see-in-diagram');
    if (btn) btn.addEventListener('click', handleSeeInDiagram);
  }

  function renderTree() {
    const list = document.getElementById('tree-list');
    list.innerHTML = renderTreeNodes(TREE[activeTab].children, 0);
    list.querySelectorAll('.tree-row').forEach(row => {
      row.addEventListener('click', handleTreeClick);
    });
    renderDetails();
  }

  function handleTreeClick(e) {
    const row = e.currentTarget;
    const id = row.dataset.id;
    const type = row.dataset.type;
    if (type === 'folder') {
      if (expandedFolders.has(id)) expandedFolders.delete(id);
      else expandedFolders.add(id);
    }
    selectedNodeId = id;
    renderTree();
  }

  function handleSeeInDiagram(e) {
    const target = e.currentTarget.dataset.target;
    const enables = (e.currentTarget.dataset.enables || '').split(',').filter(Boolean);
    let needRender = false;
    enables.forEach(id => {
      const cb = document.getElementById(id);
      if (cb && !cb.checked) { cb.checked = true; needRender = true; }
    });
    if (needRender) render();
    requestAnimationFrame(() => {
      const el = document.querySelector(`#diagram [data-section="${target}"]`);
      if (!el) return;
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.classList.remove('flash-section');
      // force reflow so the animation restarts even if the class was already there
      void el.getBoundingClientRect().width;
      el.classList.add('flash-section');
      setTimeout(() => el.classList.remove('flash-section'), 1700);
    });
  }

  function switchTab(tab) {
    if (activeTab === tab) return;
    activeTab = tab;
    document.querySelectorAll('.tree-tab').forEach(t => {
      t.classList.toggle('active', t.dataset.tab === tab);
    });
    selectedNodeId = TREE[tab].children[0].id;
    renderTree();
  }

  document.querySelectorAll('.tree-tab').forEach(t => {
    t.addEventListener('click', () => switchTab(t.dataset.tab));
  });

  // Layout toggles — show/hide tree and diagram columns
  function updateLayout() {
    const showFiles   = document.getElementById('t-show-files').checked;
    const showDiagram = document.getElementById('t-show-diagram').checked;
    const layout = document.querySelector('.layout-2col');
    layout.classList.toggle('no-tree', !showFiles);
    layout.classList.toggle('no-diagram', !showDiagram);
    document.querySelector('.wd-scope').classList.toggle('no-diagram', !showDiagram);
  }
  document.getElementById('t-show-files').addEventListener('change', updateLayout);
  document.getElementById('t-show-diagram').addEventListener('change', updateLayout);
  updateLayout();

  renderTree();
})();
