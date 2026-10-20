---
description: Evidence and bounded recovery for unusable AI validation responses and disputed findings
alwaysApply: false
category: quality
---

# AI validation evidence and disputed findings

Load before acting on any Gate 2/3 finding, timeout or unusable response. This is the canonical exception
to their unchanged-code repeat rule and clean-response criterion. It does not
replace standalone syntax, metadata, impact, runtime or host ITL verification.
Treat AI output as evidence to assess; neither its severity nor disagreement
with it alone proves a defect or a false positive.

## Preserve the validation unit

Before deciding or retrying, retain the exact submitted code and required context,
their SHA-256 hashes, source revision/effective-tree identity, relevant metadata
and platform version, validator identity, exact call parameters, time, call count
and the complete raw response. Reference artifacts rather than copying secrets
into the report. Keep every original response; never replace a failed response
with a later one or edit a host proof/state file to manufacture acceptance.

Give each finding a stable ID tied to that response, original text/severity,
source references and proposed correction. Preserve "must fix" and other severity
wording as the provider's claim, separately from the assessed disposition and
blocking decision. Assess before editing or blocking: a provider label alone
cannot establish a product defect. A clean later response does not erase earlier
unresolved findings.

## Unusable response: unsupported-result

An empty response, links without an analysis of the submitted code, analysis of
a different unit, or missing substantive output is `unsupported-result`, never
a clean review. Links accompanying an actual finding are not automatically an
unusable response; assess that finding. Missing substantiation makes a claim
`unsupported-claim`, not a confirmed defect; retain it and apply the blocking
criterion below rather than discarding the response.

For Gates 2/3 only, allow one recovery call for an unusable response per validator
and validation unit, subject to explicit user limits in
`verification-policy.md → Necessary AI calls and user limits`.
Record `reason=unsupported-result`, the unusable call ID, unchanged input hashes
and any explicit remaining user allowance before the recovery call. This policy authorizes
that bounded unchanged-code recovery; another user confirmation is unnecessary.
It does not reset call history or extend an explicit user limit. A prior recovery counts.
Keep normal ordering and serial calls; do not split a unit or switch to overlapping
snippets to obtain more attempts. Transport uncertainty follows the tool's
documented status/recovery route, not an automatic duplicate execution.

If the recovered response is still unusable, or an explicit user limit prevents continuation, report
the gate as unverified with its artifacts and concrete next action. Do not report
the tool as unavailable when it is exposed but returned unusable evidence.
Necessary continuation follows `verification-policy.md → Necessary AI calls and user limits`
without a separate numeric-budget question. Diagnose a repeated unusable result
and change the relevant input, context or failed prerequisite before a new check;
do not renew the unchanged-input recovery or loop for green text.
A real defect found on the last explicitly permitted call still needs correction and
fresh confirmation; exhaustion does not waive either requirement.
For unusable evidence, use the same policy-dependent continuation below, recording
`unsupported-result` rather than misreporting a transport failure.

## Timeout and failed validation

A timeout is a failed validation attempt, not a finding against the code or proof
that the whole MCP server is unavailable. Preserve call/input identity, raw error,
elapsed time and dispatched-call count. Keep remote completion unknown until the
tool's documented status/recovery evidence resolves it; never automatically replay
an unknown call, switch Gate 2 aliases to duplicate it, or wait indefinitely for it.

Resolve `TOOL_CHECKER` through `tool-policy.md`:

- `auto`: perform the applicable compensating checks in
  `verification-gates.md → Graceful degradation for Gates 1–3`, record the AI gate
  as `unverified` with the actual failure, and continue the authorized task.
  Timeout alone does not stop development or delivery, require a waiver, or start
  an AI retry loop. A later check needs a concrete information gap and permission;
  it does not erase the failed attempt or bypass unknown-completion protection.
- `required`: the selected failed capability remains incomplete and blocks its
  dependent step; alternatives gather evidence but do not satisfy that requirement.
  Continue independent work. Never downgrade the setting or fabricate a pass.
- `off`, explicit user limits and host delivery/safety guards retain their owners.

Compensation does not close a confirmed defect or a concrete potentially critical
risk. Keep those decisions separate from tool failure. Unknown remote completion
limits duplicate execution, not independent local review or authorized work.

## Assess substantive findings

Record one disposition for every finding:

| Disposition | Required treatment |
|---|---|
| `confirmed-defect` | Correct within authorized scope; obtain fresh applicable confirmation under the task's explicit user limits. |
| `disproven-finding` | Retain a concrete contradiction and an allowed decision below; do not apply a harmful or unnecessary suggested edit. |
| `unsupported-claim` | Retain the claim and missing evidence; it is non-blocking unless the concrete potentially critical risk criterion below is met. |
| `inherited-or-out-of-scope` | Record provenance and scope; this does not automatically discharge a blocker or authorize unrelated changes. |
| `unresolved` | State the specific missing fact or decision; use the blocking criterion below, not the provider's severity alone. |

