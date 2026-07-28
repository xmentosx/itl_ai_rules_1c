[CmdletBinding()]
param(
    [ValidateSet("Fast", "Full")]
    [string]$Mode = "Full",
    [string]$OutputDirectory = "build\test-results\local",
    [string]$QualificationPath = "build\test-results\qualification\full.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Resolve-RepositoryPath {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Root)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-RelativeRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Root)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if (-not $fullPath.StartsWith($fullRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Replace('\', '/')
    }
    return ($fullPath.Substring($fullRoot.Length)).TrimStart([char[]]'\/').Replace('\', '/')
}

function New-InventoryEntry {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Root)
    return [ordered]@{
        path = Get-RelativeRepositoryPath -Path $Path -Root $Root
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Resolve-RepositoryPath -Path $OutputDirectory -Root $repoRoot
$qualificationFullPath = Resolve-RepositoryPath -Path $QualificationPath -Root $repoRoot
$summaryPath = Join-Path $outputRoot "check-summary.json"
$junitPath = Join-Path $outputRoot "pester.xml"
$startedAt = [DateTime]::UtcNow
$overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$pesterResult = $null
$pesterVersion = $null
$failure = $null
$stages = New-Object System.Collections.ArrayList

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
Push-Location $repoRoot
try {
    $stageStartedAt = [DateTime]::UtcNow
    $stageStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $stageFailure = $null
    try {
        & git diff --check HEAD -- .
        if ($LASTEXITCODE -ne 0) { throw "git diff --check failed." }
    } catch {
        $stageFailure = $_.Exception.Message
        throw
    } finally {
        $stageStopwatch.Stop()
        [void]$stages.Add([ordered]@{
            name = "git-diff-check"
            status = $(if ($stageFailure) { "failed" } else { "passed" })
            execution = "executed"
            reason = "required"
            startedAt = $stageStartedAt.ToString("o")
            finishedAt = [DateTime]::UtcNow.ToString("o")
            durationMs = [int64]$stageStopwatch.ElapsedMilliseconds
        })
    }

    $stageStartedAt = [DateTime]::UtcNow
    $stageStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $stageFailure = $null
    try {
        Import-Module Pester -MinimumVersion 5.0.0 -Force
        $pesterVersion = [string](Get-Module Pester | Select-Object -First 1 -ExpandProperty Version)
        $configuration = New-PesterConfiguration
        $configuration.Run.Path = @(".\tests")
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = "Detailed"
        if ($Mode -eq "Fast") { $configuration.Filter.Tag = @("Fast") }
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputFormat = "JUnitXml"
        $configuration.TestResult.OutputPath = $junitPath
        $pesterResult = Invoke-Pester -Configuration $configuration
        if ([string]$pesterResult.Result -ne "Passed") {
            throw "Pester did not pass: result=$($pesterResult.Result), failed=$($pesterResult.FailedCount)."
        }
    } catch {
        $stageFailure = $_.Exception.Message
        throw
    } finally {
        $stageStopwatch.Stop()
        [void]$stages.Add([ordered]@{
            name = "pester"
            status = $(if ($stageFailure) { "failed" } else { "passed" })
            execution = "executed"
            reason = $(if ($Mode -eq "Fast") { "Fast-tag inventory" } else { "complete test inventory" })
            startedAt = $stageStartedAt.ToString("o")
            finishedAt = [DateTime]::UtcNow.ToString("o")
            durationMs = [int64]$stageStopwatch.ElapsedMilliseconds
        })
    }
} catch {
    $failure = $_.Exception.Message
} finally {
    $overallStopwatch.Stop()
    $commit = [string](& git rev-parse HEAD 2>$null)
    $tree = [string](& git rev-parse 'HEAD^{tree}' 2>$null)
    $branch = [string](& git branch --show-current 2>$null)
    $dirty = @(& git status --porcelain --untracked-files=all).Count -gt 0
    # A new downstream revision is intentionally branched straight from the
    # immutable upstream snapshot, so it may have no reachable fork tag yet.
    # `git describe` exits non-zero in that valid pre-release state.
    $baseTag = [string](@(& git tag --merged HEAD --list "itl-*" --sort=-version:refname | Select-Object -First 1))
    $baseTagContents = if ($baseTag) { [string](& git for-each-ref --format='%(contents)' "refs/tags/$baseTag" 2>$null) } else { "" }
    $upstreamCommit = ""
    $upstreamRef = ""
    if ($baseTagContents -match 'upstream=([^@;\s]+)@([0-9a-fA-F]{40})') {
        $upstreamRef = $Matches[1]
        $upstreamCommit = $Matches[2].ToLowerInvariant()
    }

    $summary = [ordered]@{
        schemaVersion = 2
        repository = "itl_ai_rules_1c"
        mode = $Mode
        status = $(if ($failure) { "failed" } else { "passed" })
        startedAt = $startedAt.ToString("o")
        finishedAt = [DateTime]::UtcNow.ToString("o")
        durationMs = [int64]$overallStopwatch.ElapsedMilliseconds
        commit = $commit
        tree = $tree
        branch = $branch
        worktreeClean = (-not $dirty)
        stages = @($stages)
        tests = [ordered]@{
            passed = $(if ($pesterResult) { [int]$pesterResult.PassedCount } else { 0 })
            failed = $(if ($pesterResult) { [int]$pesterResult.FailedCount } else { 0 })
            skipped = $(if ($pesterResult) { [int]$pesterResult.SkippedCount } else { 0 })
        }
        error = $failure
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 10), $utf8NoBom)

    if ($Mode -eq "Full") {
        $testInventory = @(
            Get-ChildItem -LiteralPath (Join-Path $repoRoot "tests") -Recurse -File -Filter "*.ps1" |
                Sort-Object FullName |
                ForEach-Object { New-InventoryEntry -Path $_.FullName -Root $repoRoot }
        )
        $scriptInventory = @(
            New-InventoryEntry -Path $PSCommandPath -Root $repoRoot
            New-InventoryEntry -Path (Join-Path $repoRoot "scripts\publish-fork-release.ps1") -Root $repoRoot
        )
        $qualification = [ordered]@{
            schemaVersion = 1
            kind = "itl-ai-rules-full-qualification"
            status = $(if ($failure) { "failed" } else { "passed" })
            reusable = (-not $failure -and -not $dirty)
            repository = [ordered]@{
                name = "itl_ai_rules_1c"
                commit = $commit
                tree = $tree
                branch = $branch
                worktreeClean = (-not $dirty)
            }
            provenance = [ordered]@{
                nearestForkTag = $baseTag
                upstreamRef = $upstreamRef
                upstreamCommit = $upstreamCommit
            }
            environment = [ordered]@{
                powershellVersion = [string]$PSVersionTable.PSVersion
                powershellEdition = [string]$PSVersionTable.PSEdition
                pesterVersion = $pesterVersion
                platform = $(if ($PSVersionTable.ContainsKey("Platform")) { [string]$PSVersionTable["Platform"] } else { "Win32NT" })
                os = $(if ($PSVersionTable.ContainsKey("OS")) { [string]$PSVersionTable["OS"] } else { [string][System.Environment]::OSVersion.VersionString })
            }
            inventory = [ordered]@{
                tests = $testInventory
                scripts = $scriptInventory
            }
            junit = [ordered]@{
                path = Get-RelativeRepositoryPath -Path $junitPath -Root $repoRoot
                sha256 = $(if (Test-Path $junitPath -PathType Leaf) { (Get-FileHash -LiteralPath $junitPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { "" })
            }
            result = [ordered]@{
                passed = $(if ($pesterResult) { [int]$pesterResult.PassedCount } else { 0 })
                failed = $(if ($pesterResult) { [int]$pesterResult.FailedCount } else { 0 })
                skipped = $(if ($pesterResult) { [int]$pesterResult.SkippedCount } else { 0 })
            }
            stages = @($stages)
            startedAt = $startedAt.ToString("o")
            finishedAt = [DateTime]::UtcNow.ToString("o")
            durationMs = [int64]$overallStopwatch.ElapsedMilliseconds
            error = $failure
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $qualificationFullPath) | Out-Null
        [System.IO.File]::WriteAllText($qualificationFullPath, ($qualification | ConvertTo-Json -Depth 12), $utf8NoBom)
    }
    Pop-Location
}

if ($failure) {
    Write-Error $failure
    exit 1
}

Write-Host "Fork $Mode gate passed. Summary: $summaryPath"
if ($Mode -eq "Full") { Write-Host "Qualification: $qualificationFullPath" }
