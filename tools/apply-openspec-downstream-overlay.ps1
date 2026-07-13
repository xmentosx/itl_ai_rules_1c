#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$marker = '<!-- itl:project-skill-preflight -->'
$overlay = @'
<!-- itl:project-skill-preflight -->
## Project skill preflight (ITL downstream)

Before answering, investigating the repository, planning, proposing, or applying:

1. Read the project root `AGENTS.md` and `USER-RULES.md` and identify every skill they make mandatory for the current subject or phase.
2. Activate those skills before broad repository traversal. Kilo must call `skill("<skill-name>")`; clients with native skill activation use their native mechanism.
3. If a mandatory skill requires an external product source, search that source first, then verify the result against code, tests, metadata, and available MCP evidence.
4. If a mandatory skill or source is unavailable, show the exact recovery action and do not present architecture or product intent as confirmed; label code-only findings as provisional.
5. When creating or updating OpenSpec artifacts, add a `## Context Sources` section listing the material external pages used and any conflicts with repository evidence.

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

foreach ($file in Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter '*.md') {
    if (-not (Test-TargetOpenSpecFile -File $file)) { continue }
    $text = [System.IO.File]::ReadAllText($file.FullName)
    if ($text.Contains($marker)) {
        $skipped++
        continue
    }

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
