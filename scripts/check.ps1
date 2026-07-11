[CmdletBinding()]
param(
    [ValidateSet("Fast", "Full")]
    [string]$Mode = "Full",
    [string]$OutputDirectory = "build\test-results\local"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
}
$summaryPath = Join-Path $outputRoot "check-summary.json"
$junitPath = Join-Path $outputRoot "pester.xml"
$startedAt = [DateTime]::UtcNow
$pesterResult = $null
$failure = $null

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
Push-Location $repoRoot
try {
    & git diff --check HEAD -- .
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --check failed."
    }

    Import-Module Pester -MinimumVersion 5.0.0 -Force
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = @(".\tests")
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = "Detailed"
    if ($Mode -eq "Fast") {
        $configuration.Filter.Tag = @("Fast")
    }
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = "JUnitXml"
    $configuration.TestResult.OutputPath = $junitPath
    $pesterResult = Invoke-Pester -Configuration $configuration
    if ([string]$pesterResult.Result -ne "Passed") {
        throw "Pester did not pass: result=$($pesterResult.Result), failed=$($pesterResult.FailedCount)."
    }
} catch {
    $failure = $_.Exception.Message
} finally {
    $commit = (& git rev-parse HEAD 2>$null)
    $dirty = @(& git status --porcelain).Count -gt 0
    $summary = [ordered]@{
        schemaVersion = 1
        repository = "itl_ai_rules_1c"
        mode = $Mode
        status = $(if ($failure) { "failed" } else { "passed" })
        startedAt = $startedAt.ToString("o")
        finishedAt = [DateTime]::UtcNow.ToString("o")
        commit = [string]$commit
        worktreeClean = (-not $dirty)
        tests = [ordered]@{
            passed = $(if ($pesterResult) { [int]$pesterResult.PassedCount } else { 0 })
            failed = $(if ($pesterResult) { [int]$pesterResult.FailedCount } else { 0 })
            skipped = $(if ($pesterResult) { [int]$pesterResult.SkippedCount } else { 0 })
        }
        error = $failure
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 6), $utf8NoBom)
    Pop-Location
}

if ($failure) {
    Write-Error $failure
    exit 1
}

Write-Host "Fork $Mode gate passed. Summary: $summaryPath"
