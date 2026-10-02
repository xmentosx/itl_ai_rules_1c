---
name: update
description: Update an existing 1c-rules install by running install.ps1 update. Use when the user asks to update 1C rules, /updaterules, or refresh 1c-rules after a marketplace plugin update.
---

# Update 1c-rules

Call the plugin wrapper. It uses `install.ps1 update` in standalone projects and the pinned ITL helper in managed projects. Preserve user-authored text in `USER-RULES.md`, `memory.md`, and `LLM-RULES.md`; the installed owner may refresh its marked managed block.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/invoke-install.ps1" -Action update -ProjectRoot "<project-root>"
```

If `.ai-rules.json` is missing in a standalone project, use the `install` skill (`-Action init`). A managed project uses its helper even when the rules manifest needs repair.
