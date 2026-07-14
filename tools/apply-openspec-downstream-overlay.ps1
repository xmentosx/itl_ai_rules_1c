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

Before answering, investigating the repository, planning, proposing, or applying:

1. Read the project root `AGENTS.md` and `USER-RULES.md` and identify every skill they make mandatory for the current subject or phase.
2. Activate those skills before broad repository traversal. Kilo must call `skill("<skill-name>")`; clients with native skill activation use their native mechanism.
3. If a mandatory skill requires an external product source, search that source first, then verify the result against code, tests, metadata, and available MCP evidence.
4. If a mandatory skill or source is unavailable, show the exact recovery action and do not present architecture or product intent as confirmed; label code-only findings as provisional.
5. When creating or updating OpenSpec artifacts, add a `## Context Sources` section listing the material external pages used and any conflicts with repository evidence.

'@
$proposeMarker = '<!-- itl:propose-test-design -->'
$proposeOverlay = @'
<!-- itl:propose-test-design -->
## 1C test design (ITL downstream)

For a configuration, extension, or observable 1C behavior change, create `openspec/changes/<change-id>/test-plan.md` before declaring the change apply-ready. Follow `content/rules/sdd-integrations.md`: plan 2-3 scenarios by default (a fourth needs a written reason), link each scenario to a requirement and task/observable slice, and include type, minimal preconditions, action, observable result, and boundary/negative aspect. UI requirements require a UI scenario. Do not read `VANESSA-TESTS-GUIDE.md` and do not create or edit `.feature` files during propose. Docs/tooling-only changes use their native checks instead of an artificial Vanessa plan.

'@
$applyMarker = '<!-- itl:apply-test-authoring -->'
$applyOverlay = @'
<!-- itl:apply-test-authoring -->
## 1C test authoring (ITL downstream)

For a 1C behavior change, read `test-plan.md` in addition to the OpenSpec CLI `contextFiles`. Before the first actual `.feature` edit, read the local `VANESSA-TESTS-GUIDE.md` once and, only if needed, 1-2 nearest local examples. Implement each test with its observable slice; small changes run one final `/itl-check`, while large changes run a focused scenario per slice and the full set at the end. Do not weaken an approved observable result or replace a required UI scenario without updating the approved artifacts. Write `test-report.md` with scenario IDs/types/results, the Vanessa report path, and defects fixed while testing.

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

Write-Host "ITL OpenSpec preflight overlay: updated=$updated already-present=$skipped root=$resolvedRoot"
