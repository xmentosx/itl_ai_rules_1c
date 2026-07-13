#Requires -Version 5.1
<#
.SYNOPSIS
    Refreshes content/openspec-bundle/ from a locally installed OpenSpec CLI.

.DESCRIPTION
    Maintainer-only utility. Runs `openspec init` in a temporary directory
    against the five tools supported by 1c-rules, then mirrors the resulting
    files into content/openspec-bundle/<tool>/ and refreshes
    content/openspec-bundle/version.txt with the CLI's reported version.

    Bumps the static snapshot that the installer ships, so end-users continue
    to get OpenSpec slash commands and SKILLs without needing npm at install
    time. Re-run after upgrading the OpenSpec CLI.

    Requirements (maintainer machine only):
      - Node.js + npm
      - The official OpenSpec CLI installed globally:
          npm install -g @fission-ai/openspec@latest

.PARAMETER RepoRoot
    Path to the 1c-rules source repository. Defaults to the parent directory
    of the script (i.e. running from the repo works without arguments).

.PARAMETER DryRun
    Show planned actions and the diff summary; do not modify the repository.

.EXAMPLE
    .\tools\refresh-openspec-bundle.ps1

.EXAMPLE
    .\tools\refresh-openspec-bundle.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$script:Tools = @('cursor', 'claude-code', 'codex', 'opencode', 'kilocode')
$script:OpenSpecToolsArg = 'cursor,claude,codex,opencode,kilocode'
$script:BundleMap = @{
    'cursor'      = @(@{ Source = '.cursor'; Target = '.cursor' })
    'claude-code' = @(@{ Source = '.claude'; Target = '.claude' })
    'codex'       = @(@{ Source = '.codex/skills'; Target = '.agents/skills' })
    'opencode'    = @(@{ Source = '.opencode'; Target = '.opencode' })
    'kilocode'    = @(
        @{ Source = '.kilocode/skills'; Target = '.agents/skills' },
        @{ Source = '.kilocode/workflows'; Target = '.kilo/commands' }
    )
}

function Resolve-RepoRoot {
    param([string]$Requested)
    if ($Requested) {
        if (-not (Test-Path $Requested)) { throw "RepoRoot does not exist: $Requested" }
        return (Resolve-Path $Requested).Path
    }
    $scriptDir = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptDir '..')).Path
}

function Test-OpenSpecAvailable {
    $cmd = Get-Command openspec -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "OpenSpec CLI not found on PATH. Install it first: npm install -g @fission-ai/openspec@latest"
    }
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $version = (& openspec --version 2>&1 | Out-String).Trim()
    }
    finally {
        $ErrorActionPreference = $prevPref
    }
    if (-not $version) { throw "openspec --version returned empty output" }
    return $version
}

function Invoke-OpenSpecInit {
    param([string]$WorkDir)
    Push-Location $WorkDir
    # OpenSpec writes progress to stderr; with $ErrorActionPreference='Stop'
    # PowerShell would treat that as a fatal native-command error. Relax the
    # preference for the duration of this call and rely on $LASTEXITCODE.
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & openspec init --tools $script:OpenSpecToolsArg 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Host $output
            throw "openspec init failed (exit $LASTEXITCODE)"
        }
        return $output
    }
    finally {
        $ErrorActionPreference = $prevPref
        Pop-Location
    }
}

