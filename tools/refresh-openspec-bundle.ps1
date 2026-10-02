#Requires -Version 5.1
<#
.SYNOPSIS
    Refreshes content/openspec-bundle/ from an explicitly pinned OpenSpec CLI.

.DESCRIPTION
    Maintainer-only utility. Runs `openspec init` in a temporary directory
    against the five tools supported by 1c-rules, then mirrors the resulting
    files into content/openspec-bundle/<tool>/ and refreshes
    content/openspec-bundle/version.txt with the CLI's reported version.

    Bumps the static snapshot that the installer ships, so end-users continue
    to get OpenSpec slash commands and SKILLs without needing npm at install
    time. Re-run after upgrading the OpenSpec CLI.

    Requirements (maintainer machine only): an absolute Node executable and
    official OpenSpec JS entrypoint with their expected SHA-256 values. The
    expected version is supplied explicitly; a global CLI is never selected.

.PARAMETER RepoRoot
    Path to the 1c-rules source repository. Defaults to the parent directory
    of the script (i.e. running from the repo works without arguments).

.PARAMETER DryRun
    Show planned actions and the diff summary; do not modify the repository.

.PARAMETER ExpectedVersion
    Exact version selected for this controlled fork intake.

.EXAMPLE
    .\tools\refresh-openspec-bundle.ps1 -NodePath C:\node\node.exe -NodeSha256 <sha256> -OpenSpecEntryPath C:\runtime\openspec.js -EntrySha256 <sha256> -ExpectedVersion 1.13.1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [Parameter(Mandatory = $true)][string]$NodePath,
    [Parameter(Mandatory = $true)][string]$NodeSha256,
    [Parameter(Mandatory = $true)][string]$OpenSpecEntryPath,
    [Parameter(Mandatory = $true)][string]$EntrySha256,
    [Parameter(Mandatory = $true)][string]$ExpectedVersion,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$script:Tools = @('cursor', 'claude-code', 'codex', 'opencode', 'kilocode')
