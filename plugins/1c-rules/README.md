# 1c-rules plugin

Thin marketplace wrapper. It does **not** ship `content/rules` as plugin rules. In a standalone project, explicit plugin commands use `install.ps1`. In an ITL-managed project, the project-local workflow helper owns the pinned rules version and client membership: session `ensure` is read-only, explicit update dispatches to `update-ai-rules`, and a missing helper protocol gives the `/itl-update-workflow` continuation. The plugin never fetches its own rules HEAD for a managed project.

## What the plugin contains

- Skills `/1c-rules:install` and `/1c-rules:update`
- Matching slash commands
- Host hooks / OpenCode plugin that run read-only `ensure` in standalone and managed projects; installation and client attachment require an explicit command
- `plugin.mjs` for OpenCode and Kilo CLI

The Codex compatibility manifest exposes the explicit install/update skills and disables automatic hooks. Codex would otherwise discover the shared Claude `hooks/hooks.json`; that shell hook is not a verified Windows Codex entrypoint. Enabling or disabling the Codex plugin affects only plugin discovery, not the project's installed workflow or rules.

## Local check

```powershell
# Plan only
powershell.exe -NoProfile -File .\plugins\1c-rules\scripts\invoke-install.ps1 -Action ensure -Tool cursor -ProjectRoot . -DryRun

# Claude Code, this checkout
claude --plugin-dir .\plugins\1c-rules
```
