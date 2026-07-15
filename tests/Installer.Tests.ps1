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
        foreach ($id in @("ITL-MCP-002", "ITL-OPENSPEC-001", "ITL-METADATA-001")) {
            $text | Should -Match $id
        }
    }

    It "ships the project-skill preflight in every explore propose and apply entrypoint" {
        $bundle = Join-Path $script:ForkRoot "content\openspec-bundle"
        $targets = @(Get-ChildItem -LiteralPath $bundle -Recurse -File -Filter "*.md" | Where-Object {
            $_.Name -in @("opsx-explore.md", "opsx-propose.md", "opsx-apply.md") -or
            ($_.Directory.Name -eq "opsx" -and $_.Name -in @("explore.md", "propose.md", "apply.md")) -or
            ($_.Name -eq "SKILL.md" -and $_.Directory.Name -in @("openspec-explore", "openspec-propose", "openspec-apply-change"))
        })
        $targets.Count | Should -Be 27
        foreach ($target in $targets) {
            (Get-Content -LiteralPath $target.FullName -Raw -Encoding UTF8) | Should -Match '<!-- itl:project-skill-preflight -->'
        }
        (Get-Content -LiteralPath (Join-Path $script:ForkRoot "tools\refresh-openspec-bundle.ps1") -Raw -Encoding UTF8) |
            Should -Match 'apply-openspec-downstream-overlay\.ps1'
    }

    It "applies the OpenSpec downstream overlay idempotently" {
        $testRoot = New-ForkTestRoot
        try {
            $skillDir = Join-Path $testRoot "openspec-explore"
            $commandDir = Join-Path $testRoot "opsx"
            New-Item -ItemType Directory -Force -Path $skillDir, $commandDir | Out-Null
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot "content\openspec-bundle\codex\.agents\skills\openspec-explore\SKILL.md") -Destination (Join-Path $skillDir "SKILL.md")
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot "content\openspec-bundle\claude-code\.claude\commands\opsx\explore.md") -Destination (Join-Path $commandDir "explore.md")
            foreach ($file in Get-ChildItem -LiteralPath $testRoot -Recurse -File) {
                $raw = (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8) -replace '(?s)<!-- itl:project-skill-preflight -->.*?(?=Enter explore mode)', ''
                [System.IO.File]::WriteAllText($file.FullName, $raw, [System.Text.UTF8Encoding]::new($false))
            }
            $transformer = Join-Path $script:ForkRoot "tools\apply-openspec-downstream-overlay.ps1"
            $first = Invoke-WindowsPowerShellFile -FilePath $transformer -Arguments @("-Root", $testRoot)
            $first.ExitCode | Should -Be 0 -Because $first.Output
            $before = @(Get-ChildItem -LiteralPath $testRoot -Recurse -File | ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $second = Invoke-WindowsPowerShellFile -FilePath $transformer -Arguments @("-Root", $testRoot)
            $second.ExitCode | Should -Be 0 -Because $second.Output
            $after = @(Get-ChildItem -LiteralPath $testRoot -Recurse -File | ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $after | Should -Be $before
            $second.Output | Should -Match 'updated=0 already-present=2'
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
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

Describe "Delegated MCP ownership" -Tag "Fast" {
    It "preserves existing client config bytes on init" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "delegated-init"
            New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot ".codex") | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot ".kilo") | Out-Null
            $codexPath = Join-Path $projectRoot ".codex\config.toml"
            $kiloPath = Join-Path $projectRoot ".kilo\kilo.json"
            [System.IO.File]::WriteAllText($codexPath, "[mcp_servers.ITL]`nurl = `"http://127.0.0.1:9991/mcp`"`n", [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($kiloPath, '{"theme":"user","mcp":{"ITL":{"type":"remote","url":"http://127.0.0.1:9992/mcp"}}}', [System.Text.UTF8Encoding]::new($false))
            $beforeCodex = (Get-FileHash -Algorithm SHA256 -LiteralPath $codexPath).Hash
            $beforeKilo = (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash

            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "codex,kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            (Get-FileHash -Algorithm SHA256 -LiteralPath $codexPath).Hash | Should -Be $beforeCodex
            (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash | Should -Be $beforeKilo
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            $manifest.integrations.mcp.owner | Should -Be "ITL"
            @($manifest.mcpServers) | Should -BeNullOrEmpty
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".codex/config.toml"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
            $result.Output | Should -Not -Match "перезапустите AI-клиент"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "removes previous managed ownership before update drift detection" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "delegated-update"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"
            $managed = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "codex,kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
            )
            $managed.ExitCode | Should -Be 0 -Because $managed.Output
            $codexPath = Join-Path $projectRoot ".codex\config.toml"
            $kiloPath = Join-Path $projectRoot ".kilo\kilo.json"
            [System.IO.File]::WriteAllText($codexPath, "[mcp_servers.ITL]`nurl = `"http://127.0.0.1:9993/mcp`"`n", [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($kiloPath, '{"mcp":{"ITL":{"type":"remote","url":"http://127.0.0.1:9994/mcp"}}}', [System.Text.UTF8Encoding]::new($false))
            $beforeCodex = (Get-FileHash -Algorithm SHA256 -LiteralPath $codexPath).Hash
            $beforeKilo = (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash

            $result = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "update", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $result.Output | Should -Not -Match "User-modified files detected"
            (Get-FileHash -Algorithm SHA256 -LiteralPath $codexPath).Hash | Should -Be $beforeCodex
            (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash | Should -Be $beforeKilo
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".codex/config.toml"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "does not create the new tool MCP config during add" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "delegated-add"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"
            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "codex", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $kiloPath = Join-Path $projectRoot ".kilo\kilo.json"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $kiloPath) | Out-Null
            [System.IO.File]::WriteAllText($kiloPath, '{"permission":{"bash":"ask"}}', [System.Text.UTF8Encoding]::new($false))
            $before = (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash

            $result = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "add", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot, "-Tool", "kilocode",
                "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash | Should -Be $before
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            @($manifest.tools | Sort-Object) | Should -Be @("codex", "kilocode")
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
