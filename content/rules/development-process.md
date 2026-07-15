---
description: Detailed task triage, clarification, implementation, verification, and delivery process
alwaysApply: false
globs: []
---

# Development process

Load this rule for implementation, fixes, refactoring, metadata work, or
OpenSpec authoring. The concise hard gates remain in `AGENTS.md`.

## Triage

Use quick-fix only for one local BSL routine or a new isolated metadata object
that is not consumed by code, forms, queries, RLS, fill checks, jobs, or event
subscriptions in the same change. A new independent register (no registrar,
small dimensions/resources, no module), defined type, enumeration, constant, or
unwired attribute can qualify.

Promote to full-cycle for transactional/write/posting paths, public common
module exports, adopted extension objects, permissions/RLS, event subscriptions,
scheduled/background jobs, architecture, multiple modules, or metadata wired
into existing behaviour. Split an isolated metadata addition from later wiring
when that keeps both changes safer.

Docs-fix skips BSL validators and verifies paths, links, anchors, naming, and
internal consistency. Spec-authoring also verifies every concrete 1C fact with
MCP evidence and follows `sdd-integrations.md`.

## Clarification

Explore repository and available evidence before asking. When an unresolved
choice materially changes behaviour, compatibility, or data handling, use:

```text
CONFUSION: <specific conflict>
Options:
  A) <option> — <trade-off>
  B) <option> — <trade-off>
→ Which one to pick?
```

Do not use this format for facts discoverable from code, metadata, docs, or
runtime state. Batch questions and stop dependent implementation until answered.

## Implementation discipline

1. State the observable goal and relevant assumptions.
2. Identify exact modules/files and downstream consumers.
3. Prefer minimum code and existing project patterns.
4. Preserve unrelated formatting, APIs, user files, and behaviour.
5. Handle realistic failure/data cases without speculative abstractions.
6. Remove only imports/variables/code made unused by this change.

Public procedures/functions and non-obvious critical logic require useful
documentation. TODOs are allowed only as task-linked technical debt under the
project coding standards.

## Verification

Choose checks from the change surface:

- BSL: syntax plus relevant semantic/code review within the MCP budget.
- Metadata XML/forms: schema/examples, `verify_xml`, UID/reference integrity.
- Behaviour: focused unit-like/integration/UI scenario and boundary case.
- Docs/rules: links, paths, indexes, budgets, and contradiction search.
- Refactor: lock observable behaviour before and after.

For a quick-fix, define one focused regression scenario before editing: previous faulty behavior, triggering action, expected fixed result, and verification type. Add a second scenario only for a separate meaningful boundary. A pre-change failing run is useful only when it is cheap and adds diagnostic value; never require two complete executable gates merely to prove the same defect. The generic checks in this rule are a verification floor, not a ceiling: project gates in `USER-RULES.md` win. If the project requires Vanessa Automation and a fresh executable gate, syntax checking alone is insufficient. If the fix cannot be expressed as one local scenario, or it affects architecture, a public API, related metadata, or several behaviors, promote it to OpenSpec. Before the first `.feature` edit read the local `VANESSA-TESTS-GUIDE.md`; do not claim completion without the project-required regression test and one fresh passed final gate. If automation is technically impossible, stop with the concrete blocker.

Review correctness, edge cases, security, transaction/lock boundaries,
compatibility, and downstream impact. Re-run a validator only after changing the
validated artifact. A required failed/stale gate blocks completion.

## Delivery

Summarize purpose and outcome, list changed files, report exact verification,
and call out only real remaining risk or manual follow-up. Never hide preserved
user-modified files, partial migrations, skipped checks, or rollback conditions.
