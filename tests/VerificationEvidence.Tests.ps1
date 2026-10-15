BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:VerificationProject = New-ForkTestRoot
}

AfterAll {
    Remove-Item -LiteralPath $script:VerificationProject -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'AI validation evidence retained through upstream verification split' -Tag 'Fast' {
    It 'installs the disputed-response policy and routes Gate 2/3 to it' {
        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
            'init', '-ProjectRoot', $script:VerificationProject, '-Source', $script:ForkRoot,
            '-Tools', 'codex', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $manifest = Get-Content -LiteralPath (Join-Path $script:VerificationProject '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $evidence = @($manifest.files.PSObject.Properties | Where-Object { [string]$_.Value.source -eq 'content/rules/verification-ai-evidence.md' })
        $evidence.Count | Should -Be 1
        $body = Get-Content -LiteralPath (Join-Path $script:VerificationProject $evidence[0].Name) -Raw -Encoding UTF8
        $body | Should -Match 'complete raw response'
        $body | Should -Match 'Necessary AI calls and user limits'
        $body | Should -Match 'explicit user limit'
        $body | Should -Not -Match 'Task grants for additional AI calls|otherwise obtain a bounded user decision'
        $gate = Get-Content -LiteralPath (Join-Path $script:VerificationProject '.codex/rules/verification-gates.md') -Raw -Encoding UTF8
        $gate | Should -Match 'verification-ai-evidence.md'
        $gate | Should -Match 'Gate 2/3 responses'
    }

    It 'upgrades the installed r36 approval barrier without losing quality rules or user restrictions' {
        $sandbox = New-ForkTestRoot
        $oldSource = Join-Path $sandbox 'old-source'
        $project = Join-Path $sandbox 'project with Кириллица'
        try {
            & git clone --quiet --no-checkout $script:ForkRoot $oldSource
            $LASTEXITCODE | Should -Be 0
            & git -C $oldSource checkout --quiet --detach 451c5a52e5b614c67406445d4af4b636da043aec
            $LASTEXITCODE | Should -Be 0
            New-Item -ItemType Directory -Force -Path $project | Out-Null
            $oldInstall = Invoke-WindowsPowerShellFile -FilePath (Join-Path $oldSource 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $project, '-Source', $oldSource,
                '-Tools', 'codex', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $oldInstall.ExitCode | Should -Be 0 -Because $oldInstall.Output
            $oldEvidence = Get-Content -LiteralPath (Join-Path $project '.codex/rules/verification-ai-evidence.md') -Raw -Encoding UTF8
            $oldEvidence | Should -Match 'additional call needs an explicit, bounded user decision'
            $userRules = Join-Path $project 'USER-RULES.md'
            $restriction = "`nUser restriction: no AI calls until resumed; retain this exact boundary.`n"
            [IO.File]::AppendAllText($userRules, $restriction, [Text.UTF8Encoding]::new($false))
            $upgrade = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'update', '-ProjectRoot', $project, '-Source', $script:ForkRoot,
                '-Tools', 'codex', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $upgrade.ExitCode | Should -Be 0 -Because $upgrade.Output
            $freshProject = Join-Path $sandbox 'fresh with Кириллица'
            New-Item -ItemType Directory -Force -Path $freshProject | Out-Null
            $freshInstall = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $freshProject, '-Source', $script:ForkRoot,
                '-Tools', 'codex', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $freshInstall.ExitCode | Should -Be 0 -Because $freshInstall.Output
            foreach ($name in @('verification-policy', 'verification-ai-evidence', 'verification-gates', 'mcp-policy', 'dev-standards-env')) {
                $installed = Get-Content -LiteralPath (Join-Path $project ".codex/rules/$name.md") -Raw -Encoding UTF8
                $fresh = Get-Content -LiteralPath (Join-Path $freshProject ".codex/rules/$name.md") -Raw -Encoding UTF8
                $installed | Should -Be $fresh -Because "$name must have identical client routing and policy after update and fresh install"
                $installed | Should -Not -Match 'Task grants for additional AI calls|additional call needs an explicit, bounded user decision|budget exhausted = unverified'
            }
            $policy = Get-Content -LiteralPath (Join-Path $project '.codex/rules/verification-policy.md') -Raw -Encoding UTF8
            $route = '.agents/skills/1c-validate/SKILL.md'
            $installedRoute = Get-Content -LiteralPath (Join-Path $project $route) -Raw -Encoding UTF8
            $freshRoute = Get-Content -LiteralPath (Join-Path $freshProject $route) -Raw -Encoding UTF8
            $installedRoute | Should -Be $freshRoute
            $installedRoute | Should -Match 'diagnostic checkpoints'
            $installedRoute | Should -Not -Match 'one confirmation at `standard`, up to two at `full`'
            $policy | Should -Match 'not hard call limits'
            $policy | Should -Match 'explicit user-imposed numeric limit'
            $policy | Should -Match 'Confirmation after a fix is mandatory'
            $evidence = Get-Content -LiteralPath (Join-Path $project '.codex/rules/verification-ai-evidence.md') -Raw -Encoding UTF8
            $evidence | Should -Match 'one recovery call'
            $evidence | Should -Match 'unsupported/unresolved blockers'
            $evidence | Should -Match 'adjudicated-false-positive'
            (Get-Content -LiteralPath $userRules -Raw -Encoding UTF8) | Should -Match ([regex]::Escape($restriction.Trim()))
        } finally {
            $sandboxFull = [IO.Path]::GetFullPath($sandbox)
            $tempFull = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            if (-not $sandboxFull.StartsWith($tempFull, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to remove a test sandbox outside Temp.' }
            if (Test-Path -LiteralPath $sandboxFull) { Remove-Item -LiteralPath $sandboxFull -Recurse -Force }
        }
    }
}
