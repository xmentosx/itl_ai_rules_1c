---
description: Run a read-only readiness diagnostic for the active client, controlled rules release, OpenSpec, ITL state, and branch infobase
---

# /doctor — read-only ITL-aware diagnostic

Run diagnostics only. Do not edit files, reconcile state, install packages, start services, or expose secret values. The ITL portion is script-owned: invoke the host workflow's read-only doctor/status helper when available and format its result; do not reproduce lifecycle logic in prose.

Report a compact table using `OK`, `WARN`, `FAIL`, and `SKIP`, then list only actionable recovery commands.

Check:

1. `.ai-rules.json` declares exactly one supported client: `codex`, `kilocode`, `claude-code`, `cursor`, or `opencode`; it agrees with the project workflow config.
2. Native discovery paths exist for that client:
   - Codex: `.codex/rules`, `.codex/agents`, `.agents/skills`, and `.codex/config.toml` when managed MCP is enabled;
   - Kilo: `.kilo/rules-1c`, `.kilo/agents`, `.kilo/commands`, `.kilo/skills`, `.kilo/kilo.json`; neighboring `.kilo/kilo.jsonc` is a `FAIL` collision;
   - Claude: `.claude/rules`, `.claude/agents`, `.claude/commands`, `.claude/skills`;
   - Cursor: `.cursor/rules`, `.cursor/agents`, `.cursor/commands`, `.cursor/skills`;
   - OpenCode: `.opencode/rules`, `.opencode/agent`, `.opencode/command`, `.claude/skills`, root `opencode.json`.
3. Manifest protocol, controlled-fork provenance, managed-file hashes, root `AGENTS.md`, `USER-RULES.md`, preserved `LLM-RULES.md`, upstream rules/skills, and all five ITL lifecycle skills are present without duplicate managed copies.
4. OpenSpec workspace and rules are installed. Report `native` when managed propose/explore/apply artifacts exist and are intact; report `natural` when the pinned adapter intentionally has no bundle. Expected `bundleSkipped` is `OK`, while a missing file from a previously managed native bundle is `FAIL`. The ITL preflight applies in both modes.
5. Read `.dev.env` without changing it. Validate upstream mode keys plus `ITL_VANESSA_TESTING` and `ITL_CHECK_EVENT_LOG`; invalid ITL values are `WARN` and have effective safe default `auto`.
6. Ask the host workflow helper for read-only MCP and branch state. On `master`, branch-only checks are `SKIP`. On managed `itldev/*`, verify the branch infobase only; never probe or suggest using the source infobase.

Recovery suggestions may use only pinned `update-ai-rules`, `/itl-update-workflow`, `/itl-refresh`, or the relevant ITL MCP command. Never recommend hidden `/updaterules`, `/checkmcp`, `/installmcp`, or `/updatemcp` commands.
