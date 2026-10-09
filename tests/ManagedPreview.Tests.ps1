BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
}

Describe 'Managed metadata preview boundary' -Tag 'Fast' {
    It 'refuses rollback preview before a tool can mutate the worktree' {
        $root = New-ForkTestRoot
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $root '.agent-1c') | Out-Null
            [IO.File]::WriteAllText((Join-Path $root '.agent-1c/project.json'), '{}', [Text.UTF8Encoding]::new($false))
            $sentinel = Join-Path $root 'source.txt'
            [IO.File]::WriteAllText($sentinel, 'original', [Text.UTF8Encoding]::new($false))
            $wrapper = Join-Path $script:ForkRoot 'content/skills/1c-metadata-manage/tools/_common/Invoke-1CEdit.ps1'
            $result = Invoke-WindowsPowerShellFile -FilePath $wrapper -Arguments @(
                '-Tool', 'form-edit', '-Root', $root, '-Scope', $sentinel, '-Preview'
            )
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'ITL_METADATA_PREVIEW_UNAVAILABLE'
            [IO.File]::ReadAllText($sentinel) | Should -BeExactly 'original'
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
}
