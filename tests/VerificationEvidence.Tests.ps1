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
        $body | Should -Match 'standard:\s*2; full:\s*3'
        $body | Should -Match 'extensions follow'
        $body | Should -Match 'Task grants for additional AI calls'
        $gate = Get-Content -LiteralPath (Join-Path $script:VerificationProject '.codex/rules/verification-gates.md') -Raw -Encoding UTF8
        $gate | Should -Match 'verification-ai-evidence.md'
        $gate | Should -Match 'Gate 2/3 responses'
    }
}
