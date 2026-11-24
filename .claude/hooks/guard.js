#!/usr/bin/env node
// PreToolUse guardrail for ParkFinder (ADR-0010). Enforces rules that agents
// could otherwise ignore. Reads the hook payload (JSON) from stdin.
//   deny -> the tool call is blocked, the reason is shown to Claude
//   ask  -> the human must confirm in the permission prompt
//   (no output) -> normal permission rules apply
const { execSync } = require('child_process');
const path = require('path');

function decide(decision, reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: decision,
      permissionDecisionReason: `[guard] ${reason}`,
    },
  }));
  process.exit(0);
}

const ENV_FILE = /^\.env(\..+)?$/i;
const isSecretEnvFile = (p) => {
  const base = path.basename(String(p || ''));
  return ENV_FILE.test(base) && base.toLowerCase() !== '.env.example';
};
// .env / .env.local / .env.production … as a word in a shell command (not .env.example)
const ENV_IN_CMD = /(^|[\s'"=\/\\<>|;&(])\.env(?!\.example\b)(\.[\w.-]+)?(?=$|[\s'"\/\\;|&)<>])/i;

function checkBash(cmd, cwd) {
  // Commit/tag messages are prose, not commands: ALL checks ignore their text
  // (messages mentioning ".env" and "--no-verify" were false positives on 2026-11-24).
  const c = cmd.replace(/\s-(m|-message)(\s+|=)("(?:[^"\\]|\\.)*"|'[^']*'|\$'(?:[^'\\]|\\.)*')/g, ' -m MSG')
    .replace(/\s+/g, ' ');

  // 3) secrets
  if (ENV_IN_CMD.test(c)) return decide('deny', 'Access to .env files is blocked (secrets). Use .env.example for structure.');

  // 2) git safety
  if (/\bgit\b.*\s--no-verify\b/.test(c)) return decide('deny', '--no-verify is not allowed; fix the failing hook instead.');
  if (/\bgit\s+push\b/.test(c)) {
    if (/\s(--force(-with-lease)?|-f)\b/.test(c) || /\s\+\S+/.test(c.split(/\bgit\s+push\b/)[1] || '')) {
      return decide('deny', 'Force-push is not allowed.');
    }
    const args = (c.split(/\bgit\s+push\b/)[1] || '').split(/[;&|]/)[0].trim().split(' ').filter((a) => a && !a.startsWith('-'));
    const refspecs = args.slice(1); // args[0] = remote
    if (refspecs.some((r) => /(^|:)(refs\/heads\/)?main$/.test(r))) {
      return decide('deny', 'Pushing to main is not allowed. Push a branch and open a Pull Request (PO merges).');
    }
    if (refspecs.length === 0) {
      let branch = '';
      try { branch = execSync('git branch --show-current', { cwd, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch (_) { /* not a repo */ }
      if (branch === 'main') return decide('deny', 'You are on main: pushing to main is not allowed. Create a branch and open a Pull Request.');
    }
  }

  // 1) Supabase cloud
  if (/\bsupabase\b/.test(c) && /\s--remote\b|\s--linked\b|\s--db-url\b/.test(c)) {
    if (/\bdb\s+reset\b/.test(c)) return decide('deny', 'Resetting the CLOUD database is never allowed.');
    if (/--dry-run\b/.test(c) || /\bmigration\s+list\b/.test(c) || /\bdb\s+(diff|lint)\b/.test(c)) return; // read-only
    return decide('ask', 'This changes the CLOUD database (project kiqqlbxqhuenuahbrcbl). Only allowed via /deploy-db after the PR is merged. Confirm?');
  }
}

let raw = '';
process.stdin.on('data', (d) => { raw += d; });
process.stdin.on('end', () => {
  let input;
  try { input = JSON.parse(raw); } catch (_) { return; } // never break the session on bad input
  const tool = input.tool_name;
  const ti = input.tool_input || {};
  const cwd = input.cwd || process.env.CLAUDE_PROJECT_DIR || process.cwd();

  if (tool === 'Bash' || tool === 'PowerShell') return checkBash(String(ti.command || ''), cwd);
  if (['Read', 'Write', 'Edit', 'NotebookEdit'].includes(tool)) {
    if (isSecretEnvFile(ti.file_path || ti.notebook_path)) return decide('deny', 'Access to .env files is blocked (secrets). Use .env.example for structure.');
  }
});
