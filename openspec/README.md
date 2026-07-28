# OpenSpec

> **AI agents:** if you need to install or update project rules, go to [`AGENT-INSTALL.md`](../AGENT-INSTALL.md). This file is a human-oriented overview of the OpenSpec workspace.

Spec-driven development workspace for this project, structured per the
[Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec) v1.0+ workflow
(OPSX, artifact-guided).

This folder is bundled by the `1c-rules` installer (see `AGENT-INSTALL.md`,
phase **Place / Shared OpenSpec scaffold**) so every project that installs
`1c-rules` starts with a ready-to-use OpenSpec layout. The installer copies
files in **skip-if-exists** mode — your existing specs and change proposals
are never overwritten.

## Directory layout

```
openspec/
├── README.md           # this file
├── config.yaml         # optional project-level OpenSpec config
├── project.md          # auto-generated 1C project context (see below)
├── specs/              # source of truth: how the system currently behaves
│   └── <domain>/
│       └── spec.md
└── changes/            # active proposals (one folder per change)
    ├── archive/        # completed changes (created by `openspec archive`)
    └── <change-name>/
        ├── proposal.md # why & what is changing
        ├── design.md   # how (technical decisions, optional)
        ├── tasks.md    # implementation checklist
        └── specs/      # delta specs (ADDED / MODIFIED / REMOVED)
            └── <domain>/
                └── spec.md
```

## Auto-generated `project.md` (1C context)

The installer inspects the project root on every `init` and `update` and
regenerates `openspec/project.md` from real 1C metadata signals:

- `Configuration.xml` / `ConfigurationExtension.xml` — name, synonym, vendor,
  edition, `CompatibilityMode` (→ platform version), `DefaultRunMode` +
  `Use*FormIn*Application` (→ form mode: managed / ordinary / mixed),
  `NamePrefix` (→ extension marker)
- `CommonModules/СтандартныеПодсистемыСервер/Ext/Module.bsl` (or English
  `StandardSubsystemsServer`) — БСП presence and version (parsed from
  `Функция ВерсияБиблиотеки()` / `Function LibraryVersion()`)
- `Subsystems/*.xml` — top-level subsystems
- `Catalogs/`, `Documents/`, `*Registers/`, `CommonModules/`, … — metadata
  counts

The file is tracked in `.ai-rules.json` like any other managed content. If
you edit it manually, the installer marks it `userModified` and stops
overwriting it. To pick up changes after editing `Configuration.xml`,
delete `openspec/project.md` and re-run `install.ps1 update`.

If the project is not a 1C source dump (no `Configuration.xml`), the bundled
fallback `project.md` remains with `unknown` values until real metadata is
available.

## Activating OpenSpec phases

The installer always places this shared workspace. Native OpenSpec commands
and matching SKILLs are additionally placed only when upstream ships
`content/openspec-bundle/<tool>/`: Cursor, Claude Code, Codex, OpenCode, and
Kilo Code in snapshot `1.2.0`. Kimi, Qwen, Command Code, Cline, and Pi have no
managed native bundle and use natural-language phase requests instead.

No `npm` or OpenSpec CLI is required for the natural flow. The installer copies
available bundle files during `init` / `update`; their snapshot version is
recorded in `.ai-rules.json` under
`integrations.openspec.artifactsBundleVersion`.

After installation you should already see, depending on which tools are active:

- Cursor — `.cursor/commands/opsx-{apply,archive,explore,propose}.md`
- Claude Code — `.claude/commands/opsx/{apply,archive,explore,propose}.md`
- Codex — only SKILLs under `.codex/skills/openspec-*/SKILL.md` (Codex has no project slash commands)
- OpenCode — `.opencode/command/opsx-{apply,archive,explore,propose}.md`
- Kilo Code — `.kilocode/workflows/opsx-{apply,archive,explore,propose}.md` (legacy path shipped by the upstream OpenSpec bundle; current Kilo Code auto-migrates `.kilocode/workflows/` to `.kilo/commands/` on startup — see `adapters/kilocode.yaml`)

…plus matching `openspec-{propose,apply-change,archive-change,explore}/SKILL.md`
folders under each bundled tool's skills directory. Restart the client for
native surfaces to take effect.

For a client without a native bundle, ask the agent to explore, prepare a
proposal, apply an approved change, or archive it in ordinary language. The
agent must read this workspace and the installed `sdd-integrations.md`, create
the same artifacts, and follow the same ITL preflight. Absence of native
shortcuts changes only invocation UX, not the OpenSpec artifact contract.

Use these phase requests verbatim when a native entrypoint is absent:

- explore: "Исследуй задачу в режиме OpenSpec, не создавая proposal и не меняя код";
- propose: "Подготовь OpenSpec proposal для `<изменение>`; создай proposal, design, tasks, test-plan и spec deltas; код не меняй";
- apply: "Реализуй согласованный OpenSpec change `<change-id>` по tasks.md и test-plan.md";
- archive: "Заархивируй принятый OpenSpec change `<change-id>` и синхронизируй specs".

### External OpenSpec CLI

The external CLI is not installed or updated by ITL. Do not run `openspec
update` over a managed project: it can overwrite pinned bundle files with
untracked versions. If the executable is absent, use the natural flow above.

## Workflow (default core profile)

```
propose <idea>   →  apply <change-id>   →  archive <change-id>
```

Invoke each phase through the installed native entrypoint when present, or
through the natural-language request above. `/opsx*` is not a universal client
surface.

1. **propose** — AI creates a new folder in `changes/<change-name>/` with
   `proposal.md`, delta `specs/`, `design.md`, and `tasks.md`.
2. **apply** — AI implements the tasks listed in `tasks.md`.
3. **archive** — completed changes merge into `specs/` and the change folder
   is moved to `changes/archive/<date>-<change-name>/`.

For deeper guidance see:

- Getting started — <https://github.com/Fission-AI/OpenSpec/blob/main/docs/getting-started.md>
- Workflows — <https://github.com/Fission-AI/OpenSpec/blob/main/docs/workflows.md>
- Commands — <https://github.com/Fission-AI/OpenSpec/blob/main/docs/commands.md>

## Integration with `1c-rules`

The detailed agent-side rules for how to read and update this folder live in:

- source repository: [`content/rules/sdd-integrations.md`](../content/rules/sdd-integrations.md)
- installed project: the canonical rules directory referenced from `AGENTS.md`

That file is loaded on demand whenever an SDD framework is detected in the project.

The installer also records the presence of this folder in
`.ai-rules.json` under `integrations.openspec` so other agents can detect it
without scanning the filesystem.