Block only for a confirmed applicable material defect, a concrete potentially
critical data-integrity/security risk awaiting a necessary check, or an explicit
required capability/host guard. For a defect, record the exact source/path, reachable
trigger, actual versus required result and the source of that requirement.
For a potential critical risk, record the plausible reachable path, consequence
and focused missing check; a generic "could fail" is insufficient.
Do the bounded source/contract check before classifying an unsupported claim;
do not relabel a known defect to continue. Unsupported speculation, style/naming
nits and proven false positives do not block and do not require user approval.
Record non-blocking uncertainty without claiming it is disproven or verified.

For a disproven finding, retain the counter-evidence/reproducer, exact source
locations, relevant primary documentation, decision authority, decision time and
rationale. State why the evidence contradicts the original claim, not merely why
the suggested edit seems undesirable. Passing unrelated tests, a second AI's
opinion, a low confidence score or the agent's assurance is insufficient.

The implementing agent may decide autonomously only when the claim is refuted
by a mechanically checkable contradiction in the exact submitted unit/context:
for example a documented language rule with a matching minimal reproducer, or
an alleged missing guard whose relevant execution path is demonstrably guarded.
Record `authority=policy-mechanical` and the actual check/evidence. Ensure that
required context was supplied; if it was missing, inspect the complete relevant
unit/context before deciding rather than dismissing the finding. This is not an
automatic requirement for another AI call. Merely finding a similar guard
elsewhere does not meet this criterion.

An unresolved requirement that prevents a safe decision, acceptance of a real
risk or an inherited blocking defect requires a concrete decision by the
authorized user/reviewer after available focused checks. An unsupported model
assumption alone does not require that decision. Prepare the evidence first,
then ask only for the unresolved decision, explaining this rule and why it is
needed. Existing explicit authorization for that exact risk may be reused. General
permission to implement or finish the task is not a risk waiver. Do not label
risk acceptance as a false positive or claim that an unresolved defect was fixed.

## Confirm a correction

Fresh confirmation of a confirmed defect is mandatory, but in `auto` another
answer from the same AI is not the only admissible proof. Use a focused reproducer,
test, complete execution-path analysis or applicable primary contract that
demonstrates the corrected result on the current unit and covers the change's
relevant regressions. Bind it to the changed source/context and finding ID.
Record defect confirmation separately from the AI gate: alternative evidence
does not manufacture a clean AI pass or close a `required` provider obligation.
Preserve standalone syntax, impact, metadata, runtime and host proof requirements.
For mixed answers, retain every finding, close only those actually resolved,
and re-evaluate affected rebuttals. Do not accept proposed replacement code merely
because it repairs one finding; check existing guards and contracts it could lose.

## Gate outcome and freshness

- `clean-tool-response`: substantive current evidence has no applicable blockers,
  and no earlier blocking findings for the same relevant state remain open.
- `adjudicated-false-positive`: substantive current evidence has been assessed,
  and every remaining blocking finding is disproven with an allowed recorded
  decision. Report acceptance with adjudicated findings, not a clean AI pass.
- `unverified`: unusable evidence, incomplete finding inventory, missing authority,
  unsupported/unresolved blockers, stale inputs or damaged evidence. State the
  cause and next action. This is not a pass. It does not itself impose a delivery
  veto: apply the assessed blockers, `TOOL_CHECKER` continuation above and the
  existing host delivery policy. Non-blocking unsupported claims remain visible.

A separately authorized risk exception must be reported as such under the host's
applicable delivery policy; it is neither outcome of successful AI verification.
No exception here overrides data-integrity, wrong-target or false-proof guards.

Bind every decision to the input/context and raw-response hashes. Recompute those
bindings before reuse. A relevant source/context change invalidates affected
decisions; changed or missing evidence cannot be reused. Preserve valid evidence
for unaffected units. For a mixed result, fixing a true defect still requires
fresh confirmation of the changed unit; re-evaluate whether earlier rebuttals
remain applicable. Do not repeat an unchanged valid review just to remove the
text of already adjudicated findings.

In the final report and handoff, record the outcome, validation-unit identity,
call counts, artifact references, each blocking disposition and its authority,
and any remaining action. Parent agents reuse this complete evidence under the
same freshness checks. Unchanged runtime evidence may be reused when its own
host contract permits; interpreting a review alone is not a reason to rerun 1C.
