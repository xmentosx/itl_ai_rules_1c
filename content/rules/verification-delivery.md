---
description: Verification delivery gates — reproduction, plan adherence, full-cycle review, UI confirmation, and final report
alwaysApply: false
category: quality
---

# Verification Delivery — Soft Gates and Reporting

**When to load this file:** after hard gates, for reproduction, plan adherence, testing, review or delivery.

Hard validator, impact, and XML gates live in `verification-gates.md`; task depth and triage live in `verification-policy.md`.

## Soft gates — run when applicable

These gates are not always required, but their absence in the listed scenarios is a defect.

### Soft gate A — Reproduction case (debug tasks only)

For any change that originated as a bug fix:

- The exact reproduction case from `standards(name="systematic-debugging") → Phase 1` was rerun **after** the fix and no longer triggers the symptom. For fast-path fixes (`standards(name="systematic-debugging") → Fast path`) the original failing scenario (from the error message, the user's report, or the log entry) serves as the reproduction case — re-check it after the fix.
- The reproduction case is documented in the delivery summary so the user can verify it.
- All temporary `ЗаписьЖурналаРегистрации("Debug.*"`, `ПоказатьЗначение`, breakpoints, hard-coded test values introduced during debugging were removed.

### Soft gate B — Plan adherence (any change with a written plan)

Triggers — apply this gate when any of the following is true:

- The change went through `subagent-pipeline.md` (Stage 4a "spec-compliance review").
- The change is an OpenSpec **apply** of an active proposal — there is a `openspec/changes/<id>/tasks.md` (and optionally `design.md` / `proposal.md` / delta `specs/`).
- The user explicitly approved a written plan in chat before implementation (numbered steps, file paths, verification points).

Checklist (same shape regardless of plan source):

- Every task / step in the plan was executed; no task was silently skipped.
- The diff against the plan was summarized file by file in the delivery report (use `git diff --name-only` to verify).
- No file outside the plan was edited; if it was, the deviation is explicitly justified in the delivery summary.
- OpenSpec: reconcile DoD with current verification/review evidence before completion (`sdd-integrations.md`). Checkboxes and CLI `all_done` alone never suffice; record explicit waivers and unfinished criteria. Update deltas when behaviour changes.
- For the subagent pipeline specifically: Stage 4a (spec-compliance review by the parent agent) was executed and passed before Stage 5. **Reuse its evidence** — when 4a passed after the latest edit, this gate is satisfied by confirming that result is still fresh; do not re-run the file-by-file diff comparison (same principle as `verification-gates.md → "Gate execution and evidence reuse"`).

### Soft gate C — Code review

Full-cycle: review is required unless the user explicitly prohibits it; otherwise only when requested. The parent reviews requirements, correctness, regressions and security. Invoke `1c-code-reviewer` only on explicit request with the reviewer model gate satisfied (`subagents.md`). Fix critical / major findings; report minor ones. Reuse fresh evidence. Disabling the subagent does not waive review or MCP gates.

### Soft gate D — UI confirmation policy

Before reporting ready/done, confirm the agreed task outcome with sufficient expected-vs-actual evidence. Select the method during existing triage by the changed behaviour and the material error that would remain undetected without UI observation; static checks/review alone do not prove runtime behaviour.

| Change / unresolved risk | Sufficient behavioural proof |
|---|---|
| Internal calculation, query, background work or refactoring with unchanged interaction/presentation | Focused unit, integration or data checks; a displayed result alone does not require opening its unchanged form. |
| Local label, visibility, command availability or form defect | Observe the affected control/action and relevant states; no unrelated end-to-end walkthrough. |
| New or materially changed user workflow, screen or setup | Follow the principal user path in the target client through its observable outcome, including first use / missing saved settings when affected. Use representative data and relevant roles/states. |
| Presentation covered by an originally agreed mockup/prototype | Compare the affected commitments with the reference under comparable viewport/settings; check interaction as well when changed. |

Observe whether the user can find/start the action, supply needed input, finish it and understand the result where those aspects are affected. Inspect the actual target UI when the criterion depends on it; a packaged/browser preview is supplementary to native-client acceptance and must be labelled accurately. Do not fabricate business data to imitate a mockup. Explain platform-control differences; pixel equality is required only when agreed. Resolve material deviations from the agreed interaction or reference before claiming completion rather than silently replacing the criterion with the implementation.

An unfinished agreed scenario, a material reference mismatch or a usability obstacle preventing that scenario is an in-scope defect. Alternative styling, extra convenience and new capabilities beyond satisfied requirements are optional follow-ups; do not expand acceptance to an unattainable ideal. Fix and recheck affected defects, reuse fresh unaffected proof, and diagnose repeated failure instead of repeating an unchanged run. Missing required observation remains unverified with its exact prerequisite; a test count, screenshot file or implementation checkbox alone is not acceptance.

Use the existing plan, DoD and evidence assessment; add no separate gate, required document or per-edit retained UI suite. Current one-off proof is sufficient when accepted by the evidence owner. This applicability decision does not waive approved criteria or independently required checks.

`/uitests` sets `UI_TESTING`: `essential` / empty = the important new or changed user-visible behaviour requiring UI proof above, automatically once the change is on the dev/test base; `auto` = every applicable scenario automatically; `manual` = explicit request; `off` = no routine UI execution, with a named invocation override subject to the broader current no-UI scope. Routes: the installed Vanessa UI route for managed ITL projects; QA MCP first and the web client (`INFOBASE_PUBLISH_URL`) as fallback for standalone projects. Canon: `dev-standards-env.md`; routes and drivers: `ui-testing-tools.md`. Unconfirmed essential DoD scenarios stay unverified (`sdd-integrations.md`). Saved Vanessa suites remain independently governed by `ITL_VANESSA_TESTING`; neither policy nor interactive UI evidence substitutes for fresh helper-owned completion/export evidence.

## Delivery summary — what the user sees

After all gates pass, the delivery report MUST contain:

1. **What was done** — 1–3 lines, no preamble. State the observed task outcome and sufficient proof; for applicable UI/reference checks, identify the checked scenario/part and material deviations. Distinguish implementation from verified usability; separate unfinished requirements from optional polish.
2. **Files changed** — every path in backticks, one line per file describing the nature of the change.
3. **Context sources** — required for non-trivial BSL / metadata changes (per `mcp-policy.md → A.3`). List the sources actually used (templates, project code, metadata, platform / БСП / ITS docs, ITS standards) and briefly state why any normally relevant source was skipped. Skipping a relevant source silently counts as a defect. Omit this section only for docs-fix / quick-fix tasks where no BSL / metadata change was made.
   - **Metadata tooling** — when the change mutated metadata / forms / layouts, one line naming the execution path: `Metadata tooling: <1c-metadata-manage tool / 1c-metadata-manager>` or `hand-edit — <documented exception>` (hard gate — `AGENTS.md → Skills and Subagents`, exceptions — `content/skills/1c-metadata-manage/SKILL.md → Hard rule`). Name a preview only when one actually ran (`… (preview shown, then applied)` — `content/skills/1c-metadata-manage/docs/edit-preview.md`). Most writes carry no preview clause (`METADATA_PREVIEW=auto` reserves it for the risky cases), and its absence is not a gap.
   - **Docs** — when a claim about platform behaviour, an API signature or a development standard came from documentation rather than from the project's own code, one line naming what answered and for which platform: `Docs: docsearch "ЗначениеЗаполнено" → ОбщегоНазначения (8.3.27)`, `Docs: standards(name="dev-standards-code-style")`, `Docs: its_help + fetch_its <document>`. The point is that the reader can reopen the same page: name the tool and the document, not "the documentation says". A version-sensitive answer without a platform version is incomplete — say which version the page applied to, and say so explicitly when it differs from the project's. Omit the line only when no documentation was consulted, which for a version-sensitive claim is itself a gap worth stating under **Risks**.
4. **Risks / nuances** — only real ones. For tool-dependent gaps name the `TOOL_*` policy, actual state (disabled / absent / failed / unsuitable scope), fallback evidence and remaining unverified requirement. `required` remains incomplete; `off` is never reported as a passing check. Use `verification-gates.md` wording for degraded gates. Omit when no risk applies.
5. **Follow-ups** — any defects observed but **not** fixed (out-of-scope dead code, pre-existing lints, downstream callers flagged by Gate 4 that need future review). Empty = omit.

**Evidence lines are conditional, never placeholders.** Each of `Memory:`, `Template:`, `Docs:`, `Metadata tooling:`, `IB tooling:`, `Repository tooling:` appears only when its channel applied to this task: `Memory:` on every non-trivial task (`project-memory.md → Gates (hard)`); `Template:` whenever `templatesearch` ran or was owed (`mcp-policy.md → A.9`, including «no fitting template»); `Docs:` when documentation answered a claim; the three tooling lines only when a metadata mutation, infobase operation or repository operation happened. Never write `IB tooling: n/a` or similar filler — an absent line already means «not applicable». A typical quick-fix delivery is: what was done, the file, the validators run, the `Memory:` line, and Risks only if real.

Do not include in the delivery summary:

- a retelling of the user's request;
- a list of which tools you called (unless that list IS the **Context sources** section above);
- thanks, apologies, introductions, conclusions;
- markdown sections added "for structure" with no content.

**Package instead of an edit.** When a person must apply the change (vendor lock kept, ordinary form, repository lock held by someone else, MCP-only sources) or the user asks for a diff / review, the deliverable is the package of `content/skills/1c-change-package/SKILL.md`.

## Anti-patterns

- **Skipping Gate 1** "because the edit was tiny" — `syntaxcheck` is the cheapest gate; skipping it never saves time.
- **Running gates in the wrong order** — running `check_1c_code` before `syntaxcheck` wastes the AI checker on syntax-broken code.
- **Looping on AI non-determinism** — if `check_1c_code` returns different items each run on the **same** code, take the strictest set and stop. Do not burn the 3-call budget on noise.
- **Marking the task done** with un-removed `Debug.*` log entries or temporary `ПоказатьЗначение` calls — soft gate A failure.
- **Auto-running `1c-code-reviewer`** when the user did not ask — soft gate C failure, and a direct violation of `subagents.md`.
