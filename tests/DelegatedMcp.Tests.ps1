BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
}

Describe 'ITL delegated MCP ownership' -Tag 'Fast' {
    It 'rejects a direct default-mode install in a managed project before writing' {
        $root = New-ForkTestRoot
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $root '.agent-1c') | Out-Null
            [IO.File]::WriteAllText((Join-Path $root '.agent-1c/project.json'), '{}', [Text.UTF8Encoding]::new($false))
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $root, '-Source', $script:ForkRoot,
                '-Tools', 'codex', '-NonInteractive', '-AssumeYes'
            )
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'ITL_LIFECYCLE_HELPER_REQUIRED'
            Test-Path -LiteralPath (Join-Path $root '.ai-rules.json') | Should -BeFalse
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    It 'preserves an existing client MCP file and records delegated ownership' {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot 'project with Кириллица'
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $mcpPath = Join-Path $projectRoot '.mcp.json'
            $original = '{"mcpServers":{"user":{"url":"http://127.0.0.1:9000"}}}' + "`n"
            [IO.File]::WriteAllText($mcpPath, $original, [Text.UTF8Encoding]::new($false))
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $projectRoot, '-Source', $script:ForkRoot,
                '-Tools', 'claude-code', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $result.Output | Should -Match 'MCP client configuration is delegated to ITL; no client MCP writes are planned'
            $result.Output | Should -Not -Match "MCP servers will be added to each tool's MCP config"
            [IO.File]::ReadAllText($mcpPath, [Text.UTF8Encoding]::new($false)) | Should -BeExactly $original
            $manifest = Get-Content -LiteralPath (Join-Path $projectRoot '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $manifest.integrations.mcp.mode | Should -Be 'delegated'
            $manifest.integrations.mcp.owner | Should -Be 'ITL'
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain '.mcp.json'
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
