---
description: Shared change-review contract — scope, 1C criteria (reuse, integration into the existing process, end-user readiness), verdict, second opinion, report and actions by role. Load for any code review, Soft gate C, Stage 4b or final OpenSpec review.
alwaysApply: false
category: quality
---

# Change Review Criteria

One owner for what a change review checks and reports, whoever reviews (parent or `1c-code-reviewer`). Launch conditions stay with `verification-delivery.md → Soft gate C`, `subagent-pipeline.md → Stage 4b`, `sdd-integrations.md → Apply until DoD is satisfied` and `subagents.md → Reviewer model gate`; severity words — `subagent-core.md → Report vocabulary`.

## Scope

Files or a selection named by the user are the scope as given. Otherwise take the change scope in this order:

1. **Project-provided scope** — when the project names how to obtain the review scope, use it and pass it as the explicit scope. When it asks to choose a range, relay its question and options to the user and rerun with the choice; never choose for them.
2. **User-named base** — `git diff <merge-base>` over tracked files (committed and uncommitted in one command) plus untracked files without ignored ones as a separate list.
3. Otherwise `CONFUSION` with candidate bases. The branch's own upstream (`@{u}`) is never a base: it shows only unpushed commits.

Review `src/cf/**` and `src/cfe/**` XML by changed objects and properties, not line by line, using the project-provided object list when available; exclude `ConfigDumpInfo.xml`. A scope too large for one context is read by objects; state the reduced coverage and never present it as complete. When the user asks to look only at recent changes, narrow the reading, not the scope, and say so.

**Self-review** (Soft gate C, the final OpenSpec review, review of code changed in this session): read the full diff only of files the current task changed and of dependencies it relies on (a call, shared object or shared test, each named); list the rest of the scope with a count as left for a separate review.

The report opens with the scope: base and its origin, code and test file counts, changed requirement sources, excluded counts by kind, coverage (read in full / by objects / counted only).

## What to check

- **Requirements** — from the OpenSpec change, task text or mockups; none found → state «requirement conformance not checked».
- **Correctness, regressions, security, data integrity** — tools: `tooling-playbooks.md → Code Review` (validator chain with BSL LS `review_1c_code`, ITS via `its_help` → `fetch_its`); standards: `coding-standards.md` index with `dev-standards-change-markers.md`, `standards(name="anti-patterns")`, `standards(name="platform-solutions")`, `standards(name="dev-standards-code-style") §8` and Quality Metrics. 1C specifics with their `standards(...)` owners: compilation directives and client-server boundaries, transactions, lock granularity and posting boundaries, query patterns, RLS and privileged mode, module regions, missing БСП usage, error handling, readability that blocks maintenance.
- **Architecture of the finished code** — `standards(name="dev-standards-architecture")` and `standards(name="anti-patterns") → Architectural Anti-Patterns`; record findings or «no findings» with the standard.
- **Reuse (C2).** Candidates: each new metadata object, new export procedure and procedure with business logic in an object, manager or common module; form handlers and trivial wrappers by judgment. Self-review confirms the search done while writing (`coding-standards.md → Code reuse`) and searches only what is missing, only for current-task candidates. A separate review runs one search per candidate (`search_function` for procedures, `ssl_search` for БСП) and `templatesearch` once per change. Result: `reused <API>` | `not found` | `rejected: <reason>` | `limited: <unavailable source and remaining gap>`; `not found` only after an actual search.
- **Integration into the existing process (C3).** For each new entry point (subscription, posting handler, command, scheduled job, new form or object event handler) find existing handlers of the same event: `find_objects_using_object` / `trace_impact` by object, `search_code` by key terms; the same `search_code` call looks for copies of the new procedure (characteristic lines, query text). Report «integrated into X» or «parallel branch next to X duplicating Y». Conditions inside an existing method are not banned; choose by the ratio of shared to diverging logic. A new procedure copying a significant part of an existing method (one business rule in two places) is `major`; a method whose flag parameter switches almost the whole body is `minor` unless it causes a defect; a large shared part with substantial divergence → recommend extracting it.
- **Architecture proposal (C4)** — only with evidence that the current architecture forced a workaround or duplication; state compatibility, migration path and cost. Separate report section, outside severity and verdict, never BLOCK. In full-cycle the user decides via `CONFUSION`; in a separate review it stays in the report.
- **End-user readiness (C5)** — for new objects and commands, statically: rights in roles (`bsp-access-rights.md` for БСП), subsystems and command interface, forms, defaults and settings, update handlers and initial filling when data already exists, message texts. A gap is `major`. Behaviour in the client — `verification-delivery.md → Soft gate D`; note whether confirmation exists.
- **Over-complexity (C6)** — mark unnecessary complexity with evidence; detailed taxonomy — `/ponytail-review`.

