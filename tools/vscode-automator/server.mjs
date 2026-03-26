#!/usr/bin/env node

/**
 * VS Code Automator — Locked-down MCP server for VS Code screenshot automation.
 *
 * Only exposes specific, hardcoded AppleScript operations for:
 * - Focusing VS Code
 * - Opening/switching panels (terminal, chat, explorer)
 * - Typing text into the active element
 * - Sending keystrokes (Enter, Tab, Escape, etc.)
 * - Taking screenshots of the VS Code window
 * - Waiting for a specified duration
 *
 * NO arbitrary script execution. Every operation maps to a fixed AppleScript snippet.
 *
 * Usage:
 *   node server.mjs                    # stdio MCP server
 *
 * Requires macOS Accessibility permission for the hosting terminal app.
 */

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { z } from 'zod';

const exec = promisify(execFile);

// ── AppleScript snippets (hardcoded, no user input in script body) ──────

const SCRIPTS = {
  focus: `
    tell application "Visual Studio Code"
      activate
    end tell
    delay 0.5
  `,

  panels: {
    terminal: 'tell application "System Events" to keystroke "`" using {control down}',
    chat: 'tell application "System Events" to keystroke "i" using {control down, shift down}',
    explorer: 'tell application "System Events" to keystroke "b" using {command down}',
    problems: 'tell application "System Events" to keystroke "m" using {command down, shift down}',
    output: 'tell application "System Events" to keystroke "u" using {command down, shift down}',
    'command-palette': 'tell application "System Events" to keystroke "p" using {command down, shift down}',
  },

  newTerminal: `
    tell application "System Events"
      keystroke "\`" using {control down, shift down}
    end tell
  `,

  // Shared: get VS Code CGWindowID via Swift/CoreGraphics
  getWindowId: `do shell script "swift -e 'import CoreGraphics; let ws = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String:Any]] ?? []; for w in ws { if (w[kCGWindowOwnerName as String] as? String) == " & quote & "Code" & quote & ", let n = w[kCGWindowNumber as String] as? Int, (w[kCGWindowLayer as String] as? Int) == 0 { print(n); break } }'"`,

  screenshot: (outputPath) => {
    const safePath = outputPath.replace(/'/g, "'\\''");
    return `do shell script "winid=$(swift -e 'import CoreGraphics; let ws = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String:Any]] ?? []; for w in ws { if (w[kCGWindowOwnerName as String] as? String) == " & quote & "Code" & quote & ", let n = w[kCGWindowNumber as String] as? Int, (w[kCGWindowLayer as String] as? Int) == 0 { print(n); break } }'); screencapture -l $winid -o '${safePath}'"`;
  },
};

// ── Allowed keystrokes (whitelist) ──────────────────────────────────────

const ALLOWED_KEYS = {
  'return': 'return',
  'enter': 'return',
  'tab': 'tab',
  'escape': 'escape',
  'space': 'space',
  'delete': 'delete',
  'up': 'up arrow',
  'down': 'down arrow',
  'left': 'left arrow',
  'right': 'right arrow',
};

const ALLOWED_MODIFIERS = ['command', 'control', 'shift', 'option'];

// ── Safe text sanitization ─────────────────────────────────────────────

function sanitizeForAppleScript(text) {
  return text
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/[\r\n\t\0]/g, ' ');
}

// ── Execute a fixed AppleScript snippet ────────────────────────────────

async function runAppleScript(script, timeoutMs = 10000) {
  try {
    const { stdout } = await exec('osascript', ['-e', script], {
      timeout: timeoutMs,
    });
    return stdout.trim();
  } catch (err) {
    throw new Error(`AppleScript failed: ${err.message}`);
  }
}

// ── Server setup ──────────────────────────────────────────────────────

const server = new McpServer({
  name: 'vscode-automator',
  version: '1.0.0',
});

// ── Tool: vscode_focus ────────────────────────────────────────────────

server.tool(
  'vscode_focus',
  'Focus the VS Code window and bring it to front.',
  {},
  async () => {
    await runAppleScript(SCRIPTS.focus);
    return { content: [{ type: 'text', text: 'VS Code focused.' }] };
  }
);

// ── Tool: vscode_open_panel ──────────────────────────────────────────

