[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$UpstreamTag,
    [string]$Remote = "upstream",
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ReportDirectory = "build\reports"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Invoke-RepoGit {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = @(& git -C $RepositoryRoot @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }
    return @($output)
}

function Get-NormalizedTagName {
    param([string]$Value)
    $normalized = ($Value -replace '[^A-Za-z0-9._-]', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw "Upstream tag cannot be normalized into a branch name: $Value"
    }
    return $normalized
}

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot ".git"))) {
    throw "RepositoryRoot is not a Git working tree: $RepositoryRoot"
}

$status = @(Invoke-RepoGit -Arguments @("status", "--porcelain"))
if ($status.Count -gt 0) {
    throw "Fork worktree must be clean before upstream intake."
}

$originalHead = [string](Invoke-RepoGit -Arguments @("rev-parse", "HEAD") | Select-Object -First 1)
[void](Invoke-RepoGit -Arguments @("fetch", $Remote, "--tags", "--prune"))

$remoteLines = @(Invoke-RepoGit -Arguments @(
    "ls-remote", "--tags", $Remote,
    "refs/tags/$UpstreamTag", "refs/tags/$UpstreamTag^{}"
))
if ($remoteLines.Count -eq 0) {
    throw "Upstream tag does not exist on remote '$Remote': $UpstreamTag. upstream/main is not an allowed fallback."
}

$peeled = @($remoteLines | Where-Object { $_ -match '\^\{\}$' } | Select-Object -First 1)
$remoteCommit = if ($peeled.Count -gt 0) {
    ([string]$peeled[0] -split '\s+')[0]
} else {
    ([string]$remoteLines[0] -split '\s+')[0]
}
$localCommit = [string](Invoke-RepoGit -Arguments @("rev-parse", "--verify", "refs/tags/$UpstreamTag^{commit}") | Select-Object -First 1)
if ($localCommit -ne $remoteCommit) {
    throw "Fetched tag commit does not match remote: local=$localCommit remote=$remoteCommit"
}

$normalizedTag = Get-NormalizedTagName -Value $UpstreamTag
$upgradeBranch = "upgrade/$normalizedTag"
& git -C $RepositoryRoot show-ref --verify --quiet "refs/heads/$upgradeBranch"
if ($LASTEXITCODE -eq 0) {
    throw "Upgrade branch already exists: $upgradeBranch"
}

if ($PSCmdlet.ShouldProcess($RepositoryRoot, "create $upgradeBranch from upstream tag $UpstreamTag ($localCommit)")) {
    [void](Invoke-RepoGit -Arguments @("switch", "--create", $upgradeBranch, $localCommit))
}

$tagType = [string](Invoke-RepoGit -Arguments @("cat-file", "-t", "refs/tags/$UpstreamTag") | Select-Object -First 1)
$tree = [string](Invoke-RepoGit -Arguments @("rev-parse", "$localCommit^{tree}") | Select-Object -First 1)
$remoteUrl = [string](Invoke-RepoGit -Arguments @("remote", "get-url", $Remote) | Select-Object -First 1)
$bootstrapCommits = @(Invoke-RepoGit -Arguments @("rev-list", "--reverse", "$localCommit..$originalHead"))
$previousForkTag = @(Invoke-RepoGit -Arguments @("tag", "--list", "itl-*", "--sort=-creatordate") | Select-Object -First 1)

$installerPath = Join-Path $RepositoryRoot "install.ps1"
$protocol = ""
if (Test-Path -LiteralPath $installerPath -PathType Leaf) {
    $match = [regex]::Match((Get-Content -LiteralPath $installerPath -Raw -Encoding UTF8), "ProtocolVersion\s*=\s*'([^']+)'" )
    if ($match.Success) { $protocol = $match.Groups[1].Value }
}
$agentsPath = Join-Path $RepositoryRoot "AGENTS.md"
$agentsBytes = if (Test-Path -LiteralPath $agentsPath -PathType Leaf) {
    (Get-Item -LiteralPath $agentsPath).Length
} else { 0 }

$reportRoot = if ([System.IO.Path]::IsPathRooted($ReportDirectory)) {
    [System.IO.Path]::GetFullPath($ReportDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $ReportDirectory))
}
$repositoryPrefix = $RepositoryRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($reportRoot.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    $relativeReportRoot = $reportRoot.Substring($repositoryPrefix.Length).Replace('\', '/').Trim('/') + "/"
    $excludePath = [string](Invoke-RepoGit -Arguments @("rev-parse", "--git-path", "info/exclude") | Select-Object -First 1)
    if (-not [System.IO.Path]::IsPathRooted($excludePath)) {
        $excludePath = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $excludePath))
    }
    $excludeText = if (Test-Path -LiteralPath $excludePath -PathType Leaf) { Get-Content -LiteralPath $excludePath -Raw -Encoding UTF8 } else { "" }
    if ($excludeText -notmatch ("(?m)^" + [regex]::Escape($relativeReportRoot) + "$")) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $updatedExclude = $excludeText.TrimEnd() + [Environment]::NewLine + $relativeReportRoot + [Environment]::NewLine
        [System.IO.File]::WriteAllText($excludePath, $updatedExclude.TrimStart(), $utf8NoBom)
    }
}
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$reportPath = Join-Path $reportRoot ("upstream-intake-$normalizedTag.json")
$report = [ordered]@{
    schemaVersion = 1
    createdAt = [DateTime]::UtcNow.ToString("o")
    upstreamRemote = $remoteUrl
    upstreamTag = $UpstreamTag
    upstreamTagType = $tagType
    upstreamCommit = $localCommit
    upstreamTree = $tree
    upgradeBranch = $upgradeBranch
    previousForkTag = [string]($previousForkTag | Select-Object -First 1)
    bootstrapCommitsForReview = @($bootstrapCommits)
    baseline = [ordered]@{
        installerProtocol = $protocol
        agentsBytes = [long]$agentsBytes
    }
    patchDispositionRequired = @("keep", "drop", "rewrite")
    readyForAdaptation = $true
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 8), $utf8NoBom)

Write-Host "Created $upgradeBranch from $UpstreamTag at $localCommit"
Write-Host "Intake report: $reportPath"
