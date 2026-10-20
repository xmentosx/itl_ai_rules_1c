BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
}

Describe 'Client-scoped model tiers' -Tag 'Fast' {
    It 'preserves legacy two-tier analysis rendering without enabling reviewer eligibility' {
        $root = New-ForkTestRoot
        try {
            [IO.File]::WriteAllText((Join-Path $root '.dev.env'), "SUBAGENT_MODEL_CODING=provider/legacy`n", [Text.UTF8Encoding]::new($false))
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-Tools', 'codex', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $manifest = Get-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $manifest.modelTiersByClient.codex.analysis | Should -Be 'provider/legacy'
            $manifest.modelTiersByClient.codex.analysisExplicit | Should -BeFalse
        }
        finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
    It 'renders each client from its own model map and never imports a legacy model into another client' {
        $root = New-ForkTestRoot
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $root '.agent-1c') | Out-Null
            [IO.File]::WriteAllText((Join-Path $root '.agent-1c/project.json'),
                '{"aiRules":{"tools":["codex","cursor"],"modelTiersByClient":{"codex":{"coding":"gpt-codex-only","analysis":"","light":""}}}}',
                [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $root '.dev.env'), "SUBAGENT_MODEL_CODING=legacy-global`n", [Text.UTF8Encoding]::new($false))
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-Tools', 'codex,cursor', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $codexAgent = Get-Content -LiteralPath (Join-Path $root '.codex/agents/developer.toml') -Raw -Encoding UTF8
            $cursorAgent = Get-Content -LiteralPath (Join-Path $root '.cursor/agents/developer.md') -Raw -Encoding UTF8
            $codexFixer = Get-Content -LiteralPath (Join-Path $root '.codex/agents/error-fixer.toml') -Raw -Encoding UTF8
            $cursorFixer = Get-Content -LiteralPath (Join-Path $root '.cursor/agents/error-fixer.md') -Raw -Encoding UTF8
            $codexAgent | Should -Match 'model = "gpt-codex-only"'
            $cursorAgent | Should -Not -Match 'legacy-global|gpt-codex-only'
            $codexFixer | Should -Match 'model = "gpt-codex-only"'
            $cursorFixer | Should -Not -Match 'legacy-global|gpt-codex-only'
            $manifest = Get-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $manifest.modelTiersByClient.codex.coding | Should -Be 'gpt-codex-only'
            $manifest.modelTiersByClient.cursor.coding | Should -Be ''

            foreach ($tool in @('cursor', 'codex')) {
                $detach = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                    'remove', '-Tool', $tool, '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                    '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
                )
                $detach.ExitCode | Should -Be 0 -Because $detach.Output
            }
            Test-Path -LiteralPath (Join-Path $root '.ai-rules.json') | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $root '.dev.env') | Should -BeTrue
            [IO.File]::WriteAllText((Join-Path $root '.agent-1c/project.json'),
                '{"aiRules":{"tools":["codex"],"modelTiersByClient":{"codex":{"coding":"gpt-codex-only","analysis":"","light":""}}}}',
                [Text.UTF8Encoding]::new($false))
            $reattach = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-Tools', 'codex', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $reattach.ExitCode | Should -Be 0 -Because $reattach.Output
            (Get-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json).tools | Should -Be @('codex')
        }
        finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
}
