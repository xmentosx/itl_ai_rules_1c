---
description: Closed deploy → test → fix → redeploy loop against the test infobase, until the scenarios pass or the iteration budget is exhausted
argumentHint: "[<scenario / task description>] [--iterations N]"
---

# /test-fix-loop — deploy → test → fix → redeploy until green

**ITL managed project (`.agent-1c/project.json`):** route a named scenario set
through the installed helper's `scenario-loop` repair kind. Record the requested
scenarios and their expected outcomes. Reuse an existing Vanessa `.feature` and
optional tag filter when they cover that exact scope. Otherwise author the
smallest executable transient `.feature` under the project's ignored
`.agent-1c/verification/scenario-loop/` directory using the existing Vanessa
steps and authoring rules; check that Git ignores its path. Preserve that file
through the repair session and any evidence or diagnosis that references it.
It is current proof, not retained regression coverage; do not add it to a
retained suite merely to make the command run. If the requested behavior cannot
be represented by a reliable executable scenario, report that prerequisite
before any load or test. Start once with
`run-itl-command.ps1 -- -Action begin-verification-repair -VerificationRepairKind
scenario-loop -VanessaFeaturePath <path> [-VanessaFilterTags <tags>]
[-VerificationRepairMaxAttempts N]`. The default is three rounds; explicit `N`
applies to a new session only. Pass the path as one quoted argument, including
when it contains spaces and Cyrillic. Keep the returned session ID. For each round use
`run-itl-command.ps1 -- -Action check-dev-branch -VerificationTrigger repair
-RepairSessionId <id> -VanessaFeaturePath <same-path> [-VanessaFilterTags
<same-tags>] -ExplicitVerificationComponent vanessa`. If the user's authorization
also covers all due components while their project execution switches are off,
use `-ExplicitVerificationComponent all` for that invocation. The helper owns
one base update, a focused Vanessa diagnostic and the subsequent unfiltered
assessment in the same persisted attempt. Only fresh full evidence completes
the session. If the obligation is classified as one-off, record its result through
the installed `begin-one-off-proof` / `complete-one-off-proof` route before
claiming export readiness; a passed diagnostic alone is not that receipt. On
failure, diagnose and change the relevant input before repeating
the same ID and scope; deploy recovery never resets the outer budget. A broad
no-UI instruction still needs explicit lifting, and neither invocation changes
the stored execution switches. The standalone procedure below applies only
outside managed ITL projects.

Run the requested test scenarios against the test infobase and, when they fail, close the loop: diagnose → fix the code → redeploy → re-test — until every scenario passes or the iteration budget runs out. This is the *outer* loop over test failures; the *inner* retry loop for deploy errors stays where it lives (`/update1cbase → Update retry loop`) and does not consume test iterations.

**Strictly opt-in.** This loop runs only when invoked as a command or explicitly requested in words; `UI_TESTING=essential` / `auto` enable routine UI verification, not this repeated deploy/fix loop. An exact `/test-fix-loop` request authorizes its named UI run for this invocation under `manual` or `off` without changing the project setting. A broader current no-UI instruction must be lifted explicitly first. Target and provider prerequisites still apply. Web-client iterations are token-expensive — on that route state the expected cost once at the start.

## Step 0. Prerequisites

Parameters, classes and defaults — `content/rules/dev-standards-env.md §1`; Defaulted keys are never asked for. Blocking for this command: `PLATFORM_PATH`, `INFOBASE_PATH`, **and a UI route** — QA MCP with a test client of the infobase, or `INFOBASE_PUBLISH_URL` for the web client (without either there is nothing to loop over — stop and ask). The dev/test-target confirmation of `/deploy-and-test` applies unchanged.

Scenario set: taken from the argument / user request. Do not invent scenarios beyond what was asked; one scenario per user-visible behavior, in the template of `content/agents/tester.md → Test Scenarios`.

**EDT projects** (`.dev.env` `USE_EDT=true`): the deploy step keeps a single owner per `content/rules/edt-workflow.md`.

Iteration budget: `--iterations N` or a number stated in the request; default **3** (mirrors the update-retry budget). Route and driving rules — via `/deploy-and-test` Step 4: QA MCP (`1c-qa-testing` skill, `qa-testclient.md`; a fresh test client after every redeploy), else the web client (`ui-testing-tools.md`, `web-client-driving.md`, including the two-attempts anti-loop limit inside the browser).

## The loop (per iteration)

1. **Deploy.** Run `/deploy-and-test` Steps 0–3 (its command lines, tool selection, and retry loop are the single source of truth). Full-snapshot mode when `EXTENSION_NAMES` is configured, single-target otherwise. If the deploy retry loop exhausts its own budget, the whole command stops with its failure report — a broken deploy is not a test failure.
2. **Test.** Run the scenario set per `/deploy-and-test` Step 4 / the `1c-tester` workflow.
   - Iteration 1: the full requested set.
   - Later iterations: only the previously failed scenarios, **plus** any previously passed scenario whose covered area was touched by the fix (use the impact-analysis evidence from Gate 4 of `verification-gates.md` to decide; when in doubt, re-run the scenario).
3. **All green → exit** to the final report.
4. **On failure — fix before the next iteration.** Diagnose per `standards(name="systematic-debugging")` (the `DEBUG_FAST_PATH` fast path applies). Fix through the normal development procedure — triage quick-fix vs full-cycle per `AGENTS.md`, delegating to `1c-error-fixer` when delegation is warranted (`subagents.md`). Run the applicable Gates 1–3 on every touched module **before** redeploying. Re-deploying unchanged sources is forbidden — the same no-change-repeat rule as everywhere else; an iteration without a fix is a wasted iteration and a defect.
5. Next iteration (back to 1) while the budget allows.

## Hard rules

- **Every iteration must change something** — a code/metadata fix, a corrected scenario precondition, or a corrected test step proven wrong by evidence. "Try again, maybe it passes" is forbidden.
- **A scenario is not massaged into passing.** If the expected result was wrong, say so explicitly and get the user's confirmation before changing the expectation; silently weakening an assertion is a defect.
- **Budget exhausted → honest stop.** Report the remaining failures with reproduction steps, screenshots/log fragments, the fix applied in each iteration, and a recommendation. Never present a red loop as done.

## Final report

An iteration table — per iteration: deployed git state, scenarios run, pass/fail per scenario, one-line fix summary — followed by the standard test report (`tester.md → Test Report Format`) for the final state, and the `IB tooling:` line required by `AGENTS.md → Skills and Subagents`.