function Get-RelativeFiles {
    param([string]$BaseDir)
    if (-not (Test-Path $BaseDir)) { return @() }
    $base = (Resolve-Path $BaseDir).Path.TrimEnd('\', '/')
    return @(Get-ChildItem -Recurse -File $BaseDir -ErrorAction SilentlyContinue | ForEach-Object {
        $_.FullName.Substring($base.Length + 1).Replace('\', '/')
    } | Sort-Object)
}

function Sync-ToolBundle {
    param(
        [string]$Tool,
        [string]$ProbeRoot,
        [string]$BundleRoot,
        [bool]$DryRun
    )
    $addedCount = 0
    $updatedCount = 0
    $removedCount = 0
    foreach ($mapping in @($script:BundleMap[$Tool])) {
        $sourceRel = ([string]$mapping.Source).Replace('/', '\')
        $targetRel = ([string]$mapping.Target).Replace('/', '\')
        $sourceDir = Join-Path $ProbeRoot $sourceRel
        $targetDir = Join-Path $BundleRoot "$Tool\$targetRel"
        if (-not (Test-Path $sourceDir)) {
            Write-Warning "  [$Tool] no $sourceRel in probe output - skipped"
            continue
        }

        $sourceFiles = Get-RelativeFiles $sourceDir
        $targetFiles = Get-RelativeFiles $targetDir
        $sourceSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$sourceFiles)
        $targetSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$targetFiles)
        $added = @($sourceFiles | Where-Object { -not $targetSet.Contains($_) })
        $removed = @($targetFiles | Where-Object { -not $sourceSet.Contains($_) })
        $shared = @($sourceFiles | Where-Object { $targetSet.Contains($_) })
        $updated = @()
        foreach ($rel in $shared) {
            $a = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $sourceDir $rel)).Hash
            $b = (Get-FileHash -Algorithm SHA256 -Path (Join-Path $targetDir $rel)).Hash
            if ($a -ne $b) { $updated += $rel }
        }
        $addedCount += $added.Count
        $removedCount += $removed.Count
        $updatedCount += $updated.Count

        if (-not $DryRun) {
            if (Test-Path $targetDir) { Remove-Item -Recurse -Force $targetDir }
            $parent = Split-Path -Parent $targetDir
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
            Copy-Item -Recurse -Force -Path $sourceDir -Destination $targetDir
        }
    }
    return [pscustomobject]@{ Tool = $Tool; Added = $addedCount; Updated = $updatedCount; Removed = $removedCount }
}

$repo = Resolve-RepoRoot -Requested $RepoRoot
$bundleRoot = Join-Path $repo 'content\openspec-bundle'
if (-not (Test-Path $bundleRoot)) { New-Item -ItemType Directory -Path $bundleRoot | Out-Null }

Write-Host "Repo:    $repo"
Write-Host "Bundle:  $bundleRoot"
Write-Host "DryRun:  $DryRun"

$cliVersion = Test-OpenSpecAvailable
Write-Host "OpenSpec CLI version: $cliVersion"

$probe = Join-Path $env:TEMP ("opsx-refresh-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $probe | Out-Null
try {
    Write-Host ''
    Write-Host "Running openspec init in $probe ..."
    $initOut = Invoke-OpenSpecInit -WorkDir $probe
    Write-Verbose $initOut

    # The official bundle is intentionally refreshed from scratch. Reapply
    # ITL's project-skill preflight before diff/copy so future CLI upgrades do
    # not silently remove mandatory project context routing.
    & (Join-Path $repo 'tools\apply-openspec-downstream-overlay.ps1') -Root $probe
    if ($LASTEXITCODE -ne 0) { throw 'ITL OpenSpec downstream overlay failed.' }

    Write-Host ''
    Write-Host 'Per-tool diff:'
    $stats = @()
    foreach ($t in $script:Tools) {
        $stats += Sync-ToolBundle -Tool $t -ProbeRoot $probe -BundleRoot $bundleRoot -DryRun:$DryRun
    }
    foreach ($s in $stats) {
        Write-Host ("  {0,-12} added={1,-3} updated={2,-3} removed={3,-3}" -f $s.Tool, $s.Added, $s.Updated, $s.Removed)
    }

    $verFile = Join-Path $bundleRoot 'version.txt'
    $existingVersion = ''
    if (Test-Path $verFile) { $existingVersion = ((Get-Content -Raw -Path $verFile) -replace '\s+$', '').Trim() }
    if (-not $DryRun) {
        Set-Content -Path $verFile -Value $cliVersion -NoNewline -Encoding UTF8
    }

    Write-Host ''
    if ($existingVersion -and $existingVersion -ne $cliVersion) {
        Write-Host "version.txt: $existingVersion -> $cliVersion"
    }
    elseif (-not $existingVersion) {
        Write-Host "version.txt: <new> -> $cliVersion"
    }
    else {
        Write-Host "version.txt: $cliVersion (unchanged)"
    }

    if ($DryRun) {
        Write-Host ''
        Write-Host 'Dry run - no files modified. Re-run without -DryRun to apply.'
    }
    else {
        Write-Host ''
        Write-Host 'Bundle refresh complete. Review `git status` and commit.'
    }
}
finally {
    if (Test-Path $probe) { Remove-Item -Recurse -Force $probe }
}
