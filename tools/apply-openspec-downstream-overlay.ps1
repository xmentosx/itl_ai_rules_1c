#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$commonMarker = '<!-- itl:project-skill-preflight -->'
$commonOverlay = @'
<!-- itl:project-skill-preflight -->
## Project skill preflight (ITL downstream)

Before repository exploration, proposal, or implementation:

1. Read project-root `AGENTS.md` and `USER-RULES.md`; their project and ITL gates override generic rules.
2. Activate every project skill required for the subject and current OpenSpec phase.
3. Query mandatory product/documentation sources before broad repository traversal, then verify findings against code, tests, metadata, and available MCP evidence.
4. Record material sources and conflicts in `## Context Sources`. If a required source is unavailable, label code-only conclusions as provisional and show the recovery action.

'@
$proposeMarker = '<!-- itl:propose-test-design -->'
$proposeOverlay = @'
<!-- itl:propose-test-design -->
## 1C test design (ITL downstream)

Create `openspec/changes/<change-id>/test-plan.md` before declaring a code, metadata, or observable-behavior change apply-ready. Resolve the effective ITL verification modes from project state. When `ITL_VANESSA_TESTING=off`, do not automatically add new Vanessa scenarios; record the skipped component and the evidence needed to enable it. Propose describes checks but does not create or edit executable tests.

'@
$applyMarker = '<!-- itl:apply-test-authoring -->'
$applyOverlay = @'
<!-- itl:apply-test-authoring -->
## 1C test authoring (ITL downstream)

Read and follow `test-plan.md` together with the OpenSpec `contextFiles`; do not silently weaken an approved observable result. Execute test authoring and checks according to the effective ITL verification modes. Finish implementation with a fresh `/itl-check`; skipped components remain explicit partial evidence and never become a normal fresh pass.

'@
$applyRoutingMarker = '<!-- itl:conditional-apply-routing -->'
$applyOldImplementationPattern = '(?ms)^6\. \*\*Run the 1C pipeline and implement tasks \(loop until done or blocked\)\*\*\r?\n\r?\n.*?^   \(`verification-checklist\.md`\) still run\.$'
$applyNewImplementationBlock = @'
6. **Choose the execution route and implement tasks (loop until done or blocked)**

   <!-- itl:conditional-apply-routing -->
   Before the first edit, load `content/rules/verification-checklist.md` and classify the
   current session plan using `AGENTS.md -> Triage`. Quick-fix / docs-fix / spec-authoring
   work follows its dedicated route. For full-cycle work, choose the actual implementation
   route now from `AGENTS.md -> Skills and Subagents`, `content/rules/subagents.md`, and the
   current `ORCHESTRATION` setting. Delegation during explore or propose does not select the
   apply route, and the absence of an earlier delegation request does not select direct
   execution.

   If delegation is chosen, load `content/rules/subagent-pipeline.md` and follow it. Otherwise
   the parent executes directly and does not load the pipeline. Apply the common routing and
   completion contract from `content/rules/sdd-integrations.md -> Apply execution route and
   spec compliance`. Either way the approved OpenSpec artifacts are the approved plan -- do
   not ask for duplicate approval -- and spec compliance plus the closing verification gate
   still run.
'@
$applyOldStage4a = '   - Run Stage 4a from `content/rules/subagent-pipeline.md` against the implemented task set.'
$applyNewStage4a = @'
   - If implementation was delegated, run Stage 4a from `content/rules/subagent-pipeline.md`.
   - If implementation was direct, run the compact structural comparison from
     `content/rules/sdd-integrations.md -> Apply execution route and spec compliance` without
     loading the pipeline.
