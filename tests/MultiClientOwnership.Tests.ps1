BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
}

Describe 'Multi-client project ownership' -Tag 'Fast' {
    It 'keeps a repeated multi-client update byte-idempotent' {
        $root = New-ForkTestRoot
        try {
            $common = @('-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated')
            $init = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments (@(
                'init', '-Tools', 'cursor,codex') + $common)
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $first = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments (@('update') + $common)
            $first.ExitCode | Should -Be 0 -Because $first.Output
            $manifest = Get-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $paths = @('.ai-rules.json') + @($manifest.files.PSObject.Properties.Name)
            $before = @{}
            foreach ($relative in $paths) {
                $path = if ([IO.Path]::IsPathRooted($relative)) { $relative } else { Join-Path $root $relative }
                Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
                $before[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            }
            Start-Sleep -Milliseconds 1200
            $repeat = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments (@('update') + $common)
            $repeat.ExitCode | Should -Be 0 -Because $repeat.Output
            foreach ($relative in $paths) {
                $path = if ([IO.Path]::IsPathRooted($relative)) { $relative } else { Join-Path $root $relative }
                (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash |
                    Should -Be $before[$relative] -Because "a no-op update changed $relative"
            }
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    It 'installs ZCode and MiMo into their project config paths while preserving user servers' {
        foreach ($case in @(
            [pscustomobject]@{ tool='zcode'; path='.zcode/config.json'; text='{"theme":"user","mcp":{"servers":{"custom":{"type":"http","url":"https://custom.invalid"}}}}'; serverPath='mcp.servers' },
            [pscustomobject]@{ tool='mimocode'; path='.mimocode/mimocode.json'; text='{"model":"user","mcp":{"custom":{"type":"remote","url":"https://custom.invalid"}}}'; serverPath='mcp' }
        )) {
            $root = New-ForkTestRoot
            try {
                $configPath = Join-Path $root $case.path
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath) | Out-Null
                [IO.File]::WriteAllText($configPath, $case.text, [Text.UTF8Encoding]::new($false))
                $init = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                    'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                    '-Tools', $case.tool, '-NonInteractive', '-AssumeYes', '-McpMode', 'managed'
                )
                $init.ExitCode | Should -Be 0 -Because $init.Output
                $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($case.tool -eq 'zcode') {
                    $config.theme | Should -Be 'user'
                    $config.mcp.servers.custom.url | Should -Be 'https://custom.invalid'
                    @($config.mcp.servers.PSObject.Properties.Name).Count | Should -BeGreaterThan 1
                } else {
                    $config.model | Should -Be 'user'
                    $config.mcp.custom.url | Should -Be 'https://custom.invalid'
                    @($config.mcp.PSObject.Properties.Name).Count | Should -BeGreaterThan 1
                    Test-Path -LiteralPath (Join-Path $root 'mimocode.json') | Should -BeFalse
                }
            } finally {
                if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
            }
        }
    }

    It 'keeps Codex skills and repairs references when Cursor is removed' {
        $root = New-ForkTestRoot
        try {
            $init = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-Tools', 'cursor,codex', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $before = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding UTF8
            $before | Should -Match '\.cursor/rules/'
            $remove = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'remove', '-Tool', 'cursor', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-AssumeYes', '-McpMode', 'delegated'
            )
            $remove.ExitCode | Should -Be 0 -Because $remove.Output
            $manifest = Get-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            @($manifest.tools) | Should -Be @('codex')
            Test-Path -LiteralPath (Join-Path $root '.agents/skills/1c-metadata-manage/SKILL.md') | Should -BeTrue
            $after = Get-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Raw -Encoding UTF8
            $after | Should -Not -Match '\.cursor/rules/'
            $after | Should -Match '\.codex/rules/'
        }
        finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    It 'preserves shared MCP and user servers when one owner is detached' {
        $root = New-ForkTestRoot
        try {
            $mcpPath = Join-Path $root '.mcp.json'
            [IO.File]::WriteAllText($mcpPath, '{"mcpServers":{"user":{"url":"http://127.0.0.1:9000"}}}', [Text.UTF8Encoding]::new($false))
            $init = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-Tools', 'claude-code,command-code', '-NonInteractive', '-AssumeYes', '-McpMode', 'managed'
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $before = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $before.mcpServers.user.url | Should -Be 'http://127.0.0.1:9000'
            $remove = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'remove', '-Tool', 'claude-code', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-AssumeYes', '-McpMode', 'managed'
            )
            $remove.ExitCode | Should -Be 0 -Because $remove.Output
            $after = Get-Content -LiteralPath $mcpPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $after.mcpServers.user.url | Should -Be 'http://127.0.0.1:9000'
            @($after.mcpServers.PSObject.Properties.Name).Count | Should -BeGreaterThan 1
            $manifest = Get-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            @($manifest.tools) | Should -Be @('command-code')
            @($manifest.files.'.mcp.json'.owners) | Should -Be @('command-code')
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    It 'keeps shared Claude and OpenCode skills after Claude is detached' {
        $root = New-ForkTestRoot
        try {
            $init = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-Tools', 'claude-code,opencode', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $skill = Join-Path $root '.claude/skills/1c-metadata-manage/SKILL.md'
            Test-Path -LiteralPath $skill -PathType Leaf | Should -BeTrue
            $hash = (Get-FileHash -LiteralPath $skill -Algorithm SHA256).Hash
            $detach = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'remove', '-Tool', 'claude-code', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $detach.ExitCode | Should -Be 0 -Because $detach.Output
            (Get-FileHash -LiteralPath $skill -Algorithm SHA256).Hash | Should -Be $hash
            $manifest = Get-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            @($manifest.tools) | Should -Be @('opencode')
            @($manifest.files.'.claude/skills/1c-metadata-manage/SKILL.md'.owners) | Should -Be @('opencode')
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
}