server.tool(
  'vscode_open_panel',
  'Open a VS Code panel using keyboard shortcut. Available panels: terminal, chat, explorer, problems, output, command-palette.',
  {
    panel: z.enum(['terminal', 'chat', 'explorer', 'problems', 'output', 'command-palette']).describe('Which panel to open/toggle.'),
  },
  async ({ panel }) => {
    const script = SCRIPTS.panels[panel];
    if (!script) throw new Error(`Unknown panel: ${panel}`);
    await runAppleScript(SCRIPTS.focus);
    await runAppleScript(script);
    return { content: [{ type: 'text', text: `Panel "${panel}" toggled.` }] };
  }
);

// ── Tool: vscode_new_terminal ────────────────────────────────────────

server.tool(
  'vscode_new_terminal',
  'Open a new terminal tab in VS Code.',
  {},
  async () => {
    await runAppleScript(SCRIPTS.focus);
    await runAppleScript(SCRIPTS.newTerminal);
    return { content: [{ type: 'text', text: 'New terminal opened.' }] };
  }
);

// ── Tool: vscode_type ────────────────────────────────────────────────

server.tool(
  'vscode_type',
  'Type text into the currently focused element in VS Code. Does NOT press Enter after — use vscode_keystroke for that.',
  {
    text: z.string().max(500).describe('Text to type. Max 500 characters.'),
    delay_between_chars: z.number().min(0).max(1).optional().describe('Delay between characters in seconds (default 0.02).'),
  },
  async ({ text, delay_between_chars }) => {
    if (!text) throw new Error('Text must be 1-500 characters.');
    const delay = delay_between_chars ?? 0.02;
    const safeText = sanitizeForAppleScript(text);
    const script = `
      tell application "System Events"
        set textToType to "${safeText}"
        repeat with c in (characters of textToType)
          keystroke c
          delay ${Math.min(Math.max(delay, 0), 1)}
        end repeat
      end tell
    `;
    await runAppleScript(script, 30000);
    return { content: [{ type: 'text', text: `Typed ${text.length} characters.` }] };
  }
);

// ── Tool: vscode_keystroke ───────────────────────────────────────────

server.tool(
  'vscode_keystroke',
  'Send a keyboard shortcut or special key to VS Code. Special keys: return/enter, tab, escape, space, delete, up, down, left, right. With modifiers, any single character key is allowed (e.g., key:"i" modifiers:["control","command"] for Ctrl+Cmd+I). Modifiers: command, control, shift, option.',
  {
    key: z.string().max(20).describe('The key to press. Special keys: return, enter, tab, escape, space, delete, up, down, left, right. Or any single character (a-z, 0-9, backtick, etc.) when used with modifiers.'),
    modifiers: z.array(z.enum(['command', 'control', 'shift', 'option'])).optional().describe('Modifier keys to hold (optional). Required when using character keys.'),
  },
  async ({ key, modifiers }) => {
    const modStr = (modifiers || [])
      .filter(m => ALLOWED_MODIFIERS.includes(m))
      .map(m => `${m} down`)
      .join(', ');

    const specialKeyCodes = {
      'return': 36, 'enter': 36, 'tab': 48, 'escape': 53, 'space': 49, 'delete': 51,
      'up': 126, 'down': 125, 'left': 123, 'right': 124,
      'up arrow': 126, 'down arrow': 125, 'left arrow': 123, 'right arrow': 124,
    };

    const isSpecialKey = key.toLowerCase() in specialKeyCodes || key.toLowerCase() in ALLOWED_KEYS;
    const isSingleChar = key.length === 1;

    // Single character keys require modifiers (safety: prevents arbitrary typing via keystroke)
    if (!isSpecialKey && isSingleChar && !modStr) {
      throw new Error(`Character key "${key}" requires at least one modifier. Use vscode_type for plain text.`);
    }
    if (!isSpecialKey && !isSingleChar) {
      throw new Error(`Key "${key}" not recognized. Use special key names or a single character with modifiers.`);
    }

    let script;
    if (isSingleChar && !isSpecialKey && modStr) {
      // Character key with modifiers (e.g., Cmd+Shift+P, Ctrl+Cmd+I)
      const safeChar = sanitizeForAppleScript(key);
      script = `tell application "System Events" to keystroke "${safeChar}" using {${modStr}}`;
    } else {
      const keyName = ALLOWED_KEYS[key.toLowerCase()] || key.toLowerCase();
      const keyCode = specialKeyCodes[keyName] || specialKeyCodes[key.toLowerCase()];
      if (keyCode === undefined) throw new Error(`Key "${key}" not found in key code map.`);

      if (modStr) {
        script = `tell application "System Events" to key code ${keyCode} using {${modStr}}`;
      } else if (keyName === 'return') {
        script = 'tell application "System Events" to keystroke return';
      } else if (keyName === 'tab') {
        script = 'tell application "System Events" to keystroke tab';
      } else if (keyName === 'escape') {
        script = 'tell application "System Events" to key code 53';
      } else if (keyName === 'space') {
        script = 'tell application "System Events" to keystroke space';
      } else if (keyName === 'delete') {
        script = 'tell application "System Events" to key code 51';
      } else {
        script = `tell application "System Events" to key code ${keyCode}`;
      }
    }

    await runAppleScript(script);
    return { content: [{ type: 'text', text: `Pressed ${key}${modStr ? ` with ${modifiers.join('+')}` : ''}.` }] };
  }
);

