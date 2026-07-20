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

    It "keeps a pristine Claude entry manifest byte-idempotent on the first update" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "claude-idempotence"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"
            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "claude-code", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $manifestPath = Join-Path $projectRoot ".ai-rules.json"
            $before = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash

            $update = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "update", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $update.ExitCode | Should -Be 0 -Because $update.Output
            (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash | Should -Be $before
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            @($manifest.files.'CLAUDE.md'.PSObject.Properties.Name) | Should -Not -Contain "userModified"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
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
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot "content\openspec-bundle\codex\.codex\skills\openspec-explore\SKILL.md") -Destination (Join-Path $skillDir "SKILL.md")
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
    It "preserves delegated MCP data while adding Kilo project instructions on init" {
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
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            (Get-FileHash -Algorithm SHA256 -LiteralPath $codexPath).Hash | Should -Be $beforeCodex
            $kilo = Get-Content -Raw -Encoding UTF8 $kiloPath | ConvertFrom-Json
            $kilo.theme | Should -Be "user"
            $kilo.mcp.ITL.url | Should -Be "http://127.0.0.1:9992/mcp"
            @($kilo.instructions) | Should -Be @("USER-RULES.md")
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            $manifest.integrations.mcp.owner | Should -Be "ITL"
            @($manifest.mcpServers) | Should -BeNullOrEmpty
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".codex/config.toml"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
            $result.Output | Should -Match "/reload"
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
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
            )
            $managed.ExitCode | Should -Be 0 -Because $managed.Output
            $codexPath = Join-Path $projectRoot ".codex\config.toml"
            $kiloPath = Join-Path $projectRoot ".kilo\kilo.json"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $codexPath) | Out-Null
            [System.IO.File]::WriteAllText($codexPath, "[mcp_servers.ITL]`nurl = `"http://127.0.0.1:9993/mcp`"`n", [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($kiloPath, '{"mcp":{"ITL":{"type":"remote","url":"http://127.0.0.1:9994/mcp"}}}', [System.Text.UTF8Encoding]::new($false))
            $beforeCodex = (Get-FileHash -Algorithm SHA256 -LiteralPath $codexPath).Hash
            $result = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "update", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $result.Output | Should -Not -Match "User-modified files detected"
            (Get-FileHash -Algorithm SHA256 -LiteralPath $codexPath).Hash | Should -Be $beforeCodex
            $kilo = Get-Content -Raw -Encoding UTF8 $kiloPath | ConvertFrom-Json
            $kilo.mcp.ITL.url | Should -Be "http://127.0.0.1:9994/mcp"
            @($kilo.instructions) | Should -Be @("USER-RULES.md")
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".codex/config.toml"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "rejects add because client replacement belongs to the host workflow" {
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
            $result = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "add", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot, "-Tool", "kilocode",
                "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match "SINGLE_CLIENT_REQUIRED: add is disabled"
            $kilo = Get-Content -Raw -Encoding UTF8 $kiloPath | ConvertFrom-Json
            $kilo.permission.bash | Should -Be "ask"
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            @($manifest.tools) | Should -Be @("codex")
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Kilo project instructions" -Tag "Fast" {
    It "removes a Kilo installation while preserving the RTK-owned legacy rule" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "kilo-remove"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"
            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output

            $rtkRule = Join-Path $projectRoot ".kilocode\rules\rtk-rules.md"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $rtkRule) | Out-Null
            [System.IO.File]::WriteAllText($rtkRule, "RTK-owned", [System.Text.UTF8Encoding]::new($false))

            $remove = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "remove", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes"
            )
            $remove.ExitCode | Should -Be 0 -Because $remove.Output
            Test-Path -LiteralPath (Join-Path $projectRoot ".ai-rules.json") | Should -BeFalse
            Test-Path -LiteralPath $rtkRule -PathType Leaf | Should -BeTrue
            (Get-Content -LiteralPath $rtkRule -Raw -Encoding UTF8) | Should -Be "RTK-owned"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "adds USER-RULES once and preserves config keys and instruction order" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "kilo-instructions"
            $kiloPath = Join-Path $projectRoot ".kilo\kilo.json"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $kiloPath) | Out-Null
            $source = '{"$schema":"https://example.test/kilo.schema.json","instructions":["docs/a.md","user-rules.md","USER-RULES.md","docs/b.md"],"mcp":{"custom":{"type":"remote","url":"http://127.0.0.1:9999/mcp"}},"permission":{"bash":"ask"},"agent":{"review":{"model":"custom"}},"skills":{"paths":["skills"]},"theme":"user"}'
            [System.IO.File]::WriteAllText($kiloPath, $source, [System.Text.UTF8Encoding]::new($false))
            $installer = Join-Path $script:ForkRoot "install.ps1"

            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $config = Get-Content -Raw -Encoding UTF8 $kiloPath | ConvertFrom-Json
            @($config.instructions) | Should -Be @("docs/a.md", "USER-RULES.md", "docs/b.md")
            $config.'$schema' | Should -Be "https://example.test/kilo.schema.json"
            $config.mcp.custom.url | Should -Be "http://127.0.0.1:9999/mcp"
            $config.permission.bash | Should -Be "ask"
            $config.agent.review.model | Should -Be "custom"
            @($config.skills.paths) | Should -Be @("skills")
            $config.theme | Should -Be "user"

            $before = (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash
            $update = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "update", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $update.ExitCode | Should -Be 0 -Because $update.Output
            (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash | Should -Be $before
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "creates the instructions array when the Kilo config is absent" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "kilo-empty"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $config = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".kilo\kilo.json") | ConvertFrom-Json
            @($config.instructions) | Should -Be @("USER-RULES.md")
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "fails without changing invalid JSON or a non-array instructions value" -TestCases @(
        @{ Name = "invalid-json"; Json = '{broken' },
        @{ Name = "wrong-type"; Json = '{"instructions":"USER-RULES.md","theme":"user"}' }
    ) {
        param($Name, $Json)
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot $Name
            $kiloPath = Join-Path $projectRoot ".kilo\kilo.json"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $kiloPath) | Out-Null
            [System.IO.File]::WriteAllText($kiloPath, $Json, [System.Text.UTF8Encoding]::new($false))
            $before = (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match "KILO_INSTRUCTIONS_INVALID"
            (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash | Should -Be $before
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
