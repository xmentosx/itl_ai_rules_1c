BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
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

    It "requires immutable source input and atomic tag publication" {
        $intake = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\new-upstream-upgrade.ps1") -Raw -Encoding UTF8
        $publish = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1") -Raw -Encoding UTF8
        $intake | Should -Match "refs/tags/"
        $intake | Should -Match "\^\[0-9a-fA-F\]\{40\}\$"
        $intake | Should -Match "must equal the current remote tip"
        $publish | Should -Match 'push", "--atomic"'
        $publish | Should -Match 'itl-\$normalizedSource-r\$Revision'
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
            $publishResult = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                "-UpstreamTag", "v2.0.0", "-RepositoryRoot", $forkRoot,
                "-UpstreamRemote", "upstream", "-PublishRemote", "origin", "-SkipCheck"
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
            $publishResult = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                "-UpstreamCommit", $currentCommit, "-UpstreamBranch", "main",
                "-RepositoryRoot", $forkRoot, "-UpstreamRemote", "upstream",
                "-PublishRemote", "origin", "-SkipCheck"
            )
            $publishResult.ExitCode | Should -Be 0 -Because $publishResult.Output
            (& git -C $forkRoot cat-file -t "refs/tags/itl-$sourceId-r1").Trim() | Should -Be "tag"
            $annotation = (& git -C $forkRoot for-each-ref "--format=%(contents)" "refs/tags/itl-$sourceId-r1") -join "`n"
            $annotation | Should -Match "refs/heads/main@$currentCommit"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
