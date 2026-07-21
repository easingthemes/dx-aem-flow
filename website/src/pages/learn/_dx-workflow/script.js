(function () {
  const W = 720;
  const CX = 360;
  const BOX_W = 320;
  const BOX_X = CX - BOX_W / 2;
  const ARROW_LEN = 26;

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

  function escapeXml(s) {
    return String(s).replace(/[<>&"']/g, c => ({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;',"'":'&#39;'}[c]));
  }

  function styleFor(kind) {
    if (kind === 'hook')    return { fill: cssVar('--hook-fill'),    stroke: cssVar('--hook-stroke') };
    if (kind === 'model')   return { fill: cssVar('--model-fill'),   stroke: cssVar('--model-stroke') };
    if (kind === 'context') return { fill: cssVar('--context-fill'), stroke: cssVar('--context-stroke') };
    if (kind === 'tool')    return { fill: cssVar('--tool-fill'),    stroke: cssVar('--tool-stroke') };
    if (kind === 'subagent')return { fill: cssVar('--subagent-fill'),stroke: cssVar('--subagent-stroke') };
    if (kind === 'fork')    return { fill: cssVar('--fork-fill'),    stroke: cssVar('--fork-stroke') };
    return { fill: cssVar('--step-fill'), stroke: cssVar('--step-stroke') };
  }

  function boxHeight(hasSubtitle, bulletsCount) {
    if (!bulletsCount) return hasSubtitle ? 48 : 34;
    const start = hasSubtitle ? 56 : 42;
    return start + bulletsCount * 18 + 14;
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

  function arrow(fromY, toY) {
    return `<line x1="${CX}" y1="${fromY}" x2="${CX}" y2="${toY}" stroke="${cssVar('--text-300')}" stroke-width="1.5" marker-end="url(#arr)"/>`;
  }

  function loopBack(fromY, toY, label) {
    const xOut = BOX_X + BOX_W + 40;
    const path = `M ${BOX_X + BOX_W} ${fromY} L ${xOut} ${fromY} L ${xOut} ${toY} L ${BOX_X + BOX_W} ${toY}`;
    let svg = `<path d="${path}" fill="none" stroke="${cssVar('--model-stroke')}" stroke-width="1.5" stroke-dasharray="5 3" marker-end="url(#arrLoop)"/>`;
    const midY = (fromY + toY) / 2;
    svg += `<text x="${xOut + 12}" y="${midY}" font-size="10" fill="${cssVar('--model-stroke')}" font-style="italic" transform="rotate(90 ${xOut + 12} ${midY})">${escapeXml(label)}</text>`;
    return svg;
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

  // ------------------------------------------------------------------
  // Overlay boxes — toggled layers on top of the always-visible pipeline
  // ------------------------------------------------------------------

  function configLayersBox(y, detailed) {
    const W = 440;
    const X = CX - W / 2;
    const titleH = 44;

    const rows = [
      { label: '.ai/rules/<topic>.md',        result: '→ full rewrite (highest)', color: '#4a9b9b' },
      { label: 'config.yaml overrides:',      result: '→ tweak tone / thresholds', color: '#4a9b9b' },
      { label: 'plugin defaults (rules/*.md)',result: '→ fallback (lowest)',       color: '#4a9b9b' }
    ];
    const rowsH = 28 + rows.length * 18 + 20;

    const exampleLines = [
      '# .ai/config.yaml',
      'overrides:',
      '  pr-review:',
      '    tone: "direct, no praise"',
      '    severity-threshold: 80'
    ];
    const codeH = exampleLines.length * 13 + 12;
    const exampleH = detailed ? (28 + codeH + 8) : 0;

    const padBottom = 10;
    const H = titleH + rowsH + exampleH + padBottom;

    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="${cssVar('--tool-fill')}" stroke="${cssVar('--tool-stroke')}"/>`;
    body += `<text x="${CX}" y="${y + 20}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">Three-layer config override</text>`;
    body += `<text x="${CX}" y="${y + 36}" text-anchor="middle" font-size="11" fill="${cssVar('--text-200')}">.ai/rules/ &gt; config.yaml overrides: &gt; plugin defaults — first match wins</text>`;

    let sy = y + titleH;
    body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
    body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${rowsH - 10}" rx="1.5" fill="${cssVar('--tool-stroke')}"/>`;
    body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="${cssVar('--tool-stroke')}">PRECEDENCE</text>`;
    let ry = sy + 28;
    rows.forEach(r => {
      body += `<rect x="${X + 26}" y="${ry + 1}" width="3" height="14" rx="1.5" fill="${r.color}"/>`;
      body += `<text x="${X + 36}" y="${ry + 12}" font-size="11" font-weight="600" fill="${cssVar('--text-100')}">${escapeXml(r.label)}</text>`;
      body += `<text x="${X + W - 18}" y="${ry + 12}" text-anchor="end" font-size="10" fill="${cssVar('--text-200')}">${escapeXml(r.result)}</text>`;
      ry += 18;
    });
    sy += rowsH;

    if (detailed) {
      body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
      body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${exampleH - 10}" rx="1.5" fill="#7a7a7a"/>`;
      body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="#7a7a7a">EXAMPLE</text>`;
      body += `<text x="${X + W - 18}" y="${sy + 14}" text-anchor="end" font-size="9" fill="${cssVar('--text-300')}" font-style="italic">project can also shadow a whole skill</text>`;
      const cb = codeBlock(X + 22, sy + 24, W - 22 - 18, exampleLines, cssVar('--tool-stroke'));
      body += cb.svg;
    }

    return { svg: body, height: H };
  }

  function subagentForkBox(y, detailed) {
    const W = 480;
    const X = CX - W / 2;
    const accent = cssVar('--subagent-stroke');

    const titleH = 44;
    const callH = 38;
    const forkH = 22;
    const subH = 108;
    const subY = titleH + callH + forkH;
    const fanH = 30;
    const detailH = detailed ? 46 : 0;
    const footerH = 22;
    const padBottom = 10;
    const H = subY + subH + fanH + detailH + footerH + padBottom;

    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="${cssVar('--subagent-fill')}" stroke="${accent}"/>`;
    body += `<text x="${CX}" y="${y + 20}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">Subagent delegation · context fork</text>`;
    body += `<text x="${CX}" y="${y + 36}" text-anchor="middle" font-size="11" fill="${cssVar('--text-200')}">Task tool spawns subagents in fresh, isolated contexts</text>`;

    const callY = y + titleH + 2;
    body += `<text x="${X + 18}" y="${callY + 14}" font-size="10" fill="${cssVar('--text-200')}" font-family="ui-monospace, SF Mono, Menlo, monospace">/dx-req research: Task(subagent_type: "dx-file-resolver", ...)</text>`;
    body += `<text x="${X + 18}" y="${callY + 28}" font-size="10" fill="${cssVar('--text-200')}" font-family="ui-monospace, SF Mono, Menlo, monospace">/dx-step-verify: Task(subagent_type: "dx-code-reviewer", ...)</text>`;

    const forkY = y + titleH + callH;
    body += `<line x1="${CX}" y1="${forkY}" x2="${CX}" y2="${forkY + 16}" stroke="${cssVar('--text-300')}" stroke-width="1.5" marker-end="url(#arr)"/>`;
    body += `<text x="${CX + 8}" y="${forkY + 13}" font-size="9" fill="${cssVar('--text-300')}" font-style="italic">fork — fresh context per subagent</text>`;

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

    body += renderSub(s1X, 'subagent: dx-file-resolver', [
      'tools: Grep · Glob · Read',
      'model: haiku — cheap lookups',
      'resolves paths via file-patterns.yaml',
      'writes into research.md'
    ]);
    body += renderSub(s2X, 'subagent: aem-fe-verifier', [
      'tools: Playwright · Read',
      'screenshots component on live AEM',
      'compares vs Figma / requirements',
      'writes aem-fe-verify.md'
    ]);

    const fanY = sBoxY + subH;
    const meetY = fanY + 16;
    body += `<line x1="${s1X + sBoxW / 2}" y1="${fanY}" x2="${CX}" y2="${meetY}" stroke="${cssVar('--text-300')}" stroke-width="1" stroke-dasharray="3 2"/>`;
    body += `<line x1="${s2X + sBoxW / 2}" y1="${fanY}" x2="${CX}" y2="${meetY}" stroke="${cssVar('--text-300')}" stroke-width="1" stroke-dasharray="3 2"/>`;
    body += `<line x1="${CX}" y1="${meetY}" x2="${CX}" y2="${meetY + 12}" stroke="${cssVar('--text-300')}" stroke-width="1.5" marker-end="url(#arr)"/>`;
    body += `<text x="${CX + 8}" y="${meetY + 10}" font-size="9" fill="${cssVar('--text-300')}" font-style="italic">only final message returns — intermediate calls hidden</text>`;

    let cursorY = meetY + fanH - 12;

    if (detailed) {
      cursorY += 4;
      body += `<line x1="${X + 14}" y1="${cursorY}" x2="${X + W - 14}" y2="${cursorY}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
      body += `<text x="${X + 22}" y="${cursorY + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="${accent}">ALSO USED BY</text>`;
      body += `<text x="${X + 22}" y="${cursorY + 30}" font-size="10" fill="${cssVar('--text-200')}">dx-doc-searcher (docs), aem-inspector (dialog fields), aem-page-finder (page lookup)</text>`;
      cursorY += detailH;
    }

    const footerY = y + H - padBottom - 8;
    body += `<text x="${X + 18}" y="${footerY}" font-size="10" fill="${cssVar('--text-200')}">parent receives: <tspan font-family="ui-monospace, SF Mono, Menlo, monospace">[tool_result, tool_result]</tspan></text>`;

    return { svg: body, height: H };
  }

  function skillForkBox(y, detailed) {
    const W = 480;
    const X = CX - W / 2;
    const accent = cssVar('--fork-stroke');
    const titleH = 44;

    const groups = [
      { label: 'FORKS (context: fork)', lines: ['dx-req · dx-plan · dx-plan-validate · dx-plan-resolve', 'dx-step-all · dx-step-build · dx-step-verify'] },
      { label: 'STAYS INLINE', lines: ['dx-step, dx-step-fix — loop inside dx-step-all’s own fork', 'dx-pr, dx-req-dod, dx-doc-gen — light enough to share the caller’s context'] }
    ];
    const groupH = groups.map(g => 28 + g.lines.length * 15 + 6);
    const groupsH = groupH.reduce((a, b) => a + b, 0);

    const handoffLines = [
      '.ai/run-context/orchestrating.flag — orchestrator marks itself; forked',
      'skill checks freshness (<2h) to detect orchestrated vs standalone',
      'Handoff: only the ## Return block crosses back — verdict + summary +',
      'artifact paths. The orchestrator’s own context never grows.'
    ];
    const handoffH = 28 + handoffLines.length * 15 + 8;

    const exampleLines = [
      '## Return',
      'verdict: pass',
      'summary: Build & deploy passed in 4m12s; 2 modules built.',
      'artifacts:',
      '  - .ai/specs/<id>/build-log.txt',
      'next_action: continue to Phase 4.5'
    ];
    const codeH = exampleLines.length * 13 + 12;
    const exampleH = detailed ? (28 + codeH + 20) : 0;

    const padBottom = 10;
    const H = titleH + groupsH + handoffH + exampleH + padBottom;

    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="${cssVar('--fork-fill')}" stroke="${accent}"/>`;
    body += `<text x="${CX}" y="${y + 20}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">Skill-level context fork (context: fork)</text>`;
    body += `<text x="${CX}" y="${y + 36}" text-anchor="middle" font-size="11" fill="${cssVar('--text-200')}">The whole phase skill runs as an isolated subagent — not a narrow Task-tool lookup</text>`;

    let sy = y + titleH;
    groups.forEach((g, i) => {
      const gH = groupH[i];
      body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
      body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${gH - 10}" rx="1.5" fill="${accent}"/>`;
      body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="${accent}">${escapeXml(g.label)}</text>`;
      let ly = sy + 30;
      g.lines.forEach(line => {
        body += `<text x="${X + 22}" y="${ly}" font-size="10.5" fill="${cssVar('--text-200')}">${escapeXml(line)}</text>`;
        ly += 15;
      });
      sy += gH;
    });

    body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
    body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${handoffH - 10}" rx="1.5" fill="${accent}"/>`;
    body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="${accent}">MECHANISM + HANDOFF</text>`;
    let hy = sy + 30;
    handoffLines.forEach(line => {
      body += `<text x="${X + 22}" y="${hy}" font-size="10.5" fill="${cssVar('--text-200')}">${escapeXml(line)}</text>`;
      hy += 15;
    });
    sy += handoffH;

    if (detailed) {
      body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
      body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${exampleH - 10}" rx="1.5" fill="#7a7a7a"/>`;
      body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="#7a7a7a">EXAMPLE — the entire handoff payload</text>`;
      const cb = codeBlock(X + 22, sy + 24, W - 22 - 18, exampleLines, accent);
      body += cb.svg;
      body += `<text x="${X + 22}" y="${sy + 24 + cb.height + 14}" font-size="9.5" fill="${cssVar('--text-300')}" font-style="italic">vs. Subagents below: that's an ad-hoc Task-tool lookup mid-skill — this is the whole phase.</text>`;
    }

    return { svg: body, height: H };
  }

  function multiRepoBox(y, detailed) {
    const W = 440;
    const X = CX - W / 2;
    const accent = cssVar('--hook-stroke');
    const titleH = 44;

    const bullets = [
      "This repo's branch has zero effect on Cloud pages (cross-repo rule)",
      'Run /dx-req <id> again inside that repo, on its own branch',
      'dx-hub can fan work out across repos from one place'
    ];
    const bulletsH = 14 + bullets.length * 16 + 10;

    const exampleLines = [
      '# .ai/config.yaml',
      'repos:',
      '  - name: Acme-Platform-Core',
      '    role: backend',
      '    platform: Cloud',
      '    base-branch: develop'
    ];
    const codeH = exampleLines.length * 13 + 12;
    const exampleH = detailed ? (28 + codeH + 8) : 0;

    const padBottom = 10;
    const H = titleH + bulletsH + exampleH + padBottom;

    let body = '';
    body += `<rect x="${X}" y="${y}" width="${W}" height="${H}" rx="8" fill="${cssVar('--hook-fill')}" stroke="${accent}"/>`;
    body += `<text x="${CX}" y="${y + 20}" text-anchor="middle" font-size="14" font-weight="600" fill="${cssVar('--text-100')}">Multi-repo delegation</text>`;
    body += `<text x="${CX}" y="${y + 36}" text-anchor="middle" font-size="11" fill="${cssVar('--text-200')}">implement.md's "Other repos required" field</text>`;

    let sy = y + titleH;
    body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
    let by = sy + 18;
    bullets.forEach(b => {
      body += `<text x="${X + 22}" y="${by}" font-size="11" fill="${cssVar('--text-200')}">• ${escapeXml(b)}</text>`;
      by += 16;
    });
    sy += bulletsH;

    if (detailed) {
      body += `<line x1="${X + 14}" y1="${sy - 1}" x2="${X + W - 14}" y2="${sy - 1}" stroke="${cssVar('--border')}" stroke-width="0.5"/>`;
      body += `<rect x="${X + 12}" y="${sy + 5}" width="3" height="${exampleH - 10}" rx="1.5" fill="#7a7a7a"/>`;
      body += `<text x="${X + 22}" y="${sy + 14}" font-size="9" font-weight="700" letter-spacing="0.6" fill="#7a7a7a">EXAMPLE</text>`;
      const cb = codeBlock(X + 22, sy + 24, W - 22 - 18, exampleLines, accent);
      body += cb.svg;
    }

    return { svg: body, height: H };
  }

  // ------------------------------------------------------------------
  // Main render
  // ------------------------------------------------------------------

  function render() {
    const showConfig = document.getElementById('t-config').checked;
    const showConfigDetail = document.getElementById('t-config-detail').checked;
    const showSubagents = document.getElementById('t-subagents').checked;
    const showSubagentsDetail = document.getElementById('t-subagents-detail').checked;
    const showMultirepo = document.getElementById('t-multirepo').checked;
    const showMultirepoDetail = document.getElementById('t-multirepo-detail').checked;
    const showFork = document.getElementById('t-fork').checked;
    const showForkDetail = document.getElementById('t-fork-detail').checked;

    let y = 24;
    const parts = [];
    function push(svg, advance) { parts.push(svg); y += advance; }
    function gap() { const fromY = y, toY = y + ARROW_LEN; parts.push(arrow(fromY, toY)); y = toY; }
    function tag(section, svg) { return `<g data-section="${section}">${svg}</g>`; }

    // 1. Ticket (always)
    push(tag('ticket-box', box(y, boxHeight(true, 0), 'step', 'ADO / Jira ticket', 'User Story or Bug — fetched via ADO/Atlassian MCP')), boxHeight(true, 0));

    // Skill-level context fork (toggle) — the mechanism behind every "⑂ forked" note below
    if (showFork) {
      gap();
      const sk = skillForkBox(y, showForkDetail);
      parts.push(tag('skill-fork-box', sk.svg));
      y += sk.height;
    }

    // Config layers (toggle)
    if (showConfig) {
      gap();
      const cb = configLayersBox(y, showConfigDetail);
      parts.push(tag('config-box', cb.svg));
      y += cb.height;
    }

    // 2. /dx-req (always)
    gap();
    {
      const bullets = ['raw-story.md + dor-report.md', 'explain.md (+ interview.md if gaps)', 'research.md — reuse-or-build findings', '⑂ forked — isolated context, writes files, returns one block'];
      const h = boxHeight(true, bullets.length);
      push(tag('req-box', box(y, h, 'step', '/dx-req — Requirements pipeline', 'fetch → DoR check → explain/interview → research', bullets)), h);
    }

    // Subagent fork (toggle) — research delegates file lookups
    if (showSubagents) {
      gap();
      const sf = subagentForkBox(y, showSubagentsDetail);
      parts.push(tag('subagent-fork', sf.svg));
      y += sf.height;
    }

    // 3. /dx-plan (always)
    gap();
    let planBoxMidY;
    {
      const bullets = ['plan-thinking.md — reasoning trace', 'implement.md — steps + key decisions', '⑂ forked — isolated context'];
      const h = boxHeight(true, bullets.length);
      push(tag('plan-box', box(y, h, 'step', '/dx-plan — Implementation plan', 'extended thinking → status-tracked steps', bullets)), h);
      planBoxMidY = y - h / 2;
    }

    // Multi-repo (toggle) — implement.md declares "Other repos required"
    if (showMultirepo) {
      gap();
      const mr = multiRepoBox(y, showMultirepoDetail);
      parts.push(tag('multirepo-box', mr.svg));
      y += mr.height;
    }

    // Decision: plan validated?
    gap();
    const planValidTop = y;
    const planValidMidY = planValidTop + 55;
    push(tag('plan-valid', diamond(y, 'Plan validated?', '/dx-plan-validate · forked')), 110);
    parts.push(`<text x="${CX + 6}" y="${planValidTop + 124}" font-size="10" fill="${cssVar('--text-300')}" font-style="italic">coverage OK — continue</text>`);
    parts.push(loopBack(planValidMidY, planBoxMidY, 'issues found → /dx-plan-resolve'));

    // 4. /dx-step-all (always)
    gap();
    let stepBoxMidY;
    {
      const bullets = ['dev-all-progress.md tracks status', 'stops after 2 consecutive fix failures', '⑂ forked — loops /dx-step inline inside its own fork'];
      const h = boxHeight(true, bullets.length);
      push(tag('step-box', box(y, h, 'step', '/dx-step-all — Execute steps', 'implement → test → review → commit, per step', bullets)), h);
      stepBoxMidY = y - h / 2;
    }

    // Decision: all steps done?
    gap();
    const stepsDoneTop = y;
    const stepsDoneMidY = stepsDoneTop + 55;
    push(diamond(y, 'All steps done?', 'implement.md status'), 110);
    parts.push(`<text x="${CX + 6}" y="${stepsDoneTop + 124}" font-size="10" fill="${cssVar('--text-300')}" font-style="italic">yes — continue</text>`);
    parts.push(loopBack(stepsDoneMidY, stepBoxMidY, 'next pending step'));

    // 5. build + verify (always)
    gap();
    let verifyBoxMidY;
    {
      const bullets = ['compile → lint → test → secrets → arch → review', 'aem-fe-verify.md — visual check (subagent)', '⑂ both forked — build and verify are separate isolated contexts'];
      const h = boxHeight(true, bullets.length);
      push(tag('verify-box', box(y, h, 'step', '/dx-step-build + /dx-step-verify', 'build & deploy, then 6-phase verification', bullets)), h);
      verifyBoxMidY = y - h / 2;
    }

    // Decision: verify clean?
    gap();
    const verifyCleanTop = y;
    const verifyCleanMidY = verifyCleanTop + 55;
    push(diamond(y, 'Verify clean?', 'max 3 fix cycles'), 110);
    parts.push(`<text x="${CX + 6}" y="${verifyCleanTop + 124}" font-size="10" fill="${cssVar('--text-300')}" font-style="italic">yes — continue</text>`);
    parts.push(loopBack(verifyCleanMidY, verifyBoxMidY, 'fix cycle (≤3)'));

    // 6. /dx-pr (always)
    gap();
    {
      const bullets = ['pushes branch, opens PR via ADO MCP', '— inline, shares the orchestrator\'s own context'];
      const h = boxHeight(true, bullets.length);
      push(tag('pr-box', box(y, h, 'step', '/dx-pr — Commit & PR', "share-plan.md drives the PR description", bullets)), h);
    }

    // 7. docs / DoD (always, terminal)
    gap();
    {
      const bullets = ['validation-report.md — coverage cross-check', 'poc-findings.md → ADO summary comment', '— inline, shares the orchestrator\'s own context'];
      const h = boxHeight(true, bullets.length);
      push(tag('docs-box', box(y, h, 'step', '/dx-req-dod + /dx-doc-gen', 'DoD check, wiki docs, QA handoff', bullets)), h);
    }

    const totalH = y + 24;

    const svg = document.getElementById('diagram');
    svg.setAttribute('viewBox', `0 0 ${W} ${totalH}`);
    svg.setAttribute('width', W);
    svg.setAttribute('height', totalH);
    svg.innerHTML = `
      <title id="diag-title">dx workflow pipeline diagram</title>
      <desc id="diag-desc">Flowchart from ADO/Jira ticket to merged PR.</desc>
      ${defs()}
      ${parts.join('\n')}
    `;
  }

  ['t-config', 't-config-detail', 't-subagents', 't-subagents-detail', 't-multirepo', 't-multirepo-detail', 't-fork', 't-fork-detail'].forEach(id => {
    document.getElementById(id).addEventListener('change', render);
  });
  render();

  // ====================================================================
  // .ai/ DIRECTORY TREE — left column
  // ====================================================================

  const TREE = {
    label: '.ai/',
    children: [
      {
        id: 'a-readme', label: 'README.md', type: 'file', color: 'context', badge: 'committed',
        oneLiner: 'Project overview + quick-start command reference',
        when: 'Read when a developer or agent needs the pipeline command sequence',
        description: 'Generated by /dx-init. Lists the directory structure and the core skill sequence — the map every other file in .ai/ fits into.',
        target: null,
        sample: `# acme-nimbus-global — AI Development Workflow

## Quick Start
/dx-req <ID>    # Fetch work item, explain, research
/dx-plan        # Generate step-by-step plan
/dx-step-all    # Execute steps (test + review + commit)
/dx-pr          # Create pull request`
      },
      {
        id: 'a-config', label: 'config.yaml', type: 'file', color: 'context', badge: 'committed',
        oneLiner: 'Project settings — SCM, build commands, AEM paths, trigger tokens',
        when: 'Read at the start of every skill invocation',
        description: 'Generated by /dx-init + /aem-init. Every skill reads this instead of hardcoding a build command or branch name — the config-driven convention from CLAUDE.md.',
        target: 'config-box', enables: ['t-config', 't-config-detail'],
        sample: `project:
  name: acme-nimbus-global
scm:
  base-branch: development
build:
  command: mvn clean install -PautoInstallPackage
  lint: cd ui.frontend && npm run lintcheck
aem:
  author-url: http://localhost:4502`
      },
      {
        id: 'a-me', label: 'me.md', type: 'file', color: 'context', badge: 'gitignored',
        oneLiner: 'Personal communication style — tone for PR comments and chat',
        when: 'Read by dx-pr-review / dx-pr-answer when drafting comments',
        description: 'Gitignored personal file. Tunes how the agent writes PR comments — casual, no severity labels, teammate voice — instead of a generic AI report tone.',
        target: null,
        sample: `## PR Comments
Write like a teammate talking, not a tool
generating a report. No bold severity labels
like **MUST-FIX:** — just say what's wrong.`
      },
      {
        id: 'a-project-dir', label: 'project/', type: 'folder', children: [
          {
            id: 'a-project-yaml', label: 'project.yaml', type: 'file', color: 'context', badge: 'committed',
            oneLiner: 'Brand/market/repo knowledge base — multi-brand, multi-market, multi-platform',
            when: 'Read during /dx-req research when scoping brand/market/repo',
            description: 'Structured data extracted once, reused by every ticket — which repo owns which brand, and whether it runs on the Legacy or Cloud platform.',
            target: 'req-box', enables: [],
            sample: `brands:
  - name: Nimbus
    markets:
      - code: CA
        platform: [Legacy, Cloud]
        commerce: Shopify
repos:
  - name: Experience-Nimbus-Global-2.0
    platform: Legacy
    fe-for: [Nimbus]`
          },
          {
            id: 'a-architecture', label: 'architecture.md', type: 'file', color: 'context', badge: 'committed',
            oneLiner: 'System design reference — Legacy vs Cloud rendering pipelines',
            when: 'Read during /dx-req research when a component spans both platforms',
            description: 'Explains how the two platforms render components differently, so research.md can reason about where a fix belongs instead of guessing.',
            target: 'req-box', enables: [],
            sample: `| | Legacy | Cloud |
|---|--------|-----|
| Rendering | Client-side (Handlebars) | Server-side (HTL) |
| CSS prefix | acme- | acmecom- |`
          },
          {
            id: 'a-component-index', label: 'component-index.md', type: 'file', color: 'context', badge: 'committed',
            oneLiner: 'Auto-generated catalog of every component across repos',
            when: "Read to resolve 'which component is this?' during research",
            description: 'Generated by a script scanning all repos, not hand-maintained. Used to jump straight from a ticket\'s component name to its source files.',
            target: 'req-box', enables: [],
            sample: `| Component | Title | Source |
|-----------|-------|--------|
| login-form | Sign In Form | Experience-Nimbus-Global-2.0 |`
          },
          {
            id: 'a-features', label: 'features.md', type: 'file', color: 'context', badge: 'committed',
            oneLiner: 'Condensed feature reference — auth, commerce, analytics, age-gate',
            when: "Read during research for domain context (e.g. 'how does auth work here?')",
            description: 'Short per-feature summaries so research doesn\'t have to rediscover cross-cutting systems (Adobe Analytics, Shopify, OneTrust) from scratch each ticket.',
            target: 'req-box', enables: [],
            sample: `## Authentication
Canada uses example-auth-api (PostgreSQL + Salesforce CRM).
Cloud: acmecom-form + Gateway API. Legacy Nimbus: LoginForm.js,
RegistrationForm.js in brand/scripts/libs/.`
          },
          {
            id: 'a-file-patterns', label: 'file-patterns.yaml', type: 'file', color: 'subagent', badge: 'committed',
            oneLiner: 'Source file path conventions per platform',
            when: 'Read to resolve exact file paths for a named component',
            description: 'Templated paths (HTL, dialog, Java model, exporter) per platform, so the file-resolver subagent can compute paths instead of grepping the whole repo.',
            target: 'subagent-fork', enables: ['t-subagents', 't-subagents-detail'],
            sample: `Legacy:
  backend:
    files:
      - label: HTL template
        path: "ui.apps/.../content/{name}/{name}.html"
      - label: Dialog
        path: ".../{name}/_cq_dialog/.content.xml"`
          }
        ]
      },
      {
        id: 'a-templates-dir', label: 'templates/', type: 'folder', children: [
          {
            id: 'a-templates-spec-dir', label: 'spec/', type: 'folder', children: [
              {
                id: 'a-tpl-implement', label: 'implement.md.template', type: 'file', color: 'context', badge: 'committed',
                oneLiner: 'Skeleton /dx-plan writes into — the plugin default',
                when: 'Read by /dx-plan before generating implement.md',
                description: 'The lowest layer of the three-layer override system. A project can override this with its own template, or per-run via config.yaml overrides.',
                target: 'config-box', enables: ['t-config', 't-config-detail'],
                sample: `# Implementation Plan: <Title>
**Repo:** <current repo name>
## Approach
<!-- 2-3 sentences: overall strategy -->
## Steps
### Step 1: <title>
**Status:** pending`
              }
            ]
          },
          {
            id: 'a-templates-adocomments-dir', label: 'ado-comments/', type: 'folder', children: [
              {
                id: 'a-tpl-qahandoff', label: 'qa-handoff.md.template', type: 'file', color: 'context', badge: 'committed',
                oneLiner: 'ADO comment skeleton posted by /aem-qa-handoff',
                when: 'Read when handing a finished ticket to QA',
                description: 'Same override system — a project can replace this template to change how the QA handoff comment looks, without touching the skill itself.',
                target: 'config-box', enables: ['t-config', 't-config-detail'],
                sample: `### [QAHandoff] Ready for QA — <story-title>
#### QA Pages
| Environment | URL |
| QA Author (Edit) | <qa-author-url>/editor.html<page>.html |`
              }
            ]
          }
        ]
      },
      {
        id: 'a-specs-dir', label: 'specs/', type: 'folder', children: [
          {
            id: 'a-spec-ticket-dir', label: '1000001-change-error-messaging-handling/', type: 'folder', children: [
              {
                id: 'a-raw-story', label: 'raw-story.md', type: 'file', color: 'context', badge: 'gitignored',
                oneLiner: 'Faithful dump of the ADO/Jira ticket, unmodified',
                when: 'Written first by /dx-req, phase 1',
                description: 'Preserves the ticket exactly as filed — description, acceptance criteria, comments, parent-feature context — so later phases can be checked against the original ask.',
                target: 'req-box', enables: [],
                sample: `# [AEM] [FE] [Nimbus] [Spike] Change Error Messaging
Handling Functionality
**ADO:** #1000001 | **Priority:** 2
## Description
As the PO of Accessibility, I want error messages in
forms to be announced by screen readers proactively.`
              },
              {
                id: 'a-dor-report', label: 'dor-report.md', type: 'file', color: 'context', badge: 'gitignored',
                oneLiner: 'Definition of Ready scorecard, posted back to ADO',
                when: 'Written by /dx-req phase 2, right after the ticket is fetched',
                description: "Scores the ticket against the team's DoR checklist and lists blocking gaps. Doesn't halt the pipeline — /dx-req keeps going and treats gaps as open questions for the interview phase.",
                target: 'req-box', enables: [],
                sample: `**Score:** 14/28 (50%)
**Verdict:** Needs more detail — MANDATORY criteria not
met: Component name, QA page URL`
              },
              {
                id: 'a-interview', label: 'interview.md', type: 'file', color: 'context', badge: 'gitignored',
                oneLiner: 'Clarifying Q&A when the ticket has ambiguous scope',
                when: 'Written by /dx-req phase 3 when dor-report.md flags open questions',
                description: "Turns the DoR gaps into concrete questions, then records the answers so explain.md doesn't have to guess at scope.",
                target: 'req-box', enables: [],
                sample: `**Q:** Should this spike cover all 7 listed components,
or a subset?
**A:** Narrow to 2-3 — one Cloud form, one Legacy form,
one non-form pattern if time allows.`
              },
              {
                id: 'a-explain', label: 'explain.md', type: 'file', color: 'context', badge: 'gitignored',
                oneLiner: 'Distilled requirements — the actual spec to build against',
                when: 'Written by /dx-req phase 3, after DoR + interview',
                description: 'Turns the raw ticket + interview answers into a numbered requirements list, scoped Changes-by-Area, and an explicit Out-of-Scope section — this is what /dx-plan reads, not the raw ticket.',
                target: 'req-box', enables: [],
                sample: `## Requirements
1. Narrow the POC to Legacy Sign-In form + Login Overlay.
2. Error summary panel with role="alert" and anchor links.
## Out of Scope
- Ripple brand — separate ticket.`
              },
              {
                id: 'a-research', label: 'research.md', type: 'file', color: 'subagent', badge: 'gitignored',
                oneLiner: 'Codebase findings — existing code to reuse vs. build new',
                when: 'Written by /dx-req phase 4, after explain.md — delegates file lookups to subagents',
                description: "The 'don't rebuild what exists' check. Compares candidate components, flags what's already wired vs genuinely missing, and lists every file that will need to change.",
                target: 'subagent-fork', enables: ['t-subagents', 't-subagents-detail'],
                sample: `| Candidate | a11y scaffolding | POC complexity |
|---|---|---|
| Login Overlay | role=alert, aria-live already wired | Simple |
| Cloud BaseForm | Per-field aria-describedby exists | Moderate |`
              },
              {
                id: 'a-plan-thinking', label: 'plan-thinking.md', type: 'file', color: 'context', badge: 'gitignored',
                oneLiner: 'Extended-thinking reasoning trace behind the plan',
                when: 'Written by /dx-plan before implement.md, using extended thinking',
                description: 'Captures the reasoning that produced implement.md — reuse decisions, risks, confidence roll-up — kept separate so implement.md itself stays a clean, executable step list.',
                target: 'plan-box', enables: [],
                sample: `## Decisions weighed
1. Reusable opt-in helper in Forms.js vs inline-in-login-
   form. Chose additive helper — a spike must demonstrate
   the reusable rollout path.`
              },
              {
                id: 'a-implement', label: 'implement.md', type: 'file', color: 'context', badge: 'gitignored',
                oneLiner: "Status-tracked implementation plan — one skill's source of truth",
                when: 'Written by /dx-plan; updated in place by /dx-step / /dx-step-all as steps complete',
                description: '/dx-step reads the first pending step; /dx-plan-validate cross-checks it against explain.md. Also carries the "Other repos required" field.',
                target: 'plan-box', enables: [],
                sample: `### Step 3: Add reusable opt-in updateErrorSummary
helper to Forms.js
**Status:** done
**Files:** Modify: ui.frontend/src/core/scripts/libs/Forms.js`
              },
              {
                id: 'a-dev-progress', label: 'dev-all-progress.md', type: 'file', color: 'fork', badge: 'gitignored',
                oneLiner: 'Per-step execution log — how progress survives dx-step-all\'s fork',
                when: 'Updated after every step during autonomous execution',
                description: "dx-step-all runs forked, so the orchestrator can't see its TaskList directly. This file is the only window into per-step progress — the orchestrator reads it after the fork returns its ## Return block.",
                target: 'skill-fork-box', enables: ['t-fork', 't-fork-detail'],
                sample: `| Step | Status | Note |
|---|---|---|
| 4: Wire Legacy Sign-In JS | done | committed 235bf2b26 |
| 7: Manual a11y verification | pending | requires manual testing |`
              },
              {
                id: 'a-aem-fe-verify', label: 'aem-fe-verify.md', type: 'file', color: 'subagent', badge: 'gitignored',
                oneLiner: 'Visual verification report from the AEM frontend subagent',
                when: 'Written by /aem-fe-verify, delegated to the aem-fe-verifier agent',
                description: "Screenshots the component on a live AEM page and checks it against the requirement/Figma reference — this file is the receipt of that subagent's work, including a bug it caught.",
                target: 'subagent-fork', enables: ['t-subagents', 't-subagents-detail'],
                sample: `**Result:** PASS WITH CRITICAL BUG FOUND & FIXED
Brand template override was missing the error-summary
container the JS expected — patched during verification.`
              },
              {
                id: 'a-poc-findings', label: 'poc-findings.md', type: 'file', color: 'context', badge: 'gitignored',
                oneLiner: 'Spike write-up — feeds the required ADO summary comment',
                when: 'Written by /dx-step (final step) once code + verification are done',
                description: 'For a spike ticket the deliverable is half code, half write-up. This file is the source material a later comment turns into the ADO update: what worked, what didn\'t, effort per component.',
                target: 'docs-box', enables: [],
                sample: `## Summary
Implemented the proactive error-announcement pattern on
2 components. Technically feasible, non-breaking (opt-in),
reusable via Forms.updateErrorSummary.`
              },
              {
                id: 'a-validation-report', label: 'validation-report.md', type: 'file', color: 'model', badge: 'gitignored',
                oneLiner: 'Cross-check of the plan against the requirements',
                when: 'Written by /dx-plan-validate, between /dx-plan and /dx-step',
                description: 'Verifies every requirement maps to a step, no unrequested feature crept in, and files referenced actually exist — the gate before execution starts.',
                target: 'plan-valid', enables: [],
                sample: `| Check | Result |
|-------|--------|
| Requirement Coverage | PASS — 12/12 |
| No Scope Creep | PASS |
**Overall Verdict:** PASS`
              },
              {
                id: 'a-share-plan', label: 'share-plan.md', type: 'file', color: 'context', badge: 'gitignored',
                oneLiner: 'Plain-language plan summary — the human-readable version',
                when: 'Written alongside implement.md; read by /dx-pr for the PR description',
                description: 'implement.md is written for the agent; share-plan.md is the same plan translated for a PM/BA — no jargon, explicit "What Won\'t Change" section.',
                target: 'pr-box', enables: [],
                sample: `### What I'm Planning to Do
- Pick a small, representative sample instead of all 7
  areas originally listed.
### What Won't Change
- Nothing about how forms look for sighted users changes.`
              },
              {
                id: 'a-dotbranch', label: '.branch', type: 'file', color: 'neutral', badge: 'gitignored',
                oneLiner: 'Feature branch name for this ticket',
                when: "Read by every skill to confirm it's operating on the right branch",
                description: 'One line, no frontmatter — the durable link between a spec folder and its git branch.',
                target: null,
                sample: `feature/1000001-change-error-messaging-handling`
              },
              {
                id: 'a-dotsprint', label: '.sprint', type: 'file', color: 'neutral', badge: 'gitignored',
                oneLiner: 'Sprint label captured at ticket-fetch time',
                when: 'Read for reporting; not used by pipeline logic',
                description: 'Cheap metadata snapshot — which sprint this ticket belonged to when /dx-req first ran.',
                target: null,
                sample: `Sprint 52`
              }
            ]
          }
        ]
      }
    ]
  };

  const BADGE_LABELS = { 'committed': 'committed', 'gitignored': 'gitignored' };
  const BADGE_COLORS = { 'committed': '', 'gitignored': '' };

  let selectedNodeId = 'a-readme';
  const expandedFolders = new Set(['a-project-dir']);

  const STAGE_MAP = {
    'a-readme': 0, 'a-config': 0, 'a-me': 0,
    'a-project-yaml': 0, 'a-architecture': 0, 'a-component-index': 0, 'a-features': 0, 'a-file-patterns': 0,
    'a-specs-dir': 1, 'a-spec-ticket-dir': 1,
    'a-raw-story': 1, 'a-dor-report': 1,
    'a-interview': 2, 'a-explain': 2, 'a-research': 2,
    'a-plan-thinking': 3, 'a-implement': 3,
    'a-dev-progress': 4,
    'a-aem-fe-verify': 5, 'a-poc-findings': 5,
    'a-validation-report': 6, 'a-share-plan': 6, 'a-dotbranch': 6, 'a-dotsprint': 6,
    'a-templates-dir': 7, 'a-templates-spec-dir': 7, 'a-templates-adocomments-dir': 7,
    'a-tpl-implement': 7, 'a-tpl-qahandoff': 7
  };
  const STAGE_DESCRIPTIONS = [
    'Project setup — /dx-init + /aem-init generate config, detected profile, and the AEM knowledge base.',
    '/dx-req fetches the ADO/Jira ticket and checks Definition of Ready.',
    '/dx-req clarifies gaps, then researches the codebase — delegates lookups to subagents.',
    '/dx-plan reasons through the approach and writes a status-tracked implementation plan.',
    '/dx-step-all executes each step — implement, test, review, commit — tracking progress.',
    'Verification — build, lint, test, plus a visual AEM check delegated to a Playwright subagent.',
    '/dx-plan-validate cross-checks coverage; /dx-pr packages the pull request.',
    'Show everything — the templates that generate these spec files and ADO comments.'
  ];
  let currentStage = 0;
  const MAX_STAGE = 7;

  function filterTreeByStage(nodes) {
    const out = [];
    for (const node of nodes) {
      const minStage = STAGE_MAP[node.id];
      if (minStage !== undefined && minStage > currentStage) continue;
      if (node.children && node.children.length) {
        const filteredChildren = filterTreeByStage(node.children);
        if (node.type === 'folder' && filteredChildren.length === 0 && minStage === undefined) continue;
        out.push({ ...node, children: filteredChildren });
      } else {
        out.push(node);
      }
    }
    return out;
  }

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
    const node = findNode(TREE.children, selectedNodeId);
    const panel = document.getElementById('detail-panel');
    if (!node) { panel.innerHTML = ''; return; }
    const path = buildPath(TREE.children, selectedNodeId, TREE.label) || node.label;
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

  function collectVisibleIds(nodes, set) {
    for (const node of nodes) {
      set.add(node.id);
      if (node.children) collectVisibleIds(node.children, set);
    }
    return set;
  }

  function getVisibleChildren() {
    return filterTreeByStage(TREE.children);
  }

  function renderTree() {
    const list = document.getElementById('tree-list');
    const visibleChildren = getVisibleChildren();
    const visibleIds = collectVisibleIds(visibleChildren, new Set());
    if (!visibleIds.has(selectedNodeId)) {
      const first = visibleChildren[0];
      if (first) selectedNodeId = first.id;
    }
    list.innerHTML = renderTreeNodes(visibleChildren, 0);
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
      void el.getBoundingClientRect().width;
      el.classList.add('flash-section');
      setTimeout(() => el.classList.remove('flash-section'), 1700);
    });
  }

  function expandAllVisibleFolders() {
    function walk(nodes) {
      for (const n of nodes) {
        if (n.type === 'folder') {
          expandedFolders.add(n.id);
          if (n.children) walk(n.children);
        }
      }
    }
    walk(getVisibleChildren());
  }

  function setStage(stage) {
    if (stage < 0) stage = 0;
    if (stage > MAX_STAGE) stage = MAX_STAGE;
    currentStage = stage;
    document.querySelectorAll('.stage-btn').forEach(btn => {
      const active = Number(btn.dataset.stage) === currentStage;
      btn.classList.toggle('active', active);
      btn.setAttribute('aria-pressed', active ? 'true' : 'false');
    });
    const hint = document.getElementById('stage-hint');
    if (hint) hint.textContent = STAGE_DESCRIPTIONS[currentStage] || '';
    expandAllVisibleFolders();
    renderTree();
  }

  document.querySelectorAll('.stage-btn').forEach(btn => {
    btn.addEventListener('click', () => setStage(Number(btn.dataset.stage)));
  });
  setStage(0);

  function updateLayout() {
    const showFiles   = document.getElementById('t-show-files').checked;
    const showDiagram = document.getElementById('t-show-diagram').checked;
    const layout = document.querySelector('.layout-2col');
    layout.classList.toggle('no-tree', !showFiles);
    layout.classList.toggle('no-diagram', !showDiagram);
  }
  document.getElementById('t-show-files').addEventListener('change', updateLayout);
  document.getElementById('t-show-diagram').addEventListener('change', updateLayout);
  updateLayout();

  renderTree();
})();
