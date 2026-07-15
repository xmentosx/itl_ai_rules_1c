---
name: updaterules
description: Update the project ruleset from its controlled immutable source
---

# /updaterules — update 1c-rules

Action: update managed files from an explicitly selected immutable rules source
(on-demand rules, subagent descriptions, workflows, SKILL packages, MCP config,
OpenSpec bundle, rendered `AGENTS.md`). Never resolve or execute a moving branch
tip from this skill. Preserve:

- `USER-RULES.md` and `memory.md` — one-time templates, never overwritten;
- contents of `openspec/specs/` and `openspec/changes/` — copied in skip-if-exists mode;
- any managed file marked `userModified: true` in `.ai-rules.json`.

## Steps

1. Make sure `.ai-rules.json` exists at the project root. If it is missing, this is a first install: run `init` by `AGENT-INSTALL.md`, not `/updaterules`.

2. If this is an ITL project (both `.agent-1c/project.json` and the ITL helper
exist), delegate source resolution and pin verification to ITL:

```powershell
powershell -ExecutionPolicy Bypass -File .\.agents\skills\1c-workflow\scripts\agent-1c.ps1 -Action update-ai-rules
```

3. Outside ITL, require the user to provide a local checkout at an explicitly
selected release tag or full commit SHA. Do not clone `main`, `master`, `HEAD`,
or any other moving ref automatically. Then run:

```powershell
& "<immutable-checkout>\install.ps1" update `
  -ProjectRoot (Get-Location).Path `
  -Source "<immutable-checkout>" `
  -AssumeYes
```

4. Check installer output:
   - `Update complete.` — success;
   - `User-modified files detected: N` — files with local edits; they are marked `userModified` and preserved;
   - `Verification OK` / `Verification found N mismatch(es)` — state of freshly placed files.

5. If PowerShell is unavailable, stop and request an immutable local source.
Do not emulate an update by downloading moving upstream content. Once the
source is available, execute *Update / add / remove* from `AGENT-INSTALL.md`
through the agent channel. Do not touch `USER-RULES.md` or `memory.md`.

## Parameters

- `-AssumeYes` — answers "yes" to confirmations and keeps user edits (`keep`) on conflicting files. For a fully automated run (CI), add `-NonInteractive`.
- `-Tools cursor,claude-code` — not needed: active tools are read from `.ai-rules.json`.
