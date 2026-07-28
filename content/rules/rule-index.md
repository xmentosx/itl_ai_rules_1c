---
description: On-demand index for 1C development, tooling, workflow, metadata, and quality rules
alwaysApply: false
globs: []
---

# On-demand rule index

Load only rules matching the current task.

## Development and architecture

- `coding-standards.md`: mandatory index before BSL/metadata authoring or review.
- `dev-standards-core.md`: parameters, formatting, naming, comments, headers.
- `dev-standards-architecture.md`: cross-module architecture and platform patterns.
- `module-structure.md`: new or restructured modules.
- `extension-patterns.md`: extension interceptors and adopted objects.
- `locks-and-transactions.md`: transaction boundaries, managed locks, deadlocks.
- `logging-strategy.md`: integrations/jobs/rollback logging without secrets.
- `registers-design.md`: information/accumulation/accounting/calculation registers.
- `dcs-design.md`: Data Composition System reports.

## Forms and metadata

- `forms.md`: entry point for managed-form work.
- `forms-add.md`: create or significantly change a form.
- `forms-events-add.md`: form event wiring.
- `form-module.md`: form-module BSL.
- `form-reserved-names.md`: forbidden local names in form modules.
- `dev-standards-forms.md`: form presentation and programmatic changes.
- `async-methods.md`: `Асинх`/`Ждать`/promises and async client workflows.
- `metadata-xml-workarounds.md`: direct metadata/form XML pitfalls.

## Tooling, workflow, and integrations

- `tooling-playbooks.md`: minimum MCP sequence by task type.
- `mcp-first-search.md`: structural search before local grep.
- `getconfigfiles.md`: extract configuration objects from an infobase.
- `integrations-add.md`: HTTP/REST/queue/external integrations.
- `refactor-add.md`: safe refactoring sequence.
- `sdd-integrations.md`: mandatory OpenSpec evidence and phase rules.

## Quality and diagnosis

- `verification-checklist.md`: completion gates for non-trivial changes.
- `systematic-debugging.md`: reproduce, hypothesize, experiment, fix.
- `anti-patterns.md`: review/performance/anti-pattern catalog.
- `platform-solutions.md`: proven platform pitfall patterns.

## Subagents

- `subagents.md`: role catalog, delegation thresholds, model tiers.
- `subagent-pipeline.md`: full-cycle delegated pipeline; skip for quick fixes.
