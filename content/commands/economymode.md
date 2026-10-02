---
description: Toggle project economy mode; configure models separately for the selected AI client and optionally set up rtk
userOnly: true
argumentHint: "[on|off|status|models|rtk]"
---

# /economymode — orchestrator economy mode

Toggle the orchestrator economy mode for the **project** by writing the `ORCHESTRATION` key in `.dev.env`. Canonical behavior of the mode — the `orchestrator-economy.md` rule (installed copy; match by file name per the path convention in `AGENTS.md`). Load that rule before acting.

Parameters, classes and defaults — `content/rules/dev-standards-env.md §1`; Defaulted keys are never asked for. Asking about models **inside this command** is allowed and expected: it is part of an explicit user-invoked configuration flow, not "task time".

Parse the argument: empty or `on` — enable; `off` — disable; `status` — report the current state; `models` — (re)configure per-tier subagent models without changing the mode; `rtk` — run `/install-rtk` (`content/commands/install-rtk.md`) without changing the mode.

The command edits `ORCHESTRATION` only in `.dev.env`. Explicit model choices belong to the selected client's `coding` / `analysis` / `light` entry in `aiRules.modelTiersByClient` of `.agent-1c/project.json` in an ITL-managed project, or `modelTiersByClient` of `.ai-rules.json` in a standalone rules-only project. Keep every other client's entry and every unrelated project value unchanged. If `.dev.env` is missing, run the appropriate installer instead of creating a partial file; until then apply the mode only for this session. Never run the standalone installer over an ITL-managed project.

## on (default)

1. Read `ORCHESTRATION` from `.dev.env`, identify the executing client from the session or an explicit user selection, and verify that it is attached in `aiRules.tools` / the standalone manifest. An unattached client gets the ITL attach route; do not connect it implicitly. Read only that client's model entry.
2. **Model check.** Economy mode pays off only when subagents use cheaper models than the parent; empty tiers inherit this client's default. The installer renders the selected client's ids into its agent files (Cursor `.cursor/agents/`, Claude Code `.claude/agents/`, Codex `.codex/agents/*.toml`, OpenCode `.opencode/agent/`, Kilo `.kilo/agents/`).
   - If **all three** tier models for this client are set — show its current mapping without asking.
   - If **any** tier is empty — ask **one** question for this client's model per tier, including "keep inheriting". `coding` writes code/metadata, `analysis` plans/reviews/tests/docs, `light` scouts. Error fixes that author production code use `coding`. Use ids confirmed by this client's own model list or supplied by the user; do not copy another client's id. OpenCode needs `provider/model` (optional `#variant`); a bare slug may prevent the client from starting. The 1C benchmark (<https://onec-llm-bench.lovable.app/>) is advisory.
   - **Keep inheriting** is a valid answer: do not write the models, and warn that subagents will run on the parent's model, so the saving is limited to context offloading.
   - Write the chosen values into this client's model map entry. Fill **empty** tiers; overwrite a nonempty tier only on explicit user request. Preserve an absent tier as empty/inherited. When `analysis` is explicitly selected, set `analysisExplicit: true`; a migrated `false` marker must not enable reviewers by accident. In an ITL project, the host owns the project configuration and pinned re-render; never run `install.ps1` directly against it.
3. Set `ORCHESTRATION=economy`.
4. **Re-render note.** Editing the model map alone does not change installed agent files. If models changed, re-render with `install.ps1 update` for standalone rules-only projects or the pinned `agent-1c.ps1 -Action update-ai-rules` from master for ITL projects; the latter reconciles the attached set. Restart the affected client afterward, especially OpenCode/Kilo/Codex. `ORCHESTRATION` itself needs no re-render.
5. **Optional companion — `rtk`.** Economy mode saves orchestrator tokens by delegating; `rtk` compresses the output of shell commands before it reaches the model. Ask once whether to set it up now (skip is always valid); on yes run `/install-rtk` (`content/commands/install-rtk.md`), which also states its limits.
6. Load the `orchestrator-economy.md` rule and apply it immediately — from this message on, in this session, without any restart.
7. Confirm to the user in 3–4 lines, in Russian:
   - режим экономии включён и записан в `.dev.env` (`ORCHESTRATION=economy`) — действует для проекта, включая новые чаты;
   - клиент и его карта ярусов: `coding` / `analysis` / `light` → фактические модели (или «наследование от клиента» с предупреждением);
   - если настроили `rtk` — вывод shell-команд теперь сжимается (после перезапуска клиента);
   - решения, спеки и верификация остаются за головным агентом; выключение — `/economymode off`.

## off

1. In the project `.dev.env`: set `ORCHESTRATION=standard` (same edit rule as above; if `.dev.env` is missing there is nothing to persist). Do not touch client model entries.
2. Stop applying the mode immediately in this session and confirm: режим экономии выключен (`ORCHESTRATION=standard`), действует обычная политика делегирования из `subagents.md` (делегировать крупное, мелкое исполнять напрямую).

## status

Read `.dev.env` and report, without editing anything:

- the `ORCHESTRATION` value (or the default when the file / key is absent or the value is invalid) and what it means;
- the selected attached client and its tier → model mapping (or «наследование от клиента»); report other attached clients only if requested;
- whether `rtk` is installed (`rtk --version`) and, if not, that `/economymode rtk` (= `/install-rtk`) can set it up.

## models

Run the model question from step 2 of `on` (same options, same write rules, same re-render note) without changing `ORCHESTRATION`. Use when the user wants to switch models later.

## rtk

Run `/install-rtk` (`content/commands/install-rtk.md`) — install, wire into the active client, verify, or uninstall the `rtk` output-compression proxy — without changing `ORCHESTRATION`. `rtk` is a third-party, user-global tool: it is not recorded in `.dev.env` and works regardless of the economy mode.

## Constraints (always)

The mode never overrides stricter rules: quick-fix / docs-fix tasks stay with the parent, `1c-code-reviewer` runs only on an explicit user request, UI testing stays gated by `UI_TESTING`, validator chains and the verification gate are unchanged, model-tier routing stays authoritative. Details — `orchestrator-economy.md → Consistency with the existing orchestration rules`.