'@
$applyOldCompletion = '   - Only after Stage 4a and the closing gate pass, update each verified task:'
$applyNewCompletion = '   - Only after the applicable spec-compliance check and the closing gate pass, update each verified task:'
$applyOldVerification = '**Verification:** Stage 4a and all applicable closing gates passed'
$applyNewVerification = '**Verification:** Applicable spec compliance and all closing gates passed'
$applyOldGuardrail = '- Load `subagent-pipeline.md` and `verification-checklist.md` before the first edit'
$applyNewGuardrail = '- Load `verification-checklist.md` before the first edit; load `subagent-pipeline.md` only after implementation delegation is chosen'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$updated = 0
$skipped = 0

function Test-TargetOpenSpecFile {
    param([System.IO.FileInfo]$File)

    if ($File.Name -in @('opsx-explore.md', 'opsx-propose.md', 'opsx-apply.md')) { return $true }
    if ($File.Directory.Name -eq 'opsx' -and $File.Name -in @('explore.md', 'propose.md', 'apply.md')) { return $true }
    if ($File.Name -ne 'SKILL.md') { return $false }
    return $File.Directory.Name -in @('openspec-explore', 'openspec-propose', 'openspec-apply-change')
}

function Get-OpenSpecPhase {
    param([System.IO.FileInfo]$File)
    if ($File.Name -in @('opsx-propose.md', 'propose.md') -or $File.Directory.Name -eq 'openspec-propose') { return 'propose' }
    if ($File.Name -in @('opsx-apply.md', 'apply.md') -or $File.Directory.Name -eq 'openspec-apply-change') { return 'apply' }
    return 'common'
}

function Set-ConditionalApplyRouting {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $normalized = $Text.Replace("`r`n", "`n")
    if ($normalized.Contains($applyRoutingMarker)) { return $normalized }

    $implementationMatches = [regex]::Matches($normalized, $applyOldImplementationPattern).Count
    if ($implementationMatches -ne 1) {
        throw "OpenSpec apply routing expected exactly one implementation block match in '$Path', found $implementationMatches. Review the upstream bundle before refreshing the downstream overlay."
    }
    $normalized = [regex]::Replace($normalized, $applyOldImplementationPattern, $applyNewImplementationBlock.Replace("`r`n", "`n"))

    $replacements = @(
        [pscustomobject]@{ Name = 'Stage 4a route'; Old = $applyOldStage4a; New = $applyNewStage4a.Replace("`r`n", "`n") }
        [pscustomobject]@{ Name = 'task completion gate'; Old = $applyOldCompletion; New = $applyNewCompletion }
        [pscustomobject]@{ Name = 'verification report'; Old = $applyOldVerification; New = $applyNewVerification }
        [pscustomobject]@{ Name = 'guardrail'; Old = $applyOldGuardrail; New = $applyNewGuardrail }
    )
    foreach ($replacement in $replacements) {
        $matches = [regex]::Matches($normalized, [regex]::Escape([string]$replacement.Old)).Count
        if ($matches -ne 1) {
            throw "OpenSpec apply routing expected exactly one $($replacement.Name) match in '$Path', found $matches. Review the upstream bundle before refreshing the downstream overlay."
        }
        $normalized = $normalized.Replace([string]$replacement.Old, [string]$replacement.New)
    }
    return $normalized
}

