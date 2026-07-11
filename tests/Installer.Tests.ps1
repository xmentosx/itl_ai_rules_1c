BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "Fork bootstrap policy" -Tag "Fast" {
    It "keeps main out of project consumption" {
        $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot "docs\FORK-POLICY.md") -Raw -Encoding UTF8
        $text | Should -Match "origin/main.*never consumed"
        $text | Should -Match "upgrade/<source-id>"
        $text | Should -Match "itl-<source-id>-rN"
        $text | Should -Match "full 40-character commit SHA"
        $text | Should -Match "never\s+moved"
    }

    It "requires an immutable upstream source and selective patch transfer" {
        $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot "docs\UPSTREAM-UPGRADE.md") -Raw -Encoding UTF8
        $text | Should -Match "Never use the moving branch name alone"
        $text | Should -Match "exact current remote-tip SHA"
        $text | Should -Match "(?is)do not\s+merge an earlier"
        $text | Should -Match 'keep.*drop.*rewrite'
        $text | Should -Match "-WhatIf"
        $text | Should -Match 'with `-Push` instead of'
    }

    It "parses install.ps1 under the PowerShell parser" {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:ForkRoot "install.ps1"),
            [ref]$tokens,
            [ref]$errors
        )
        @($errors) | Should -BeNullOrEmpty
    }

    It "keeps local gate artifacts out of git status" {
        $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot ".gitignore") -Raw -Encoding UTF8
        $text | Should -Match '(?m)^build/\r?$'
    }

    It "records bootstrap infrastructure in the downstream ledger" {
        $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot "docs\DOWNSTREAM-PATCHES.md") -Raw -Encoding UTF8
        $text | Should -Match "ITL-INFRA-001"
        $text | Should -Match "ITL-INFRA-002"
        $text | Should -Match '`keep`'
        $text | Should -Match '`drop`'
        $text | Should -Match '`rewrite`'
    }
}

Describe "Current upstream installer smoke" {
    It "initializes and diagnoses a Kilo-only temporary project" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "project"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"

            $initResult = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
            )
            $initResult.ExitCode | Should -Be 0 -Because $initResult.Output

            $doctorResult = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "doctor", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot
            )
            $doctorResult.ExitCode | Should -Be 0 -Because $doctorResult.Output

            $manifestPath = Join-Path $projectRoot ".ai-rules.json"
            Test-Path -LiteralPath $manifestPath -PathType Leaf | Should -BeTrue
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            @($manifest.tools) | Should -Be @("kilocode")
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
