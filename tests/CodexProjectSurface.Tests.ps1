BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
}

Describe 'Codex project-local command surface' -Tag 'Fast' {
    It 'installs project skills without changing shared user prompts' {
        $root = New-ForkTestRoot
        $prompts = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex/prompts'
        $before = @{}
        if (Test-Path -LiteralPath $prompts -PathType Container) {
            foreach ($file in Get-ChildItem -LiteralPath $prompts -File) {
                $before[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
        try {
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-Tools', 'codex', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $manifest = Get-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            @($manifest.files.PSObject.Properties.Name | Where-Object { [IO.Path]::IsPathRooted($_) -or $_ -match '^~[/\\]' }) | Should -BeNullOrEmpty
            $rootRules = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding UTF8
            $rootRules | Should -Match 'ITL managed-project ownership'
            $rootRules | Should -Match 'Spec-driven development workspace'
            $rootRules | Should -Match 'USER-RULES.md'
            $manifest.files.'AGENTS.md'.PSObject.Properties.Match('userModified').Count | Should -Be 0
            $userRules = Get-Content -LiteralPath (Join-Path $root 'USER-RULES.md') -Raw -Encoding UTF8
            $userRules | Should -Match 'ITL hard gates'
            Test-Path -LiteralPath (Join-Path $root '.agents/skills/test-fix-loop/SKILL.md') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $root '.agents/skills/caveman/SKILL.md') | Should -BeTrue
            $manifestPath = Join-Path $root '.ai-rules.json'
            $legacyPrompt = Join-Path $prompts 'itl-legacy-migration-probe.md'
            Test-Path -LiteralPath $legacyPrompt | Should -BeFalse
            $legacyManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $legacyManifest.files | Add-Member -MemberType NoteProperty -Name $legacyPrompt -Value ([ordered]@{ source='content/commands/legacy-probe.md'; installedHash='unavailable'; owners=@('codex') })
            [IO.File]::WriteAllText($manifestPath, (($legacyManifest | ConvertTo-Json -Depth 40) + "`n"), [Text.UTF8Encoding]::new($false))
            $update = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'update', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $update.ExitCode | Should -Be 0 -Because $update.Output
            $update.Output | Should -Match 'detached ownership of 1 user-global prompt'
            $updatedManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            @($updatedManifest.files.PSObject.Properties.Name | Where-Object { [IO.Path]::IsPathRooted($_) }) | Should -BeNullOrEmpty
            (Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding UTF8) | Should -Be $rootRules
            $after = @{}
            if (Test-Path -LiteralPath $prompts -PathType Container) {
                foreach ($file in Get-ChildItem -LiteralPath $prompts -File) {
                    $after[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                }
            }
            ($after | ConvertTo-Json -Compress) | Should -Be ($before | ConvertTo-Json -Compress)
        }
        finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
}
