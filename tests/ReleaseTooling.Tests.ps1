BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")

    function New-TestReleaseQualification([string]$ForkRoot, [string]$ArtifactRoot) {
        $scriptsDir = Join-Path $ForkRoot "scripts"
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:ForkRoot "scripts\check.ps1") -Destination (Join-Path $scriptsDir "check.ps1") -Force
        Copy-Item -LiteralPath (Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1") -Destination (Join-Path $scriptsDir "publish-fork-release.ps1") -Force
        [System.IO.File]::WriteAllText((Join-Path $ForkRoot ".gitignore"), "build/`n", [System.Text.UTF8Encoding]::new($false))
        & git -C $ForkRoot add scripts .gitignore
        & git -C $ForkRoot commit -m "fixture: add qualified release tooling" | Out-Null

        New-Item -ItemType Directory -Path $ArtifactRoot -Force | Out-Null
        $junitPath = Join-Path $ArtifactRoot "pester.xml"
        [System.IO.File]::WriteAllText($junitPath, '<testsuites tests="0" failures="0"/>', [System.Text.UTF8Encoding]::new($false))
        $qualificationPath = Join-Path $ArtifactRoot "full.json"
        $commit = (& git -C $ForkRoot rev-parse HEAD).Trim()
        $tree = (& git -C $ForkRoot rev-parse 'HEAD^{tree}').Trim()
        $branch = (& git -C $ForkRoot branch --show-current).Trim()
        $qualification = [ordered]@{
            schemaVersion = 1
            kind = "itl-ai-rules-full-qualification"
            status = "passed"
            reusable = $true
            repository = [ordered]@{ name = "fixture"; commit = $commit; tree = $tree; branch = $branch; worktreeClean = $true }
            provenance = [ordered]@{ nearestForkTag = ""; upstreamRef = ""; upstreamCommit = "" }
            environment = [ordered]@{}
            inventory = [ordered]@{
                tests = @()
                scripts = @(
                    [ordered]@{ path = "scripts/check.ps1"; sha256 = (Get-FileHash -LiteralPath (Join-Path $scriptsDir "check.ps1") -Algorithm SHA256).Hash.ToLowerInvariant() }
                    [ordered]@{ path = "scripts/publish-fork-release.ps1"; sha256 = (Get-FileHash -LiteralPath (Join-Path $scriptsDir "publish-fork-release.ps1") -Algorithm SHA256).Hash.ToLowerInvariant() }
                )
            }
            junit = [ordered]@{ path = $junitPath.Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $junitPath -Algorithm SHA256).Hash.ToLowerInvariant() }
            result = [ordered]@{ passed = 0; failed = 0; skipped = 0 }
            stages = @()
            startedAt = [DateTime]::UtcNow.ToString("o")
            finishedAt = [DateTime]::UtcNow.ToString("o")
            durationMs = 0
            error = $null
        }
        [System.IO.File]::WriteAllText($qualificationPath, ($qualification | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        return $qualificationPath
    }
}

Describe "Fork release tooling" -Tag "Fast" {
    It "parses the intake and publish scripts" {
        foreach ($name in @("new-upstream-upgrade.ps1", "publish-fork-release.ps1")) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                (Join-Path $script:ForkRoot "scripts\$name"),
                [ref]$tokens,
                [ref]$errors
            )
            @($errors) | Should -BeNullOrEmpty
        }
    }

    It "derives the repository root at runtime instead of in param defaults" {
        foreach ($name in @("new-upstream-upgrade.ps1", "publish-fork-release.ps1")) {
            $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\$name") -Raw -Encoding UTF8
            $text | Should -Match '\[string\]\$RepositoryRoot = ""'
            $text | Should -Match '\$PSCommandPath'
            $text | Should -Not -Match '\$RepositoryRoot = \(Split-Path -Parent \$PSScriptRoot\)'
        }
    }

    It "requires immutable source input and atomic tag publication" {
        $intake = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\new-upstream-upgrade.ps1") -Raw -Encoding UTF8
        $publish = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1") -Raw -Encoding UTF8
        $intake | Should -Match "refs/tags/"
        $intake | Should -Match "\^\[0-9a-fA-F\]\{40\}\$"
        $intake | Should -Match "must equal the current remote tip"
        $publish | Should -Match 'push", "--atomic"'
        $publish | Should -Match 'itl-\$normalizedSource-r\$Revision'
        $publish | Should -Match 'upgrade/\$normalizedSource-r\$Revision'
        $publish | Should -Match "Test-ReusableQualification"
        $publish | Should -Not -Match "SkipCheck"
    }

    It "emits a versioned Full qualification with exact inventory and stage timings" {
        $check = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\check.ps1") -Raw -Encoding UTF8
        $check | Should -Match '\[string\]\$QualificationPath'
        $check | Should -Match 'schemaVersion = 2'
        $check | Should -Match 'itl-ai-rules-full-qualification'
        $check | Should -Match 'inventory = \[ordered\]'
        $check | Should -Match 'durationMs'
        $check | Should -Match 'junit = \[ordered\]'
        $check | Should -Match 'git tag --merged HEAD --list "itl-\*"'
        $check | Should -Not -Match 'git describe --tags'
    }
}

