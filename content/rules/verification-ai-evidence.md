---
description: Evidence and bounded recovery for unusable AI validation responses and disputed findings
alwaysApply: false
category: quality
---

# AI validation evidence and disputed findings

Load for an unusable or disputed Gate 2/3 response. This is the canonical exception
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
source references and proposed correction. Report wording such as "must fix" as
blocking when that is the response's stated disposition even without a structured
severity field. A clean later response does not erase earlier unresolved findings.

## Unusable response: unsupported-result

An empty response, links without an analysis of the submitted code, analysis of
a different unit, or missing substantive output is `unsupported-result`, never
a clean review. Links accompanying an actual finding are not automatically an
unusable response; assess that finding. Missing substantiation for a substantive
blocking claim is an unresolved finding, not permission to discard the response.

For Gates 2/3 only, allow one recovery call for an unusable response per validator
and validation unit within the current authorized call budget (default standard:
2; full: 3; extensions follow `verification-policy.md → Task grants for additional AI calls`).
Record `reason=unsupported-result`, the unusable call ID, unchanged input hashes
and remaining allowance before the recovery call. This explicit policy authorizes
that bounded unchanged-code recovery; another user confirmation is unnecessary.
It does not reset the budget or add a call. An already authorized recovery counts.
Keep normal ordering and serial calls; do not split a unit or switch to overlapping
snippets to obtain more attempts. Transport uncertainty follows the tool's
documented status/recovery route, not an automatic duplicate execution.

If the recovered response is still unusable, or the budget is exhausted, report
the gate as unverified with its artifacts and concrete next action. Do not report
the tool as unavailable when it is exposed but returned unusable evidence. An
additional allocation follows `verification-policy.md → Task grants for additional AI calls`:
an applicable explicit task grant permits a finite next block without another
numeric question; otherwise obtain a bounded user decision. Allocation alone
does not authorize another unchanged-input recovery; do not loop for green text.
A real defect found on the last available call still needs correction and
fresh confirmation; exhaustion does not waive either requirement.

## Assess substantive findings

Record one disposition for every finding:

| Disposition | Required treatment |
|---|---|
| `confirmed-defect` | Correct within authorized scope; obtain fresh applicable confirmation within the remaining budget. |
| `disproven-finding` | Retain a concrete contradiction and an allowed decision below; do not apply a harmful or unnecessary suggested edit. |
| `unsupported-claim` | Evidence is insufficient to confirm or disprove it; a blocking claim remains open. |
| `inherited-or-out-of-scope` | Record provenance and scope; this does not automatically discharge a blocker or authorize unrelated changes. |
| `unresolved` | State the specific missing fact or decision; the affected gate remains open. |

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
required context was supplied; a reviewer missing essential context requires a
complete-unit validation, not dismissal of its finding. Merely finding a similar
guard elsewhere does not meet this criterion.

Ambiguous business meaning, an unproven platform assumption, acceptance of a real
risk or an inherited blocking defect requires a concrete decision by the
authorized user/reviewer. Prepare the evidence and recommended disposition first,
then ask only for the unresolved decision, explaining this rule and why it is
needed. Existing explicit authorization for that exact risk may be reused. General
permission to implement or finish the task is not a risk waiver. Do not label
risk acceptance as a false positive or claim that an unresolved defect was fixed.

## Gate outcome and freshness

- `clean-tool-response`: substantive current evidence has no applicable blockers,
  and no earlier blocking findings for the same relevant state remain open.
- `adjudicated-false-positive`: substantive current evidence has been assessed,
  and every remaining blocking finding is disproven with an allowed recorded
  decision. Report acceptance with adjudicated findings, not a clean AI pass.
- `unverified`: unusable evidence, incomplete finding inventory, missing authority,
  unsupported/unresolved blockers, stale inputs or damaged evidence. State the
  cause and next action. No export/delivery eligibility follows from this outcome.

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