$script:OpenSpecToolsArg = 'cursor,claude,codex,opencode,kilocode'
$script:DotMap = @{
    'cursor'      = '.cursor'
    'claude-code' = '.claude'
    # OpenSpec >= 1.13 writes Codex skills to the vendor-neutral .agents/skills/;
    # the installer maps them onto the Codex adapter's .codex/skills/.
    'codex'       = '.agents'
    'opencode'    = '.opencode'
    'kilocode'    = '.kilocode'
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

function Assert-PinnedOpenSpecCli {
    foreach ($inputPath in @($NodePath, $OpenSpecEntryPath)) {
        if (-not [IO.Path]::IsPathRooted($inputPath) -or -not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
            throw "OPEN_SPEC_BUNDLE_PIN_PATH_INVALID: '$inputPath' must be an existing absolute file."
        }
    }
    if ($ExpectedVersion -notmatch '^\d+\.\d+\.\d+$' -or
        $NodeSha256 -notmatch '^[a-fA-F0-9]{64}$' -or $EntrySha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'OPEN_SPEC_BUNDLE_PIN_INVALID: provide an exact version and two SHA-256 values.'
    }
    if ((Get-FileHash -LiteralPath $NodePath -Algorithm SHA256).Hash -ine $NodeSha256 -or
        (Get-FileHash -LiteralPath $OpenSpecEntryPath -Algorithm SHA256).Hash -ine $EntrySha256) {
        throw 'OPEN_SPEC_BUNDLE_PIN_DRIFT: Node or OpenSpec entrypoint bytes differ from the supplied hashes.'
    }
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $version = (& $NodePath $OpenSpecEntryPath --version 2>&1 | Out-String).Trim()
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $prevPref
    }
    if ($exitCode -ne 0 -or $version -cne $ExpectedVersion) {
        throw "OPEN_SPEC_BUNDLE_VERSION_MISMATCH: expected '$ExpectedVersion', got '$version' (exit $exitCode)."
    }
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
        $output = & $NodePath $OpenSpecEntryPath init --tools $script:OpenSpecToolsArg 2>&1 | Out-String
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

# CLI bookkeeping files that must not ship (e.g. .agents/skills/.openspec-target).
$script:SkipNames = @('.openspec-target')

function Get-RelativeFiles {
    param([string]$BaseDir)
    if (-not (Test-Path $BaseDir)) { return @() }
    $base = (Resolve-Path $BaseDir).Path.TrimEnd('\', '/')
    return @(Get-ChildItem -Recurse -File -Force $BaseDir -ErrorAction SilentlyContinue |
        Where-Object { $script:SkipNames -notcontains $_.Name } | ForEach-Object {
        $_.FullName.Substring($base.Length + 1).Replace('\', '/')
    } | Sort-Object)
}

function Get-NormalizedBundleText {
    param([Parameter(Mandatory = $true)][string]$Path)
    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    return $strictUtf8.GetString([IO.File]::ReadAllBytes($Path)).Replace("`r`n", "`n")
}

function Sync-ToolBundle {
    param(
        [string]$Tool,
        [string]$ProbeRoot,
        [string]$BundleRoot,
        [bool]$DryRun
    )
    $dot = $script:DotMap[$Tool]
    $sourceDir = Join-Path $ProbeRoot $dot
    # Compare each generated file and replace only changed content. A
    # same-version refresh remains byte-stable across checkout line endings.
    $toolDir = Join-Path $BundleRoot $Tool
    $bundleFull = [IO.Path]::GetFullPath($BundleRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $toolFull = [IO.Path]::GetFullPath($toolDir)
    if (-not $toolFull.StartsWith($bundleFull, [StringComparison]::OrdinalIgnoreCase) -or
        $Tool -notin $script:Tools -or
        ((Test-Path -LiteralPath $toolFull) -and
            ((Get-Item -LiteralPath $toolFull -Force).Attributes -band [IO.FileAttributes]::ReparsePoint))) {
        throw "OPEN_SPEC_BUNDLE_TOOL_SCOPE_INVALID: refusing to replace '$toolDir'."
    }

    if (-not (Test-Path $sourceDir)) {
        Write-Warning "  [$Tool] no $dot in probe output - skipped"
        return [pscustomobject]@{ Tool = $Tool; Added = 0; Updated = 0; Removed = 0 }
    }

    $sourceFiles = @(Get-RelativeFiles $sourceDir | ForEach-Object { "$dot/$_" })
    $targetFiles = Get-RelativeFiles $toolDir
    $sourceSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$sourceFiles)
    $targetSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$targetFiles)

    $added = @($sourceFiles | Where-Object { -not $targetSet.Contains($_) })
    $removed = @($targetFiles | Where-Object { -not $sourceSet.Contains($_) })
    $shared = @($sourceFiles | Where-Object { $targetSet.Contains($_) })
    $updated = @()
    foreach ($rel in $shared) {
        $a = Get-NormalizedBundleText -Path (Join-Path $ProbeRoot $rel)
        $b = Get-NormalizedBundleText -Path (Join-Path $toolDir $rel)
        if ($a -cne $b) { $updated += $rel }
    }

    if (-not $DryRun) {
        foreach ($rel in $removed) {
            $obsolete = [IO.Path]::GetFullPath((Join-Path $toolDir $rel))
            if (-not $obsolete.StartsWith(($toolFull + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
                throw "OPEN_SPEC_BUNDLE_FILE_SCOPE_INVALID: '$obsolete'."
            }
            Remove-Item -LiteralPath $obsolete -Force
        }
        foreach ($rel in @($added) + @($updated)) {
            $dest = Join-Path $toolDir $rel
            $parent = Split-Path -Parent $dest
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
            Copy-Item -LiteralPath (Join-Path $ProbeRoot $rel) -Destination $dest -Force
        }
    }

    return [pscustomobject]@{
        Tool    = $Tool
        Added   = $added.Count
        Updated = $updated.Count
        Removed = $removed.Count
    }
}

$repo = Resolve-RepoRoot -Requested $RepoRoot
$bundleRoot = Join-Path $repo 'content\openspec-bundle'
if (-not (Test-Path $bundleRoot)) { New-Item -ItemType Directory -Path $bundleRoot | Out-Null }

Write-Host "Repo:    $repo"
Write-Host "Bundle:  $bundleRoot"
Write-Host "DryRun:  $DryRun"

$cliVersion = Assert-PinnedOpenSpecCli
Write-Host "OpenSpec CLI version: $cliVersion"

$probe = Join-Path $env:TEMP ("opsx-refresh-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $probe | Out-Null
try {
    Write-Host ''
    Write-Host "Running openspec init in $probe ..."
    $initOut = Invoke-OpenSpecInit -WorkDir $probe
    Write-Verbose $initOut
    $overlayPath = Join-Path $repo 'tools/apply-openspec-downstream-overlay.ps1'
    if (-not (Test-Path -LiteralPath $overlayPath -PathType Leaf)) {
        throw "OPEN_SPEC_BUNDLE_OVERLAY_MISSING: $overlayPath"
    }
    & $overlayPath -Root $probe -GeneratedRoot

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
    if (-not $DryRun -and $existingVersion -cne $cliVersion) {
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
    $tempFull = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $probeFull = [IO.Path]::GetFullPath($probe)
    if (-not $probeFull.StartsWith($tempFull, [StringComparison]::OrdinalIgnoreCase) -or
        -not ([IO.Path]::GetFileName($probeFull) -match '^opsx-refresh-[a-f0-9]{32}$')) {
        throw "OPEN_SPEC_BUNDLE_PROBE_SCOPE_INVALID: refusing to remove '$probeFull'."
    }
    if (Test-Path -LiteralPath $probeFull) { Remove-Item -LiteralPath $probeFull -Recurse -Force }
}