Describe "Upstream intake behavior" {
    It "creates an upgrade branch directly from a real remote tag" {
        $testRoot = New-ForkTestRoot
        try {
            $remoteRoot = Join-Path $testRoot "upstream.git"
            $sourceRoot = Join-Path $testRoot "source"
            $forkRoot = Join-Path $testRoot "fork"
            & git init --bare $remoteRoot | Out-Null
            & git init $sourceRoot | Out-Null
            & git -C $sourceRoot config user.email "test@example.invalid"
            & git -C $sourceRoot config user.name "ITL Test"
            Set-Content -LiteralPath (Join-Path $sourceRoot "install.ps1") -Encoding ASCII -Value "`$script:ProtocolVersion = '1.0'"
            Set-Content -LiteralPath (Join-Path $sourceRoot "AGENTS.md") -Encoding ASCII -Value "fixture"
            & git -C $sourceRoot add .
            & git -C $sourceRoot commit -m "fixture" | Out-Null
            & git -C $sourceRoot tag "v2.0.0"
            & git -C $sourceRoot remote add origin $remoteRoot
            & git -C $sourceRoot push origin HEAD:main --tags | Out-Null
            & git --git-dir=$remoteRoot symbolic-ref HEAD refs/heads/main
            & git clone $remoteRoot $forkRoot | Out-Null
            & git -C $forkRoot remote add upstream $remoteRoot

            $scriptPath = Join-Path $script:ForkRoot "scripts\new-upstream-upgrade.ps1"
            $result = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @(
                "-UpstreamTag", "v2.0.0", "-Remote", "upstream", "-RepositoryRoot", $forkRoot
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            (& git -C $forkRoot branch --show-current).Trim() | Should -Be "upgrade/v2.0.0"
            (& git -C $forkRoot rev-parse HEAD).Trim() | Should -Be (& git -C $forkRoot rev-parse "v2.0.0^{commit}").Trim()
            Test-Path -LiteralPath (Join-Path $forkRoot "build\reports\upstream-intake-v2.0.0.json") | Should -BeTrue

            $publishPath = Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1"
            $qualificationPath = New-TestReleaseQualification -ForkRoot $forkRoot -ArtifactRoot (Join-Path $testRoot "qualification")
            $publishResult = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                "-UpstreamTag", "v2.0.0", "-RepositoryRoot", $forkRoot,
                "-UpstreamRemote", "upstream", "-PublishRemote", "origin", "-QualificationPath", $qualificationPath
            )
            $publishResult.ExitCode | Should -Be 0 -Because $publishResult.Output
            (& git -C $forkRoot cat-file -t "refs/tags/itl-v2.0.0-r1").Trim() | Should -Be "tag"
            (& git -C $forkRoot rev-parse "release/itl-v2.0.0-r1").Trim() | Should -Be (& git -C $forkRoot rev-parse HEAD).Trim()
            @(& git -C $forkRoot ls-remote --tags origin "refs/tags/itl-v2.0.0-r1").Count | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "freezes the current upstream branch tip as a full commit snapshot" {
        $testRoot = New-ForkTestRoot
        try {
            $remoteRoot = Join-Path $testRoot "upstream.git"
            $sourceRoot = Join-Path $testRoot "source"
            $forkRoot = Join-Path $testRoot "fork"
            & git init --bare $remoteRoot | Out-Null
            & git init $sourceRoot | Out-Null
            & git -C $sourceRoot config user.email "test@example.invalid"
            & git -C $sourceRoot config user.name "ITL Test"
            Set-Content -LiteralPath (Join-Path $sourceRoot "install.ps1") -Encoding ASCII -Value "`$script:ProtocolVersion = '1.0'"
            Set-Content -LiteralPath (Join-Path $sourceRoot "AGENTS.md") -Encoding ASCII -Value "fixture"
            & git -C $sourceRoot add .
            & git -C $sourceRoot commit -m "first" | Out-Null
            $staleCommit = (& git -C $sourceRoot rev-parse HEAD).Trim()
            Add-Content -LiteralPath (Join-Path $sourceRoot "AGENTS.md") -Encoding ASCII -Value "current"
            & git -C $sourceRoot add AGENTS.md
            & git -C $sourceRoot commit -m "current" | Out-Null
            $currentCommit = (& git -C $sourceRoot rev-parse HEAD).Trim()
            & git -C $sourceRoot remote add origin $remoteRoot
            & git -C $sourceRoot push origin HEAD:main | Out-Null
            & git --git-dir=$remoteRoot symbolic-ref HEAD refs/heads/main
            & git clone $remoteRoot $forkRoot | Out-Null
            & git -C $forkRoot remote add upstream $remoteRoot

            $scriptPath = Join-Path $script:ForkRoot "scripts\new-upstream-upgrade.ps1"
            $staleResult = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @(
                "-UpstreamCommit", $staleCommit, "-UpstreamBranch", "main",
                "-Remote", "upstream", "-RepositoryRoot", $forkRoot
            )
            $staleResult.ExitCode | Should -Not -Be 0
            $staleResult.Output | Should -Match "must equal the current remote tip"

            $result = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @(
                "-UpstreamCommit", $currentCommit, "-UpstreamBranch", "main",
                "-Remote", "upstream", "-RepositoryRoot", $forkRoot
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $sourceId = "main-$($currentCommit.Substring(0, 8))"
            (& git -C $forkRoot branch --show-current).Trim() | Should -Be "upgrade/$sourceId"
            (& git -C $forkRoot rev-parse HEAD).Trim() | Should -Be $currentCommit
            $reportPath = Join-Path $forkRoot "build\reports\upstream-intake-$sourceId.json"
            Test-Path -LiteralPath $reportPath | Should -BeTrue
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $report.upstreamSourceKind | Should -Be "commit"
            $report.upstreamRef | Should -Be "refs/heads/main"
            $report.upstreamCommit | Should -Be $currentCommit

            $publishPath = Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1"
            $qualificationPath = New-TestReleaseQualification -ForkRoot $forkRoot -ArtifactRoot (Join-Path $testRoot "qualification")
            $publishResult = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                "-UpstreamCommit", $currentCommit, "-UpstreamBranch", "main",
                "-RepositoryRoot", $forkRoot, "-UpstreamRemote", "upstream",
                "-PublishRemote", "origin", "-QualificationPath", $qualificationPath
            )
            $publishResult.ExitCode | Should -Be 0 -Because $publishResult.Output
            (& git -C $forkRoot cat-file -t "refs/tags/itl-$sourceId-r1").Trim() | Should -Be "tag"
            $annotation = (& git -C $forkRoot for-each-ref "--format=%(contents)" "refs/tags/itl-$sourceId-r1") -join "`n"
            $annotation | Should -Match "refs/heads/main@$currentCommit"

            & git -C $forkRoot branch -m "upgrade/$sourceId-r2"
            $publishR2 = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                "-UpstreamCommit", $currentCommit, "-UpstreamBranch", "main", "-Revision", "2",
                "-RepositoryRoot", $forkRoot, "-UpstreamRemote", "upstream",
                "-PublishRemote", "origin", "-QualificationPath", $qualificationPath
            )
            $publishR2.ExitCode | Should -Be 0 -Because $publishR2.Output
            (& git -C $forkRoot cat-file -t "refs/tags/itl-$sourceId-r2").Trim() | Should -Be "tag"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