// ── Tool: vscode_command ────────────────────────────────────────────

server.tool(
  'vscode_command',
  'Run a VS Code command via the Command Palette. Opens Cmd+Shift+P, types the command name, and presses Enter. Atomic operation — no focus loss between steps. Examples: "Chat: New CLI Session to the Side", "Terminal: Create New Terminal in Editor Area".',
  {
    command: z.string().max(200).describe('The VS Code command to run (as it appears in Command Palette).'),
  },
  async ({ command }) => {
    // Open Command Palette
    await runAppleScript('tell application "System Events" to keystroke "p" using {command down, shift down}');
    await new Promise(r => setTimeout(r, 500));

    // Type command name
    const safeCommand = sanitizeForAppleScript(command);
    await runAppleScript(`
      tell application "System Events"
        keystroke "${safeCommand}"
      end tell
    `);
    await new Promise(r => setTimeout(r, 800));

    // Execute
    await runAppleScript('tell application "System Events" to keystroke return');

    return { content: [{ type: 'text', text: `Executed VS Code command: ${command}` }] };
  }
);

// ── Tool: vscode_screenshot ──────────────────────────────────────────

server.tool(
  'vscode_screenshot',
  'Take a screenshot of the VS Code window and save to a file.',
  {
    output_path: z.string().optional().describe('File path for the screenshot (PNG). Must be under tools/. Defaults to tools/screenshots/vscode-screenshot-<timestamp>.png.'),
  },
  async ({ output_path }) => {
    const outputPath = output_path || join(
      'tools', 'screenshots',
      `vscode-screenshot-${Date.now()}.png`
    );

    const resolvedPath = resolve(outputPath);
    const allowedPrefixes = [
      join(process.cwd(), 'tools'),
    ];
    const isAllowed = allowedPrefixes.some(prefix => resolvedPath.startsWith(prefix));
    if (!isAllowed) {
      throw new Error(`Screenshot path must be under tools/. Got: ${outputPath}`);
    }

    await runAppleScript(SCRIPTS.focus);
    await new Promise(r => setTimeout(r, 300));
    await runAppleScript(SCRIPTS.screenshot(resolvedPath));
    return { content: [{ type: 'text', text: `Screenshot saved to ${resolvedPath}` }] };
  }
);

// ── Recording state ──────────────────────────────────────────────────

let activeRecording = null;

// ── Tool: vscode_record ─────────────────────────────────────────────

