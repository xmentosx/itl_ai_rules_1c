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
    $blocks = @()
    if (-not $text.Contains($commonMarker)) { $blocks += $commonOverlay }
    $phase = Get-OpenSpecPhase -File $file
    if ($phase -eq 'propose' -and -not $text.Contains($proposeMarker)) { $blocks += $proposeOverlay }
    if ($phase -eq 'apply' -and -not $text.Contains($applyMarker)) { $blocks += $applyOverlay }
    if ($blocks.Count -eq 0) { $skipped++; continue }

    $overlay = ($blocks -join '')
    $newText = $overlay + $text
    if ($text.StartsWith('---')) {
        $frontmatterEnd = [regex]::Match($text, '(?s)\A---\r?\n.*?\r?\n---\r?\n')
        if (-not $frontmatterEnd.Success) {
            throw "Malformed OpenSpec skill frontmatter: $($file.FullName)"
        }
        $newText = $text.Substring(0, $frontmatterEnd.Length) + "`n" + $overlay + $text.Substring($frontmatterEnd.Length)
    }

    [System.IO.File]::WriteAllText($file.FullName, $newText, $utf8NoBom)
    $updated++
}

$aliasStats = Sync-CodexOpsxAliases
Write-Host "ITL OpenSpec preflight overlay: updated=$updated already-present=$skipped root=$resolvedRoot"
Write-Host "ITL Codex opsx aliases: updated=$($aliasStats.Updated) already-present=$($aliasStats.Unchanged)"
