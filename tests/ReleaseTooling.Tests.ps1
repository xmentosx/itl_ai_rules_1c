BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
    . (Join-Path $script:ForkRoot 'scripts/full-check-contract.ps1')

    function New-TestInventoryCheckout {
        $parent = New-ForkTestRoot
        $root = Join-Path $parent 'Инвентарь с пробелом'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $files = @('install.ps1', 'AGENTS.md', 'USER-RULES.md',
            'tools/validate-rules.ps1', 'tools/render-gate-evals.ps1',
            'tools/refresh-openspec-bundle.ps1', 'tools/apply-openspec-downstream-overlay.ps1',
            'content/skills/md-to-docx/package.json', 'content/skills/md-to-docx/package-lock.json',
            'scripts/check.ps1', 'scripts/full-check-contract.ps1', 'scripts/publish-fork-release.ps1')
        foreach ($relative in $files) {
            $path = Join-Path $root ($relative.Replace('/', '\'))
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot ($relative.Replace('/', '\'))) -Destination $path
        }
        foreach ($relative in @('tests/тест с пробелом.ps1', 'tools/tests/исходник с пробелом.json',
            'adapters/fixture.yaml', 'plugins/1c-rules/fixture.json', 'content/openspec-bundle/fixture.md')) {
            $path = Join-Path $root ($relative.Replace('/', '\'))
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
            [IO.File]::WriteAllText($path, "tracked fixture: Кириллица с пробелом`n", [Text.UTF8Encoding]::new($false))
        }
        [IO.File]::WriteAllText((Join-Path $root '.gitignore'), "*.generated.*`nbuild/`n", [Text.UTF8Encoding]::new($false))
        foreach ($arguments in @(@('init', '--quiet', $root), @('-C', $root, 'config', 'user.email', 'test@example.invalid'),
            @('-C', $root, 'config', 'user.name', 'ITL Test'), @('-C', $root, 'add', '--all'),
            @('-C', $root, 'commit', '--quiet', '-m', 'fixture: tracked inventory'))) {
            $gitResult = Invoke-TestNativeCommand -FilePath 'git' -Arguments $arguments
            if ($gitResult.ExitCode -ne 0) { throw $gitResult.Output }
        }
        return [pscustomobject]@{ Root = $root; Parent = $parent }
    }

    function Remove-TestInventoryCheckout($Checkout) {
        $parent = [IO.Path]::GetFullPath([string]$Checkout.Parent)
        $prefix = Join-Path ([IO.Path]::GetFullPath([IO.Path]::GetTempPath())) 'itl-ai-rules-test-'
        if (-not $parent.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected inventory fixture cleanup path.' }
        Remove-Item -LiteralPath $parent -Recurse -Force
    }

    function New-TestReleaseQualification([string]$ForkRoot, [string]$ArtifactRoot) {
        $scriptsDir = Join-Path $ForkRoot "scripts"
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:ForkRoot "scripts\check.ps1") -Destination (Join-Path $scriptsDir "check.ps1") -Force
        Copy-Item -LiteralPath (Join-Path $script:ForkRoot "scripts\full-check-contract.ps1") -Destination (Join-Path $scriptsDir "full-check-contract.ps1") -Force
        Copy-Item -LiteralPath (Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1") -Destination (Join-Path $scriptsDir "publish-fork-release.ps1") -Force
        foreach ($directory in @('tests', 'tools/tests', 'adapters', 'plugins/1c-rules', 'content/openspec-bundle')) {
            $destination = Join-Path $ForkRoot ($directory.Replace('/', '\'))
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot ($directory.Replace('/', '\'))) -Destination $destination -Recurse
        }
        foreach ($relative in @('install.ps1', 'AGENTS.md', 'USER-RULES.md',
                'tools/validate-rules.ps1', 'tools/render-gate-evals.ps1',
                'tools/refresh-openspec-bundle.ps1', 'tools/apply-openspec-downstream-overlay.ps1',
                'content/skills/md-to-docx/package.json', 'content/skills/md-to-docx/package-lock.json')) {
            $destination = Join-Path $ForkRoot ($relative.Replace('/', '\'))
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot ($relative.Replace('/', '\'))) -Destination $destination -Force
        }
        [System.IO.File]::WriteAllText((Join-Path $ForkRoot ".gitignore"), "build/`n", [System.Text.UTF8Encoding]::new($false))
        & git -C $ForkRoot add .
        & git -C $ForkRoot commit -m "fixture: add qualified release tooling" | Out-Null

        New-Item -ItemType Directory -Path $ArtifactRoot -Force | Out-Null
        $junitPath = Join-Path $ArtifactRoot "pester.xml"
        [System.IO.File]::WriteAllText($junitPath, '<testsuites tests="0" failures="0"/>', [System.Text.UTF8Encoding]::new($false))
        $qualificationPath = Join-Path $ArtifactRoot "full.json"
        $commit = (& git -C $ForkRoot rev-parse HEAD).Trim()
        $tree = (& git -C $ForkRoot rev-parse 'HEAD^{tree}').Trim()
        $branch = (& git -C $ForkRoot branch --show-current).Trim()
        $qualification = [ordered]@{
            schemaVersion = 2
            kind = "itl-ai-rules-full-qualification"
            status = "passed"
            reusable = $true
            repository = [ordered]@{ name = "itl_ai_rules_1c"; commit = $commit; tree = $tree; branch = $branch; worktreeClean = $true }
            provenance = [ordered]@{ nearestForkTag = ""; upstreamRef = ""; upstreamCommit = "" }
            environment = [ordered]@{ externalRuntime = (Get-ForkFullRuntimeIdentity) }
            inventory = [ordered]@{
                tests = @(Get-ChildItem -LiteralPath (Join-Path $ForkRoot 'tests') -Recurse -File -Filter '*.ps1' |
                    Sort-Object FullName | ForEach-Object {
                        [ordered]@{
                            path = $_.FullName.Substring($ForkRoot.Length).TrimStart([char[]]'\/').Replace('\', '/')
                            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                        }
                    })
                scripts = @(
                    [ordered]@{ path = "scripts/check.ps1"; sha256 = (Get-FileHash -LiteralPath (Join-Path $scriptsDir "check.ps1") -Algorithm SHA256).Hash.ToLowerInvariant() }
                    [ordered]@{ path = "scripts/full-check-contract.ps1"; sha256 = (Get-FileHash -LiteralPath (Join-Path $scriptsDir "full-check-contract.ps1") -Algorithm SHA256).Hash.ToLowerInvariant() }
                    [ordered]@{ path = "scripts/publish-fork-release.ps1"; sha256 = (Get-FileHash -LiteralPath (Join-Path $scriptsDir "publish-fork-release.ps1") -Algorithm SHA256).Hash.ToLowerInvariant() }
                )
                fullInputs = @(Get-ForkFullInventory -RepositoryRoot $ForkRoot)
                requiredStages = @(Get-ForkRequiredFullStageNames)
            }
            junit = [ordered]@{ path = $junitPath.Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $junitPath -Algorithm SHA256).Hash.ToLowerInvariant() }
            result = [ordered]@{ passed = 0; failed = 0; skipped = 0 }
            stages = @(Get-ForkRequiredFullStageNames | ForEach-Object { [ordered]@{ name = $_; status = 'passed' } })
            startedAt = [DateTime]::UtcNow.ToString("o")
            finishedAt = [DateTime]::UtcNow.ToString("o")
            durationMs = 0
            error = $null
        }
        [System.IO.File]::WriteAllText($qualificationPath, ($qualification | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        return $qualificationPath
    }
}

Describe 'Fork Full input inventory' {
    It 'ignores generated outputs and preserves tracked Unicode paths across required roots' {
        $checkout = New-TestInventoryCheckout
        try {
            $before = @(Get-ForkFullInventory -RepositoryRoot $checkout.Root)
            $before.path | Should -Contain 'tools/tests/исходник с пробелом.json'
            $before.path | Should -Contain 'tests/тест с пробелом.ps1'
            foreach ($relative in @('tests/fixture.generated.json', 'tools/tests/driver.generated.ps1',
                'tools/tests/render.generated.md', 'tools/tests/qualification.generated.json',
                'adapters/runtime.generated.log', 'plugins/1c-rules/runtime.generated.log',
                'content/openspec-bundle/render.generated.md')) {
                $path = Join-Path $checkout.Root ($relative.Replace('/', '\'))
                [IO.File]::WriteAllText($path, "generated artifact: Кириллица с пробелом`n", [Text.UTF8Encoding]::new($false))
                (Invoke-TestNativeCommand -FilePath 'git' -Arguments @('-C', $checkout.Root, 'check-ignore', '--', $relative)).ExitCode | Should -Be 0
            }
            $after = @(Get-ForkFullInventory -RepositoryRoot $checkout.Root)
            ($after | ConvertTo-Json -Depth 5 -Compress) | Should -BeExactly ($before | ConvertTo-Json -Depth 5 -Compress)
        } finally { Remove-TestInventoryCheckout $checkout }
    }

    It 'shares inventory with the qualification reader and invalidates tracked edits while retaining the clean guard' {
        $checkout = New-TestInventoryCheckout
        try {
            $RepositoryRoot = $checkout.Root
            $tokens = $null; $errors = $null
            $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $script:ForkRoot 'scripts/publish-fork-release.ps1'), [ref]$tokens, [ref]$errors)
            $reader = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-ReusableQualification' }, $false)
            . ([scriptblock]::Create($reader.Extent.Text))
            Mock Get-ForkFullRuntimeIdentity { return [ordered]@{ fixture = 'inventory-reader-only' } }
            $commit = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
            $tree = (& git -C $RepositoryRoot rev-parse 'HEAD^{tree}').Trim()
            $artifactRoot = Join-Path $RepositoryRoot 'build/qualification'
            New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
            $junit = Join-Path $artifactRoot 'pester.xml'
            [IO.File]::WriteAllText($junit, '<testsuites tests="0" failures="0"/>', [Text.UTF8Encoding]::new($false))
            $scripts = @('scripts/check.ps1', 'scripts/full-check-contract.ps1', 'scripts/publish-fork-release.ps1')
            $qualified = [ordered]@{
                schemaVersion = 2; kind = 'itl-ai-rules-full-qualification'; status = 'passed'; reusable = $true
                repository = @{ commit = $commit; tree = $tree; worktreeClean = $true }
                environment = @{ externalRuntime = (Get-ForkFullRuntimeIdentity) }
                inventory = @{
                    tests = @((Get-ForkFullInventory -RepositoryRoot $RepositoryRoot) | Where-Object { $_.path -like 'tests/*.ps1' })
                    scripts = @(foreach ($relative in $scripts) { @{ path = $relative; sha256 = (Get-FileHash -LiteralPath (Join-Path $RepositoryRoot $relative)).Hash.ToLowerInvariant() } })
                    fullInputs = @(Get-ForkFullInventory -RepositoryRoot $RepositoryRoot)
                    requiredStages = @(Get-ForkRequiredFullStageNames)
                }
                stages = @(Get-ForkRequiredFullStageNames | ForEach-Object { @{ name = $_; status = 'passed' } })
                junit = @{ path = $junit; sha256 = (Get-FileHash -LiteralPath $junit).Hash.ToLowerInvariant() }
            }
            $qualificationPath = Join-Path $artifactRoot 'full.json'
            [IO.File]::WriteAllText($qualificationPath, ($qualified | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
            Test-ReusableQualification -Path $qualificationPath -HeadCommit $commit -HeadTree $tree | Should -BeTrue
            [IO.File]::WriteAllText((Join-Path $RepositoryRoot 'tools/tests/qualification.generated.json'), '{"generated":true}', [Text.UTF8Encoding]::new($false))
            Test-ReusableQualification -Path $qualificationPath -HeadCommit $commit -HeadTree $tree | Should -BeTrue
            [IO.File]::AppendAllText((Join-Path $RepositoryRoot 'adapters/fixture.yaml'), "source edit`n", [Text.UTF8Encoding]::new($false))
            Test-ReusableQualification -Path $qualificationPath -HeadCommit $commit -HeadTree $tree | Should -BeFalse
            $probe = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'scripts/publish-fork-release.ps1') -Arguments @(
                '-UpstreamTag', 'fixture', '-RepositoryRoot', $RepositoryRoot, '-QualificationPath', $qualificationPath, '-QualificationProbeOnly')
            $probe.ExitCode | Should -Not -Be 0
            $probe.Output | Should -Match 'Qualification probe requires a clean worktree'
        } finally { Remove-TestInventoryCheckout $checkout }
    }

    It 'retains missing mandatory input failure for <Kind>' -TestCases @(
        @{ Kind = 'directory'; Relative = 'adapters' }
        @{ Kind = 'explicit file'; Relative = 'AGENTS.md' }
        @{ Kind = 'tracked file'; Relative = 'tools/tests/исходник с пробелом.json' }
    ) {
        param($Kind, $Relative)
        $checkout = New-TestInventoryCheckout
        try {
            $target = [IO.Path]::GetFullPath((Join-Path $checkout.Root $Relative))
            $root = [IO.Path]::GetFullPath($checkout.Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected missing-input fixture path.' }
            Remove-Item -LiteralPath $target -Recurse -Force
            { Get-ForkFullInventory -RepositoryRoot $checkout.Root } | Should -Throw '*FULL_CHECK_INPUT_MISSING:*'
        } finally { Remove-TestInventoryCheckout $checkout }
    }
}

Describe "Fork release tooling" -Tag "Fast" {
    It "parses the intake and publish scripts" {
        foreach ($name in @("check.ps1", "new-upstream-upgrade.ps1", "publish-fork-release.ps1")) {
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

    It "sets an explicit UTF-8 boundary for redirected qualification" {
        $check = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\check.ps1") -Raw -Encoding UTF8
        $check | Should -Match '\[Console\]::OutputEncoding = \$utf8'
        $check | Should -Match '\$OutputEncoding = \$utf8'
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
        $publish | Should -Match '\$\{resolvedUpstreamCommit\}:refs/heads/main'
        $publish | Should -Match 'itl-\$normalizedSource-r\$Revision'
        $publish | Should -Match 'upgrade/\$normalizedSource-r\$Revision'
        $publish | Should -Match 'CommitAbbreviationLength'
        $publish | Should -Match "Test-ReusableQualification"
        $publish | Should -Match '\$publishWhatIfPreference = \$WhatIfPreference'
        $publish | Should -Match '(?s)\$WhatIfPreference = \$false.*?Test-ReusableQualification.*?\$WhatIfPreference = \$publishWhatIfPreference.*?ShouldProcess'
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
        $check | Should -Match 'git diff --check "\$resolvedUpstreamCommit\.\.HEAD"'
        $check | Should -Match 'Full requires -UpstreamCommit before publication'
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
            $probe = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                '-UpstreamTag', 'v2.0.0', '-RepositoryRoot', $forkRoot,
                '-QualificationPath', $qualificationPath, '-QualificationProbeOnly'
            )
            $probe.ExitCode | Should -Be 0 -Because $probe.Output
            $proofBytes = [IO.File]::ReadAllBytes($qualificationPath)
            $oldProof = Get-Content -LiteralPath $qualificationPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $oldProof.schemaVersion = 1
            [IO.File]::WriteAllText($qualificationPath, ($oldProof | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
            $legacyProbe = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                '-UpstreamTag', 'v2.0.0', '-RepositoryRoot', $forkRoot,
                '-QualificationPath', $qualificationPath, '-QualificationProbeOnly'
            )
            $legacyProbe.ExitCode | Should -Not -Be 0
            $legacyProbe.Output | Should -Match 'Qualification schema or kind mismatch'
            [IO.File]::WriteAllBytes($qualificationPath, $proofBytes)
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
                "-PublishRemote", "origin", "-QualificationPath", $qualificationPath, "-Push"
            )
            $publishResult.ExitCode | Should -Be 0 -Because $publishResult.Output
            (& git -C $forkRoot cat-file -t "refs/tags/itl-$sourceId-r1").Trim() | Should -Be "tag"
            $annotation = (& git -C $forkRoot for-each-ref "--format=%(contents)" "refs/tags/itl-$sourceId-r1") -join "`n"
            $annotation | Should -Match "refs/heads/main@$currentCommit"
            (& git -C $forkRoot rev-parse "refs/remotes/origin/main").Trim() | Should -Be $currentCommit
            @(& git -C $forkRoot ls-remote --tags origin "refs/tags/itl-$sourceId-r1").Count | Should -Be 1
            @(& git -C $forkRoot ls-remote --heads origin "refs/heads/release/itl-$sourceId-r1").Count | Should -Be 1

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

Describe "Metadata scaffold repeatability" {
    It "updates explicit form and template metadata without overwriting authored content" {
        $testRoot = Join-Path ([IO.Path]::GetTempPath()) ("itl-metadata-repeatability-" + [guid]::NewGuid().ToString("N"))
        try {
            $reportsDir = Join-Path $testRoot "Reports"
            New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
            $objectPath = Join-Path $reportsDir "SmokeReport.xml"
            $objectXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" xmlns:v8="http://v8.1c.ru/8.1/data/core" version="2.17">
  <Report uuid="11111111-1111-1111-1111-111111111111">
    <Properties>
      <Name>SmokeReport</Name>
      <Synonym><v8:item><v8:lang>ru</v8:lang><v8:content>Smoke</v8:content></v8:item></Synonym>
      <DefaultForm/>
      <MainDataCompositionSchema/>
    </Properties>
    <ChildObjects/>
  </Report>
</MetaDataObject>
'@
            [IO.File]::WriteAllText($objectPath, $objectXml, [Text.UTF8Encoding]::new($true))

            $formScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-form-scaffold\scripts\form-add.ps1"
            $firstForm = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @(
                "-ObjectPath", $objectPath, "-FormName", "MainForm", "-Synonym", "Draft form", "-SetDefault"
            )
            $firstForm.ExitCode | Should -Be 0 -Because $firstForm.Output

            $formRoot = Join-Path $reportsDir "SmokeReport\Forms\MainForm\Ext"
            $formContentPath = Join-Path $formRoot "Form.xml"
            $modulePath = Join-Path $formRoot "Form\Module.bsl"
            $authoredForm = [Text.UTF8Encoding]::new($false).GetBytes("<Form>authored form</Form>")
            $authoredModule = [Text.UTF8Encoding]::new($false).GetBytes("Procedure Authored()`nEndProcedure")
            [IO.File]::WriteAllBytes($formContentPath, $authoredForm)
            [IO.File]::WriteAllBytes($modulePath, $authoredModule)
            $formContentBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($formContentPath))
            $moduleBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($modulePath))

            $secondForm = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @(
                "-ObjectPath", $objectPath, "-FormName", "MainForm", "-Synonym", "Final form", "-SetDefault"
            )
            $secondForm.ExitCode | Should -Be 0 -Because $secondForm.Output
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($formContentPath)) | Should -Be $formContentBefore
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($modulePath)) | Should -Be $moduleBefore

            $templateScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-template-manage\scripts\add-template.ps1"
            $firstTemplate = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @(
                "-ObjectName", "SmokeReport", "-TemplateName", "MainSchema", "-TemplateType", "DataCompositionSchema",
                "-Synonym", "Draft schema", "-SrcDir", $reportsDir, "-SetMainSKD"
            )
            $firstTemplate.ExitCode | Should -Be 0 -Because $firstTemplate.Output

            $templateContentPath = Join-Path $reportsDir "SmokeReport\Templates\MainSchema\Ext\Template.xml"
            $authoredTemplate = [Text.UTF8Encoding]::new($false).GetBytes("<DataCompositionSchema>authored schema</DataCompositionSchema>")
            [IO.File]::WriteAllBytes($templateContentPath, $authoredTemplate)
            $templateBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($templateContentPath))

            $secondTemplate = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @(
                "-ObjectName", "SmokeReport", "-TemplateName", "MainSchema", "-TemplateType", "DataCompositionSchema",
                "-Synonym", "Final schema", "-SrcDir", $reportsDir, "-SetMainSKD"
            )
            $secondTemplate.ExitCode | Should -Be 0 -Because $secondTemplate.Output
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($templateContentPath)) | Should -Be $templateBefore

            $rootDoc = New-Object System.Xml.XmlDocument
            $rootDoc.Load($objectPath)
            $rootNs = New-Object System.Xml.XmlNamespaceManager($rootDoc.NameTable)
            $rootNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            @($rootDoc.SelectNodes("//md:ChildObjects/md:Form[text()='MainForm']", $rootNs)).Count | Should -Be 1
            @($rootDoc.SelectNodes("//md:ChildObjects/md:Template[text()='MainSchema']", $rootNs)).Count | Should -Be 1
            $rootDoc.SelectSingleNode("//md:Report/md:Properties/md:DefaultForm", $rootNs).InnerText | Should -Be "Report.SmokeReport.Form.MainForm"
            $rootDoc.SelectSingleNode("//md:Report/md:Properties/md:MainDataCompositionSchema", $rootNs).InnerText | Should -Be "Report.SmokeReport.Template.MainSchema"

            $formMetaDoc = New-Object System.Xml.XmlDocument
            $formMetaDoc.Load((Join-Path $reportsDir "SmokeReport\Forms\MainForm.xml"))
            $formMetaNs = New-Object System.Xml.XmlNamespaceManager($formMetaDoc.NameTable)
            $formMetaNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $formMetaNs.AddNamespace("v8", "http://v8.1c.ru/8.1/data/core")
            $formMetaDoc.SelectSingleNode("//md:Synonym/v8:item[v8:lang='ru']/v8:content", $formMetaNs).InnerText | Should -Be "Final form"
            $formUuidBefore = $formMetaDoc.SelectSingleNode('//md:Form', $formMetaNs).GetAttribute('uuid')
            $pythonFormScript = Join-Path $script:ForkRoot 'content\skills\1c-metadata-manage\tools\1c-form-scaffold\scripts\form-add.py'
            $pythonFormOutput = @(& python $pythonFormScript -ObjectPath $objectPath -FormName MainForm -Synonym 'Python final' -SetDefault 2>&1)
            $LASTEXITCODE | Should -Be 0 -Because ($pythonFormOutput -join "`n")
            $formMetaDoc.Load((Join-Path $reportsDir 'SmokeReport\Forms\MainForm.xml'))
            $formMetaDoc.SelectSingleNode('//md:Form', $formMetaNs).GetAttribute('uuid') | Should -Be $formUuidBefore
            $formMetaDoc.SelectSingleNode("//md:Synonym/v8:item[v8:lang='ru']/v8:content", $formMetaNs).InnerText | Should -Be 'Python final'
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($formContentPath)) | Should -Be $formContentBefore
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($modulePath)) | Should -Be $moduleBefore

            $templateMetaDoc = New-Object System.Xml.XmlDocument
            $templateMetaDoc.Load((Join-Path $reportsDir "SmokeReport\Templates\MainSchema.xml"))
            $templateMetaNs = New-Object System.Xml.XmlNamespaceManager($templateMetaDoc.NameTable)
            $templateMetaNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $templateMetaNs.AddNamespace("v8", "http://v8.1c.ru/8.1/data/core")
            $templateMetaDoc.SelectSingleNode("//md:Synonym/v8:item[v8:lang='ru']/v8:content", $templateMetaNs).InnerText | Should -Be "Final schema"

            $formMetaPath = Join-Path $reportsDir "SmokeReport\Forms\MainForm.xml"
            $formMetaText = [IO.File]::ReadAllText($formMetaPath)
            [IO.File]::WriteAllText($formMetaPath, $formMetaText.Replace('<FormType>Managed</FormType>', '<FormType>Ordinary</FormType>'))
            $formMetaBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($formMetaPath))
            $rootBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($objectPath))
            $incompatibleForm = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @(
                '-ObjectPath', $objectPath, '-FormName', 'MainForm', '-Synonym', 'Must not apply', '-SetDefault'
            )
            $incompatibleForm.ExitCode | Should -Be 1
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($formMetaPath)) | Should -Be $formMetaBefore
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($objectPath)) | Should -Be $rootBefore
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($formContentPath)) | Should -Be $formContentBefore
            $pythonIncompatible = Invoke-TestNativeCommand -FilePath 'python.exe' -Arguments @($pythonFormScript, '-ObjectPath', $objectPath, '-FormName', 'MainForm', '-Synonym', 'Must not apply', '-SetDefault')
            $pythonIncompatible.ExitCode | Should -Be 1 -Because $pythonIncompatible.Output
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($formMetaPath)) | Should -Be $formMetaBefore
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($objectPath)) | Should -Be $rootBefore

            $templateMetaPath = Join-Path $reportsDir "SmokeReport\Templates\MainSchema.xml"
            $templateMetaText = [IO.File]::ReadAllText($templateMetaPath)
            [IO.File]::WriteAllText($templateMetaPath, $templateMetaText.Replace('<TemplateType>DataCompositionSchema</TemplateType>', '<TemplateType>HTMLDocument</TemplateType>'))
            $templateMetaBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($templateMetaPath))
            $incompatibleTemplate = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @(
                '-ObjectName', 'SmokeReport', '-TemplateName', 'MainSchema', '-TemplateType', 'DataCompositionSchema',
                '-Synonym', 'Must not apply', '-SrcDir', $reportsDir, '-SetMainSKD'
            )
            $incompatibleTemplate.ExitCode | Should -Be 1
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($templateMetaPath)) | Should -Be $templateMetaBefore
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($objectPath)) | Should -Be $rootBefore
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($templateContentPath)) | Should -Be $templateBefore
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
