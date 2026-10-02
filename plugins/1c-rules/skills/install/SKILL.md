---
name: install
description: Install 1c-rules into the current 1C project by running install.ps1. Use when the user asks to install 1C rules, поставить правила 1С, or bootstrap 1c-rules after adding the marketplace plugin.
---

# Install 1c-rules

This plugin does not copy `content/rules` into the host. In a standalone project it calls `install.ps1`, which adapts files through `adapters/*.yaml`. In an ITL-managed project the installed workflow helper owns installation and client membership.

## Host tool id

| Host | `-Tool` |
| --- | --- |
| Cursor | `cursor` |
| Claude Code | `claude-code` |
| Codex | `codex` |
| OpenCode | `opencode` |
| Kilo Code / Kilo CLI | `kilocode` |

## Steps

1. Resolve the **project root** (the 1C repo, never `~/.claude`, `~/.cursor`, `~/.config/kilo`, or the user home).
2. For a managed project (`.agent-1c/project.json`), run from its clean master. The wrapper dispatches explicit `init` to the project's ITL client attach operation with its pinned rules. Do not invoke a standalone rules checkout, a plugin HEAD cache, or `install.ps1` there. The session `ensure` hook is read-only.
3. Run the plugin script from this plugin's `scripts/` directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/invoke-install.ps1" -Action init -Tool <tool-id> -ProjectRoot "<project-root>"
```

On machines with `pwsh`, that binary is fine too. The script finds the local `1c-rules` checkout when you are developing this repo; otherwise it clones `https://github.com/comol/ai_rules_1c.git` and runs that `install.ps1`.

4. Read the installer output. Success ends with the usual `install.ps1` verification lines. Do not claim success if a frontmatter gate failed.
5. Tell the user to restart the AI client if MCP configs changed.

Do not hand-copy `content/` into `.cursor/`, `.claude/`, `.opencode/`, or `.kilo/`. Do not put on-demand rules into `.claude/rules/` or `.kilo/rules/`.