function Sync-CodexOpsxAliases {
    $codexSkillRoot = Join-Path $resolvedRoot 'codex\.codex\skills'
    if (-not (Test-Path -LiteralPath $codexSkillRoot -PathType Container)) {
        return [pscustomobject]@{ Updated = 0; Unchanged = 0 }
    }

    $definitions = [ordered]@{
        'opsx-explore' = [ordered]@{
            canonical = 'openspec-explore'
            description = 'Explicit alias for the canonical OpenSpec explore workflow. Invoke only as $opsx-explore.'
        }
        'opsx-propose' = [ordered]@{
            canonical = 'openspec-propose'
            description = 'Explicit alias for the canonical OpenSpec proposal workflow. Invoke only as $opsx-propose.'
        }
        'opsx-apply' = [ordered]@{
            canonical = 'openspec-apply-change'
            description = 'Explicit alias for the canonical OpenSpec apply workflow. Invoke only as $opsx-apply.'
        }
        'opsx-archive' = [ordered]@{
            canonical = 'openspec-archive-change'
            description = 'Explicit alias for the canonical OpenSpec archive workflow. Invoke only as $opsx-archive.'
        }
    }
    $skillTemplate = @'
---
name: <alias>
description: <description>
---

This is an explicit compatibility alias for `<canonical>`.

Read `../<canonical>/SKILL.md` completely, then follow it exactly as if that canonical skill had been selected. Treat any text following `$<alias>` as input to the canonical skill. Do not duplicate, weaken, or reinterpret the canonical workflow here.
'@
    $policyText = @'
policy:
  allow_implicit_invocation: false
'@
    $skillTemplate = $skillTemplate.Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    $policyText = $policyText.Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    $updated = 0
    $unchanged = 0
    foreach ($alias in $definitions.Keys) {
        $definition = $definitions[$alias]
        $canonicalPath = Join-Path $codexSkillRoot "$($definition.canonical)\SKILL.md"
        if (-not (Test-Path -LiteralPath $canonicalPath -PathType Leaf)) {
            throw "Canonical Codex OpenSpec skill is missing for ${alias}: $canonicalPath"
        }

        $aliasRoot = Join-Path $codexSkillRoot $alias
        $targets = [ordered]@{
            (Join-Path $aliasRoot 'SKILL.md') = $skillTemplate.Replace('<alias>', $alias).Replace('<description>', [string]$definition.description).Replace('<canonical>', [string]$definition.canonical)
            (Join-Path $aliasRoot 'agents\openai.yaml') = $policyText
        }
        foreach ($target in $targets.Keys) {
            $expected = [string]$targets[$target]
            $current = if (Test-Path -LiteralPath $target -PathType Leaf) { [System.IO.File]::ReadAllText($target) } else { $null }
            if ($current -ceq $expected) {
                $unchanged++
                continue
            }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            [System.IO.File]::WriteAllText($target, $expected, $utf8NoBom)
            $updated++
        }
    }
    return [pscustomobject]@{ Updated = $updated; Unchanged = $unchanged }
}

foreach ($file in Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter '*.md') {
    if (-not (Test-TargetOpenSpecFile -File $file)) { continue }
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $newText = $text
    $blocks = @()
    if (-not $text.Contains($commonMarker)) { $blocks += $commonOverlay }
    $phase = Get-OpenSpecPhase -File $file
    if ($phase -eq 'propose' -and -not $text.Contains($proposeMarker)) { $blocks += $proposeOverlay }
    if ($phase -eq 'apply' -and -not $text.Contains($applyMarker)) { $blocks += $applyOverlay }

    if ($blocks.Count -gt 0) {
        $overlay = ($blocks -join '')
        $newText = $overlay + $text
        if ($text.StartsWith('---')) {
            $frontmatterEnd = [regex]::Match($text, '(?s)\A---\r?\n.*?\r?\n---\r?\n')
            if (-not $frontmatterEnd.Success) {
                throw "Malformed OpenSpec skill frontmatter: $($file.FullName)"
            }
            $newText = $text.Substring(0, $frontmatterEnd.Length) + "`n" + $overlay + $text.Substring($frontmatterEnd.Length)
        }
    }
    if ($phase -eq 'apply') {
        $newText = Set-ConditionalApplyRouting -Text $newText -Path $file.FullName
    }
    if ($newText -ceq $text) { $skipped++; continue }

    [System.IO.File]::WriteAllText($file.FullName, $newText, $utf8NoBom)
    $updated++
}

$aliasStats = Sync-CodexOpsxAliases
Write-Host "ITL OpenSpec preflight overlay: updated=$updated already-present=$skipped root=$resolvedRoot"
Write-Host "ITL Codex opsx aliases: updated=$($aliasStats.Updated) already-present=$($aliasStats.Unchanged)"
