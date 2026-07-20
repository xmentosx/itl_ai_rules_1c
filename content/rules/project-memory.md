---
description: Routing and quality rules for persistent project memory
alwaysApply: false
globs: []
---

# Project memory

Use two stores with no duplication.

## `memory.md`

Store a rule here only when it is simultaneously global to the project,
critical (violation risks production/data/security/compliance), stable across
tasks, and non-derivable from repository rules or official documentation. Do
not store TODOs, temporary agreements, subsystem trivia, style reminders, or
secrets.

## `remember` and `recall`

When `1c-templates-mcp` actually exposes these tools, use them for narrower
project facts, user corrections, object/subsystem quirks, recurring errors, and
their proven fixes. Recall relevant terms at the start of non-trivial work.
Write one self-contained English fact per note while preserving exact 1C names.

If the tools are unavailable, append useful corrections temporarily under
`## Captured during work (no remember available)` in `memory.md`, then migrate
them when the server returns.

Promote a remembered fact to `memory.md` only after it meets all four strict
criteria and remove the original. Demote a rule that no longer qualifies.