server.tool(
  'vscode_record',
  'Start recording the VS Code window as a video. Recording runs in the background — execute automation actions, then call vscode_stop_record to finish. Only one recording at a time.',
  {
    output_path: z.string().describe('File path for the video (MOV). Must be under tools/.'),
    max_duration: z.number().min(10).max(300).optional().describe('Max recording duration in seconds (default 120). Recording auto-stops after this.'),
  },
  async ({ output_path, max_duration }) => {
    if (activeRecording) {
      throw new Error('A recording is already in progress. Call vscode_stop_record first.');
    }

    const resolvedPath = resolve(output_path);
    const allowedPrefixes = [join(process.cwd(), 'tools')];
    if (!allowedPrefixes.some(prefix => resolvedPath.startsWith(prefix))) {
      throw new Error(`Recording path must be under tools/. Got: ${output_path}`);
    }

    await runAppleScript(SCRIPTS.focus);
    await new Promise(r => setTimeout(r, 300));

    // Get VS Code window bounds (position + size) for region recording
    // Note: screencapture -l (window ID) is ignored in -V (video) mode,
    // so we use -R (region) to capture just the VS Code window area
    const boundsStr = await runAppleScript(
      'tell application "System Events" to tell process "Code" to get {position, size} of front window'
    );
    const bounds = boundsStr.split(',').map(s => parseInt(s.trim(), 10));
    if (bounds.length !== 4 || bounds.some(isNaN)) {
      throw new Error(`Could not get VS Code window bounds. Got: ${boundsStr}`);
    }
    const [x, y, w, h] = bounds;

    const duration = max_duration || 120;

    // Use -R (region) since -l (window ID) is ignored in video mode
    const proc = spawn('screencapture', ['-R', `${x},${y},${w},${h}`, '-V', String(duration), '-o', resolvedPath], {
      detached: true,
      stdio: 'ignore',
    });

    activeRecording = {
      process: proc,
      path: resolvedPath,
      startTime: Date.now(),
      maxDuration: duration,
    };

    // Auto-cleanup if process exits on its own (max duration reached)
    proc.on('exit', () => {
      activeRecording = null;
    });

    return { content: [{ type: 'text', text: `Recording started → ${resolvedPath} (max ${duration}s). Run your automation, then call vscode_stop_record.` }] };
  }
);

// ── Tool: vscode_stop_record ────────────────────────────────────────

server.tool(
  'vscode_stop_record',
  'Stop the current VS Code window recording. The video file is saved automatically.',
  {},
  async () => {
    if (!activeRecording) {
      throw new Error('No recording in progress.');
    }

    const { process: proc, path: filePath, startTime } = activeRecording;
    const elapsed = Math.round((Date.now() - startTime) / 1000);

    // Send SIGINT to screencapture to stop recording gracefully
    proc.kill('SIGINT');

    // Wait a moment for file to finalize
    await new Promise(r => setTimeout(r, 1000));

    activeRecording = null;

    return { content: [{ type: 'text', text: `Recording stopped after ${elapsed}s → ${filePath}` }] };
  }
);

// ── Tool: vscode_wait ────────────────────────────────────────────────

server.tool(
  'vscode_wait',
  'Wait for a specified number of seconds. Use to let VS Code respond before taking a screenshot.',
  {
    seconds: z.number().min(1).max(120).describe('Seconds to wait (1-120).'),
  },
  async ({ seconds }) => {
    const secs = Math.min(Math.max(seconds || 5, 1), 120);
    await new Promise(r => setTimeout(r, secs * 1000));
    return { content: [{ type: 'text', text: `Waited ${secs} seconds.` }] };
  }
);

// ── Tool: vscode_click_tab ───────────────────────────────────────────

server.tool(
  'vscode_click_tab',
  'Click on a specific terminal tab by name in VS Code terminal panel. Uses accessibility API to find and click the tab.',
  {
    tab_name: z.string().describe('Name of the terminal tab to click (e.g., "Claude Code", "bash", "Copilot").'),
  },
  async ({ tab_name }) => {
    const tabName = sanitizeForAppleScript(tab_name);
    const script = `
      tell application "System Events"
        tell process "Code"
          set tabButtons to every radio button of every tab group of every group of every group of front window
          repeat with btn in (a reference to every radio button of every tab group of every group of every group of front window)
            try
              if name of btn contains "${tabName}" then
                click btn
                return "clicked"
              end if
            end try
          end repeat
        end tell
      end tell
      return "not found"
    `;
    const result = await runAppleScript(script, 10000);
    if (result === 'not found') {
      return { content: [{ type: 'text', text: `Terminal tab "${tab_name}" not found. Try exact name from the terminal tab bar.` }] };
    }
    return { content: [{ type: 'text', text: `Clicked terminal tab "${tab_name}".` }] };
  }
);

// ── Start server ─────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
console.error('vscode-automator MCP server started (stdio)');
