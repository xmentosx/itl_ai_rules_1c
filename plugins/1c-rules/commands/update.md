---
name: update
description: Update 1c-rules in this project via install.ps1
---

If `.ai-rules.json` is missing in a standalone project, run `/1c-rules:install` instead. A managed ITL project delegates to its pinned workflow helper even when that manifest is absent.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin>/scripts/invoke-install.ps1" -Action update -ProjectRoot "<project-root>"
```

Preserve user-authored text in `USER-RULES.md`, `memory.md`, and `LLM-RULES.md`; the installed owner may refresh its marked managed block.
