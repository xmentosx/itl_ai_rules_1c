---
name: install
description: Install 1c-rules into this project via install.ps1
---

For a standalone project, run the plugin wrapper so `install.ps1` adapts rules for this host. A managed ITL project delegates installation and client attachment to its installed workflow helper.

1. Project root = the current 1C repository. Refuse home / CLI config directories. If `.agent-1c/project.json` exists, run from its clean master; the wrapper dispatches explicit `init` to the pinned ITL client attach operation. Do not run a standalone installer or a plugin HEAD cache there. Note whether `.ai-rules.json` already exists only for a standalone first install.
2. Tool id: Cursor `cursor`, Claude Code `claude-code`, Codex `codex`, OpenCode `opencode`, Kilo `kilocode`.
3. Execute:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/invoke-install.ps1" -Action init -Tool <tool-id> -ProjectRoot "<project-root>"
```

4. After a successful standalone first install, follow `AGENT-INSTALL.md` → `Optional first source dump`: if `.dev.env` has `INFOBASE_PATH` and no project sources exist, offer **«Выгрузить» / «Пропустить»** in chat. The wrapper uses unattended flags, so its skipped export is not the user's refusal. On acceptance execute the installed `/loadfrom1cbase full` procedure; on refusal finish installation. Never repeat a choice already answered, or offer on an update / re-init. ITL bootstrap owns source acquisition in managed projects; do not offer a second dump.

Do not copy `content/` by hand. Restart the client if MCP config changed.
