BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")

    function Invoke-TestInstall {
        param([string]$ProjectRoot, [string]$Tool, [string]$McpMode = "delegated")
        return Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "init", "-ProjectRoot", $ProjectRoot, "-Source", $script:ForkRoot,
            "-Tools", $Tool, "-NonInteractive", "-AssumeYes", "-McpMode", $McpMode
        )
    }

    $script:PublishedCommands = @("caveman", "deploy-and-test", "doctor", "economymode", "evolve", "getconfigfiles", "litemode", "loadfrom1cbase", "update1cbase")
    $script:SuppressedCommands = @("checkmcp", "installmcp", "updatemcp", "updaterules")
    $script:LayoutRoot = New-ForkTestRoot
}

AfterAll {
    Remove-Item -LiteralPath $script:LayoutRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Single-client adapter contract" -Tag "Fast" {
    It "rejects multiple and unsupported clients before writing a manifest" {
        foreach ($value in @("codex,kilocode", "other")) {
            $project = Join-Path $script:LayoutRoot ("reject-" + $value.Replace(',', '-'))
            New-Item -ItemType Directory -Force -Path $project | Out-Null
            $result = Invoke-TestInstall -ProjectRoot $project -Tool $value
            $result.ExitCode | Should -Not -Be 0
            Test-Path (Join-Path $project ".ai-rules.json") | Should -BeFalse
        }
    }

    It "initializes each supported client with exactly one manifest tool and native paths" {
        $cases = @(
            @{ Tool="codex"; Paths=@(".codex/rules", ".codex/agents", ".agents/skills", ".agents/skills/openspec-propose/SKILL.md") },
            @{ Tool="kilocode"; Paths=@(".kilo/rules-1c", ".kilo/agents", ".kilo/commands", ".kilo/skills", ".kilo/kilo.json") },
            @{ Tool="claude-code"; Paths=@(".claude/rules", ".claude/agents", ".claude/commands", ".claude/skills") },
            @{ Tool="cursor"; Paths=@(".cursor/rules", ".cursor/agents", ".cursor/commands", ".cursor/skills") },
            @{ Tool="opencode"; Paths=@(".opencode/rules", ".opencode/agent", ".opencode/command", ".claude/skills") }
        )
        foreach ($case in $cases) {
            $project = Join-Path $script:LayoutRoot $case.Tool
            New-Item -ItemType Directory -Force -Path $project | Out-Null
            $result = Invoke-TestInstall -ProjectRoot $project -Tool $case.Tool
            $result.ExitCode | Should -Be 0 -Because "$($case.Tool): $($result.Output)"
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $project ".ai-rules.json") | ConvertFrom-Json
            @($manifest.tools) | Should -Be @($case.Tool)
            $manifest.protocol | Should -Be "1.1"
            foreach ($path in $case.Paths) { Test-Path (Join-Path $project $path) | Should -BeTrue -Because "$($case.Tool): $path" }
        }
    }

    It "publishes the allowlist and suppresses generic update and MCP commands" {
        foreach ($tool in @("kilocode", "claude-code", "cursor", "opencode")) {
            $project = Join-Path $script:LayoutRoot $tool
            $commandDir = switch ($tool) {
                "kilocode" { ".kilo/commands" }
                "claude-code" { ".claude/commands" }
                "cursor" { ".cursor/commands" }
                "opencode" { ".opencode/command" }
            }
            foreach ($name in $script:PublishedCommands) { Test-Path (Join-Path $project "$commandDir/$name.md") | Should -BeTrue -Because "$tool publishes $name" }
            foreach ($name in $script:SuppressedCommands) { Test-Path (Join-Path $project "$commandDir/$name.md") | Should -BeFalse -Because "$tool suppresses $name" }
        }

        $codex = Join-Path $script:LayoutRoot "codex"
        foreach ($name in $script:PublishedCommands) { Test-Path (Join-Path $codex ".agents/skills/$name/SKILL.md") | Should -BeTrue -Because "Codex exposes $name as a project skill" }
        foreach ($name in $script:SuppressedCommands) { Test-Path (Join-Path $codex ".agents/skills/$name/SKILL.md") | Should -BeFalse }
        Test-Path (Join-Path $codex ".codex/skills") | Should -BeFalse
    }

    It "does not write user-global Codex prompts" {
        $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $script:LayoutRoot "codex/.ai-rules.json") | ConvertFrom-Json
        @($manifest.files.PSObject.Properties.Name | Where-Object { $_ -match '^~|^[A-Za-z]:|\.codex/prompts' }) | Should -BeNullOrEmpty
    }

    It "keeps a no-op update byte-idempotent" {
        $project = Join-Path $script:LayoutRoot "codex"
        $manifestPath = Join-Path $project ".ai-rules.json"
        $before = (Get-FileHash -Algorithm SHA256 $manifestPath).Hash
        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "update", "-ProjectRoot", $project, "-Source", $script:ForkRoot,
            "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match "Manifest unchanged"
        (Get-FileHash -Algorithm SHA256 $manifestPath).Hash | Should -Be $before
    }

    It "preserves project LLM-RULES byte-for-byte on update" {
        $project = Join-Path $script:LayoutRoot "codex"
        $path = Join-Path $project "LLM-RULES.md"
        [IO.File]::WriteAllText($path, "# LLM Rules`n`nuser-approved local rule`n", [Text.UTF8Encoding]::new($false))
        $before = (Get-FileHash -Algorithm SHA256 $path).Hash
        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "update", "-ProjectRoot", $project, "-Source", $script:ForkRoot,
            "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        (Get-FileHash -Algorithm SHA256 $path).Hash | Should -Be $before
    }
}

Describe "Adapter safety guards" -Tag "Fast" {
    It "blocks Kilo JSON and JSONC collision without changing either file" {
        $project = Join-Path $script:LayoutRoot "kilo-jsonc-collision"
        New-Item -ItemType Directory -Force -Path (Join-Path $project ".kilo") | Out-Null
        $json = Join-Path $project ".kilo/kilo.json"
        $jsonc = Join-Path $project ".kilo/kilo.jsonc"
        [IO.File]::WriteAllText($json, '{"theme":"user"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($jsonc, '{ // user config`n}', [Text.UTF8Encoding]::new($false))
        $beforeJson = (Get-FileHash $json).Hash
        $beforeJsonc = (Get-FileHash $jsonc).Hash
        $result = Invoke-TestInstall -ProjectRoot $project -Tool "kilocode"
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match "KILO_CONFIG_COLLISION"
        (Get-FileHash $json).Hash | Should -Be $beforeJson
        (Get-FileHash $jsonc).Hash | Should -Be $beforeJsonc
        Test-Path (Join-Path $project ".ai-rules.json") | Should -BeFalse
    }

    It "preserves the five ITL-owned project skills" {
        $project = Join-Path $script:LayoutRoot "itl-skills"
        $names = @("1c-workflow", "1c-workflow-fast", "itl-roctup-1c-data", "itl-vanessa-ui-mcp", "product-docs")
        foreach ($name in $names) {
            $file = Join-Path $project ".agents/skills/$name/ITL-SENTINEL.txt"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
            [IO.File]::WriteAllText($file, "ITL owns $name", [Text.UTF8Encoding]::new($false))
        }
        $result = Invoke-TestInstall -ProjectRoot $project -Tool "codex"
        $result.ExitCode | Should -Be 0 -Because $result.Output
        foreach ($name in $names) { (Get-Content -Raw (Join-Path $project ".agents/skills/$name/ITL-SENTINEL.txt")) | Should -Be "ITL owns $name" }
    }
}
