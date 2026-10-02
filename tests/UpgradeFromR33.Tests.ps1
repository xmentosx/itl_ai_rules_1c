BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
}

Describe 'Managed rules upgrade from the workflow master baseline' {
    It 'replaces clean r33 root instructions with the new upstream root and retains user rules' {
        $sandbox = New-ForkTestRoot
        $oldSource = Join-Path $sandbox 'old-source'
        $project = Join-Path $sandbox 'project'
        try {
            & git clone --quiet --no-checkout $script:ForkRoot $oldSource
            $LASTEXITCODE | Should -Be 0
            & git -C $oldSource checkout --quiet --detach 9309bfbbc9f8d844a21bce55178c2e0d72eaf965
            $LASTEXITCODE | Should -Be 0
            New-Item -ItemType Directory -Force -Path $project | Out-Null
            $oldInstall = Invoke-WindowsPowerShellFile -FilePath (Join-Path $oldSource 'install.ps1') -Arguments @(
                'init', '-ProjectRoot', $project, '-Source', $oldSource,
                '-Tools', 'kilocode', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $oldInstall.ExitCode | Should -Be 0 -Because $oldInstall.Output
            $oldManifest = Get-Content -LiteralPath (Join-Path $project '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $oldManifest.version | Should -Match 'itl-'
            $oldRoot = Get-Content -LiteralPath (Join-Path $project 'AGENTS.md') -Raw -Encoding UTF8
            $oldRoot | Should -Not -Match 'ITL managed-project ownership'

            $userRulesPath = Join-Path $project 'USER-RULES.md'
            [IO.File]::AppendAllText($userRulesPath, "`nUser-owned migration note.`n", [Text.UTF8Encoding]::new($false))
            $upgrade = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot 'install.ps1') -Arguments @(
                'update', '-ProjectRoot', $project, '-Source', $script:ForkRoot,
                '-Tools', 'kilocode', '-NonInteractive', '-AssumeYes', '-McpMode', 'delegated'
            )
            $upgrade.ExitCode | Should -Be 0 -Because $upgrade.Output
            $newRoot = Get-Content -LiteralPath (Join-Path $project 'AGENTS.md') -Raw -Encoding UTF8
            $newRoot | Should -Match 'ITL managed-project ownership'
            $newRoot | Should -Match 'Spec-driven development workspace'
            $newRoot | Should -Match 'USER-RULES.md'
            $newRoot | Should -Not -Be $oldRoot
            (Get-Content -LiteralPath $userRulesPath -Raw -Encoding UTF8) | Should -Match 'User-owned migration note'
            $newManifest = Get-Content -LiteralPath (Join-Path $project '.ai-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $newManifest.files.'AGENTS.md'.PSObject.Properties.Match('userModified').Count | Should -Be 0
        } finally {
            $sandboxFull = [IO.Path]::GetFullPath($sandbox)
            $tempFull = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            if (-not $sandboxFull.StartsWith($tempFull, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to remove a test sandbox outside Temp: $sandboxFull"
            }
            if (Test-Path -LiteralPath $sandboxFull) { Remove-Item -LiteralPath $sandboxFull -Recurse -Force }
        }
    }
}
