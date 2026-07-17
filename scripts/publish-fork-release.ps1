[CmdletBinding(DefaultParameterSetName = "Tag", SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Tag")][string]$UpstreamTag,
    [Parameter(Mandatory = $true, ParameterSetName = "Commit")]
    [ValidatePattern("^[0-9a-fA-F]{40}$")][string]$UpstreamCommit,
    [Parameter(ParameterSetName = "Commit")][string]$UpstreamBranch = "main",
    [ValidateRange(1, 999)][int]$Revision = 1,
    [string]$UpstreamRemote = "upstream",
    [string]$PublishRemote = "origin",
    [string]$RepositoryRoot = "",
    [string]$QualificationPath = "build\test-results\qualification\full.json",
    [switch]$Push
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

function Test-RefExists {
    param([string]$Ref)
    & git -C $RepositoryRoot show-ref --verify --quiet $Ref
    return ($LASTEXITCODE -eq 0)
}

function Test-ReusableQualification {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$HeadCommit,
        [Parameter(Mandatory = $true)][string]$HeadTree
    )
    if (-not (Test-Path $Path -PathType Leaf)) { return $false }
    try {
        $qualification = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([int]$qualification.schemaVersion -ne 1 -or [string]$qualification.kind -ne "itl-ai-rules-full-qualification") { return $false }
        if ([string]$qualification.status -ne "passed" -or -not [bool]$qualification.reusable) { return $false }
        if ([string]$qualification.repository.commit -ne $HeadCommit -or [string]$qualification.repository.tree -ne $HeadTree) { return $false }
        if (-not [bool]$qualification.repository.worktreeClean) { return $false }

        $expectedTests = @($qualification.inventory.tests | ForEach-Object { [string]$_.path } | Sort-Object)
        $testsRoot = Join-Path $RepositoryRoot "tests"
        $actualTests = if (Test-Path $testsRoot -PathType Container) {
            @(Get-ChildItem -LiteralPath $testsRoot -Recurse -File -Filter "*.ps1" | ForEach-Object {
                $_.FullName.Substring($RepositoryRoot.Length).TrimStart([char[]]'\/').Replace('\', '/')
            } | Sort-Object)
        } else { @() }
        if (($expectedTests -join "`n") -ne ($actualTests -join "`n")) { return $false }

        $qualifiedScripts = @($qualification.inventory.scripts | ForEach-Object { ([string]$_.path).Replace('\', '/') } | Sort-Object)
        $requiredScripts = @("scripts/check.ps1", "scripts/publish-fork-release.ps1")
        if (($qualifiedScripts -join "`n") -ne ($requiredScripts -join "`n")) { return $false }

        foreach ($entry in @($qualification.inventory.tests) + @($qualification.inventory.scripts)) {
            $entryPath = if ([System.IO.Path]::IsPathRooted([string]$entry.path)) { [string]$entry.path } else { Join-Path $RepositoryRoot ([string]$entry.path).Replace('/', '\') }
            if (-not (Test-Path $entryPath -PathType Leaf)) { return $false }
            if ((Get-FileHash -LiteralPath $entryPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne ([string]$entry.sha256).ToLowerInvariant()) { return $false }
        }
        $junitPath = if ([System.IO.Path]::IsPathRooted([string]$qualification.junit.path)) { [string]$qualification.junit.path } else { Join-Path $RepositoryRoot ([string]$qualification.junit.path).Replace('/', '\') }
        if (-not (Test-Path $junitPath -PathType Leaf)) { return $false }
        if ((Get-FileHash -LiteralPath $junitPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne ([string]$qualification.junit.sha256).ToLowerInvariant()) { return $false }
        return $true
    } catch {
        return $false
    }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$qualificationFullPath = if ([System.IO.Path]::IsPathRooted($QualificationPath)) {
    [System.IO.Path]::GetFullPath($QualificationPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $QualificationPath))
}
$sourceKind = $PSCmdlet.ParameterSetName.ToLowerInvariant()
$sourceName = if ($sourceKind -eq "tag") {
    $UpstreamTag
} else {
    "$UpstreamBranch-$($UpstreamCommit.Substring(0, 8).ToLowerInvariant())"
}
$normalizedSource = (($sourceName -replace '[^A-Za-z0-9._-]', '-').Trim('-'))
$revisionUpgradeBranch = "upgrade/$normalizedSource-r$Revision"
$allowedUpgradeBranches = @($revisionUpgradeBranch)
if ($Revision -eq 1) {
    # Bootstrap releases created before revision-qualified upgrade branches
    # remain reproducible, while r2+ must use their own clean intake branch.
    $allowedUpgradeBranches += "upgrade/$normalizedSource"
}
$forkTag = "itl-$normalizedSource-r$Revision"
$releaseBranch = "release/$forkTag"

$status = @(Invoke-RepoGit -Arguments @("status", "--porcelain"))
if ($status.Count -gt 0) { throw "Fork worktree must be clean before release." }
$currentBranch = [string](Invoke-RepoGit -Arguments @("branch", "--show-current") | Select-Object -First 1)
if ($allowedUpgradeBranches -notcontains $currentBranch) {
    throw "Release r$Revision must be published from '$revisionUpgradeBranch'; current branch is '$currentBranch'."
}

[void](Invoke-RepoGit -Arguments @("fetch", $UpstreamRemote, "--tags", "--prune"))
$upstreamRef = ""
if ($sourceKind -eq "tag") {
    $upstreamRef = "refs/tags/$UpstreamTag"
    $resolvedUpstreamCommit = [string](Invoke-RepoGit -Arguments @("rev-parse", "--verify", "$upstreamRef^{commit}") | Select-Object -First 1)
} else {
    $upstreamRef = "refs/heads/$UpstreamBranch"
    $resolvedUpstreamCommit = ([string](Invoke-RepoGit -Arguments @("rev-parse", "--verify", "$UpstreamCommit^{commit}") | Select-Object -First 1)).ToLowerInvariant()
    if ($resolvedUpstreamCommit -ne $UpstreamCommit.ToLowerInvariant()) {
        throw "Resolved upstream commit differs from the requested full SHA: requested=$UpstreamCommit resolved=$resolvedUpstreamCommit"
    }
    $remoteLines = @(Invoke-RepoGit -Arguments @("ls-remote", "--heads", $UpstreamRemote, $upstreamRef))
    if ($remoteLines.Count -ne 1) {
        throw "Upstream branch does not resolve to exactly one remote ref: $UpstreamRemote/$UpstreamBranch"
    }
    $remoteTip = (([string]$remoteLines[0] -split '\s+')[0]).ToLowerInvariant()
    & git -C $RepositoryRoot merge-base --is-ancestor $resolvedUpstreamCommit $remoteTip
    if ($LASTEXITCODE -ne 0) {
        throw "Selected upstream snapshot $resolvedUpstreamCommit is no longer reachable from $UpstreamRemote/$UpstreamBranch ($remoteTip)."
    }
}
$headCommit = [string](Invoke-RepoGit -Arguments @("rev-parse", "HEAD") | Select-Object -First 1)
$headTree = [string](Invoke-RepoGit -Arguments @("rev-parse", "HEAD^{tree}") | Select-Object -First 1)
& git -C $RepositoryRoot merge-base --is-ancestor $resolvedUpstreamCommit $headCommit
if ($LASTEXITCODE -ne 0) {
    throw "Current release candidate is not based on upstream $sourceKind $upstreamRef ($resolvedUpstreamCommit)."
}

if (Test-ReusableQualification -Path $qualificationFullPath -HeadCommit $headCommit -HeadTree $headTree) {
    Write-Host "Reusing exact clean Full qualification: $qualificationFullPath"
} else {
    $checkPath = Join-Path $RepositoryRoot "scripts\check.ps1"
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $checkPath -Mode Full -QualificationPath $qualificationFullPath
    if ($LASTEXITCODE -ne 0) { throw "Fork Full gate failed." }
    if (-not (Test-ReusableQualification -Path $qualificationFullPath -HeadCommit $headCommit -HeadTree $headTree)) {
        throw "Fork Full gate did not produce an exact reusable qualification."
    }
}

if (Test-RefExists -Ref "refs/tags/$forkTag") { throw "Fork tag already exists locally: $forkTag" }
if (Test-RefExists -Ref "refs/heads/$releaseBranch") { throw "Release branch already exists locally: $releaseBranch" }
$remoteTag = @(& git -C $RepositoryRoot ls-remote --tags $PublishRemote "refs/tags/$forkTag")
if ($LASTEXITCODE -ne 0) { throw "Could not inspect remote tag: $forkTag" }
if ($remoteTag.Count -gt 0) { throw "Fork tag already exists remotely: $forkTag" }

$annotation = "ITL ai_rules_1c release $forkTag; upstream=$upstreamRef@$resolvedUpstreamCommit; fork=$headCommit"
$createdBranch = $false
$createdTag = $false
try {
    if ($PSCmdlet.ShouldProcess($RepositoryRoot, "create $releaseBranch and immutable tag $forkTag")) {
        [void](Invoke-RepoGit -Arguments @("branch", $releaseBranch, $headCommit))
        $createdBranch = $true
        [void](Invoke-RepoGit -Arguments @("tag", "--annotate", $forkTag, $headCommit, "--message", $annotation))
        $createdTag = $true

        if ($Push) {
            [void](Invoke-RepoGit -Arguments @(
                "push", "--atomic", $PublishRemote,
                "refs/heads/${releaseBranch}:refs/heads/${releaseBranch}",
                "refs/tags/${forkTag}:refs/tags/${forkTag}"
            ))
        }
    }
} catch {
    if ($createdTag) { & git -C $RepositoryRoot tag --delete $forkTag *> $null }
    if ($createdBranch) { & git -C $RepositoryRoot branch --delete --force $releaseBranch *> $null }
    throw
}

Write-Host "Release candidate: $forkTag -> $headCommit"
Write-Host "Upstream provenance: $sourceKind $upstreamRef -> $resolvedUpstreamCommit"
if (-not $Push) { Write-Host "Remote was not changed; pass -Push after review." }
