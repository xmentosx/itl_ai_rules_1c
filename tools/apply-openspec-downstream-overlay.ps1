#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [switch]$GeneratedRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$utf8 = [Text.UTF8Encoding]::new($false)
$start = '<!-- itl:openspec-integration-v2:start -->'
$end = '<!-- itl:openspec-integration-v2:end -->'
$phaseNames = [ordered]@{
    explore = 'openspec-explore'
    propose = 'openspec-propose'
    apply = 'openspec-apply-change'
    archive = 'openspec-archive-change'
    update = 'openspec-update-change'
    sync = 'openspec-sync-specs'
}

function Get-PhaseFromFile {
    param([IO.FileInfo]$File)
    foreach ($phase in $phaseNames.Keys) {
        if ($File.Name -eq "opsx-$phase.md" -or
            ($File.Directory.Name -eq 'opsx' -and $File.Name -eq "$phase.md") -or
            ($File.Name -eq 'SKILL.md' -and $File.Directory.Name -eq $phaseNames[$phase])) {
            return $phase
        }
    }
    return ''
}

function Get-Overlay {
    param([string]$Phase)
    $phaseAction = switch ($Phase) {
        explore { 'Explore is read-only; record sources and material uncertainty before proposing.' }
        propose { 'Propose writes planning artifacts only. Do not require a separate test-plan.md or plan unit, regression, and acceptance suites by default; choose verification obligations and retention from the effective project policy.' }
        apply { 'Apply the approved artifacts without reopening settled choices. The existing ITL verification owner selects checks and records fresh proof; a test file is not required merely to satisfy a count.' }
        archive { 'Archive only after local sync and validation of the selected change and its spec delta. In a managed project, use the ITL pinned `openspec-archive-change` action instead of a direct move or an unqualified CLI.' }
        update { 'Update revises the selected change artifacts, not the installed workflow package. Preserve approved decisions unless the user reopens them. An explicit request to update an already agreed change authorizes the in-scope artifact edits; the upstream per-artifact confirmation steps apply only to a newly proposed material revision that the request and accepted decisions did not authorize.' }
        sync { 'Sync writes local current specs while leaving the change active; validate the selected delta again before archive. External main specs are unavailable in this release.' }
    }
    $template = @'
$start
<!-- itl:project-skill-preflight -->
<!-- itl:caveman-response-style -->
## ITL project contract for OpenSpec @@PHASE@@

Before this phase in a managed ITL project, read project-root `AGENTS.md` and `USER-RULES.md`, then load the on-demand OpenSpec, product-documentation, and subject skills they route to. Confirm 1C facts through the required MCP provider before broad repository traversal; record material sources and conflicts in the change artifacts. Unavailable required evidence makes the dependent conclusion provisional, not silently verified.

In a managed ITL project, use the OpenSpec CLI pinned to the installed workflow checkout: resolve its absolute Node executable and JS entrypoint through the ITL runtime, and provision the selected pin with the existing `provision-openspec-cli` action if missing. Do not select a global `openspec` from PATH or run `openspec update` to regenerate these adapted files. Before any planning write, call the ITL `openspec-context` action and require its local root to equal this checkout. `OPEN_SPEC_EXTERNAL_STORE_DEFERRED` stops the dependent phase before any direct `--store`, artifact write, sync or archive move; preserve the external binding and documents, and continue only after an explicit local selection or a later qualified release. For a local new change or archive, use the ITL pinned `openspec-new-change` or `openspec-archive-change` action; agent-authored artifacts and sync use only the resolved local paths. A standalone rules-only project without ITL state follows the upstream OpenSpec CLI workflow and its own installation.

An existing authorization for this phase and selected change remains valid across its steps. Do not repeat an approval request solely because an upstream step says to confirm. Ask only when a new material choice, explicit waiver, or unaccepted risk actually requires the user's decision; continue independent work while that decision is pending.

@@PHASE_ACTION@@

Caveman follows the project skill: explicit session force first; otherwise `CAVEMAN=auto` by default, with session level `full` by default. Auto classifies the current verb; it does not impose a permanent style on all OpenSpec phases. Shorten only working commentary. Keep artifacts, exact technical text, evidence, safety warnings, and mandatory reports complete.
$end
'@
    return $template.Replace('$start', $start).Replace('$end', $end).
        Replace('@@PHASE@@', $Phase).Replace('@@PHASE_ACTION@@', $phaseAction).
        Replace("`r`n", "`n").TrimEnd("`n")
}

$expected = 0
$changed = 0
foreach ($tool in @('cursor', 'claude-code', 'codex', 'opencode', 'kilocode')) {
    $toolRoot = if ($GeneratedRoot) {
        $directory = switch ($tool) {
            'cursor' { '.cursor' }
            'claude-code' { '.claude' }
            'codex' { '.agents' }
            'opencode' { '.opencode' }
            'kilocode' { '.kilocode' }
        }
        Join-Path $rootPath $directory
    }
    else { Join-Path $rootPath $tool }
    if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) {
        throw "OPEN_SPEC_OVERLAY_BUNDLE_MISSING: $toolRoot"
    }
    $toolCount = 0
    foreach ($file in @(Get-ChildItem -LiteralPath $toolRoot -Recurse -File -Filter '*.md')) {
        $phase = Get-PhaseFromFile -File $file
        if (-not $phase) { continue }
        $toolCount++
        $originalText = [IO.File]::ReadAllText($file.FullName)
        $raw = $originalText.Replace("`r`n", "`n")
        $old = [regex]::Match($raw, '(?s)\n?<!-- itl:openspec-integration-v2:start -->.*?<!-- itl:openspec-integration-v2:end -->\n*')
        if ($old.Success) { $raw = $raw.Remove($old.Index, $old.Length) }
        $frontmatter = [regex]::Match($raw, '(?s)\A---\n.*?\n---\n')
        $overlay = Get-Overlay -Phase $phase
        if ($frontmatter.Success) {
            $head = $raw.Substring(0, $frontmatter.Length).TrimEnd("`n")
            $body = $raw.Substring($frontmatter.Length).TrimStart("`n")
            $candidate = "$head`n`n$overlay`n`n$body"
        }
        else { $candidate = "$overlay`n`n$($raw.TrimStart("`n"))" }
        $current = $originalText.Replace("`r`n", "`n")
        if ($candidate -cne $current) {
            $bytes = [IO.File]::ReadAllBytes($file.FullName)
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and
                $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $outputText = if ($originalText.Contains("`r`n")) { $candidate.Replace("`n", "`r`n") } else { $candidate }
            [IO.File]::WriteAllText($file.FullName, $outputText, [Text.UTF8Encoding]::new($hasBom))
            $changed++
        }
    }
    $required = if ($tool -eq 'codex') { 6 } else { 12 }
    if ($toolCount -ne $required) {
        throw "OPEN_SPEC_OVERLAY_PHASE_SET_INCOMPLETE: $tool has $toolCount files, expected $required."
    }
    $expected += $required
}
Write-Output "OpenSpec ITL overlay: files=$expected changed=$changed"