## Verdict and confidence

Confidence scale — `standards(name="anti-patterns") → "Confidence Scoring (for Reviews)"`; default policy — quality over quantity:

- **≥ 75** — report evidence-supported findings; whether they block merge depends on severity, not the score.
- **50–74** — label the finding unconfirmed and name the focused check needed to resolve it. A plausible data-integrity or security defect keeps its potential `critical` severity; it never becomes `minor` because confidence is lower.
- **< 50** — suppress unsupported speculation. A concrete potentially `critical` risk that cannot yet be closed belongs in open verification questions with its evidence gap and next check, not among confirmed defects.

Score confidence honestly and independently of impact. Severity describes consequences: `critical` (security / data-integrity failures or other delivery-blocking defects) / `major` (functional defects, readability blocking maintenance, measurable performance impact, best-practice violations affecting downstream code) / `minor` (style and naming nuances, refactor candidates without a measurable defect). Status: ❌ BLOCK — a confirmed `critical` or `major` defect, or a concrete potentially `critical` risk awaiting a required check; ⚠️ CONCERNS — minor findings or other explicitly unconfirmed concerns; ✅ APPROVE — no findings or unresolved material verification questions. State whether a block is a proven defect or missing evidence. `1c-arch-reviewer` keeps its own status rule for a design review.

## Second opinion

For payroll, regulated accounting reports, government-service integrations, primary-document generation and financial reconciliation, run `ask_1c_ai` (1С:Напарник) on the risky segment with the same review prompt. Findings from both providers still need evidence; a finding from one provider gets the focused check that confirms or rejects it. Name the source of each finding. Tool off, absent or failed (`tool-policy.md`) → «second opinion not obtained: <reason>», not blocking. Self-review asks only about current-task candidates.

## Report

Per finding: `file:line`, issue, evidence (or the missing evidence), rule, fix or next check. Skeleton:

```markdown
## Code Review Result
**Scope:** base, origin, counts, coverage
**Status:** ✅ APPROVE / ⚠️ CONCERNS / ❌ BLOCK

### [critical | major | minor] Title (confidence: XX%)
**File:** `Module.bsl:45` · **Issue:** · **Evidence:** · **Rule:** · **Fix / next check:**

## Reuse and integration (C2, C3)
## Proposals (C4)
## Open questions
## Positive findings
```

## Actions by role

- Parent in full-cycle and OpenSpec apply: fix `critical` / `major`, and each `minor` in lines the current task added or changed when the fix is local (no behaviour, file or object outside the task; no check beyond the task's own). Recheck the affected scope after any fix. List every other `minor` with a reason: `outside the task`, `needs checks outside the task` or `judgement call — user decides`.
- Subagent: report only; mark each `minor` `local fix` or with a reason above.
- A separately requested review: report only; change code only when the user asks. Mark `minor` the same way, so «fix them» covers the local ones. If this session changed code in the scope, it is a self-review: say so and recommend a separate chat.

## Evidence

Reuse only tool results the reviewer observed in its own session against unchanged content. The author's report is the subject of the review, not evidence: re-run such claims or mark them unverified.

- **Gate 1.** A pass the project recorded and bound to the current content is evidence, not the author's report. Without it, recommend that check in the development chat rather than starting it here; Gate 1 then rests on the review's own validator calls or is unverified.
- **Gates 2–3 on a large scope** (marked large by the project, or beyond one context): run them by text on changed procedures chosen by risk (transactions, posting and locks, data writes, privileged mode, public API); report the rest with a count as «not checked automatically».
