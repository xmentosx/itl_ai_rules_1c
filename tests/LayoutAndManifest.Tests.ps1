BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")

    function Invoke-TestInstall {
        param([string]$ProjectRoot, [string]$Tools, [string]$SourceRoot = $script:ForkRoot)
        $installer = Join-Path $SourceRoot "install.ps1"
        return Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
            "init", "-ProjectRoot", $ProjectRoot, "-Source", $SourceRoot,
            "-Tools", $Tools, "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
        )
    }

    function Get-SelectedPromptSnapshot {
        $root = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\prompts"
        $result = [ordered]@{}
        foreach ($name in @("checkmcp", "deploy-and-test", "doctor", "getconfigfiles", "installmcp", "loadfrom1cbase", "update1cbase", "updatemcp", "updaterules")) {
            $path = Join-Path $root ($name + ".md")
            $result[$path] = if (Test-Path -LiteralPath $path -PathType Leaf) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash } else { "<missing>" }
        }
        return $result
    }

    function Assert-SnapshotsEqual {
        param($Before, $After)
        @($Before.Keys) | Should -Be @($After.Keys)
        foreach ($key in $Before.Keys) { $After[$key] | Should -Be $Before[$key] }
    }

    $script:LayoutRoot = New-ForkTestRoot
    $script:CombinedProject = Join-Path $script:LayoutRoot "combined"
    $script:CodexProject = Join-Path $script:LayoutRoot "codex-only"
    $script:KiloProject = Join-Path $script:LayoutRoot "kilo-only"
    New-Item -ItemType Directory -Force -Path $script:CombinedProject | Out-Null
    $script:PromptBefore = Get-SelectedPromptSnapshot
    $script:CombinedInstallResult = Invoke-TestInstall -ProjectRoot $script:CombinedProject -Tools "codex,kilocode"
    $script:CombinedInstallResult.ExitCode | Should -Be 0 -Because $script:CombinedInstallResult.Output
    foreach ($case in @(@($script:CodexProject, "codex"), @($script:KiloProject, "kilocode"))) {
        New-Item -ItemType Directory -Force -Path $case[0] | Out-Null
        $singleResult = Invoke-TestInstall -ProjectRoot $case[0] -Tools $case[1]
        $singleResult.ExitCode | Should -Be 0 -Because $singleResult.Output
    }
    $script:PromptAfter = Get-SelectedPromptSnapshot
}

AfterAll {
    Remove-Item -LiteralPath $script:LayoutRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Modern Codex and Kilo layout" {
    It "installs the expected Codex-only and Kilo-only inventories" {
        foreach ($project in @($script:CodexProject, $script:KiloProject)) {
            Test-Path (Join-Path $project ".agents\skills\doctor\SKILL.md") | Should -BeTrue
            Test-Path (Join-Path $project ".agents\skills\openspec-propose\SKILL.md") | Should -BeTrue
            Test-Path (Join-Path $project ".kilocode") | Should -BeFalse
        }
        Test-Path (Join-Path $script:CodexProject ".kilo") | Should -BeFalse
        Test-Path (Join-Path $script:CodexProject ".codex\skills") | Should -BeFalse
        Test-Path (Join-Path $script:KiloProject ".kilo\commands\opsx-propose.md") | Should -BeTrue
        Test-Path (Join-Path $script:KiloProject ".kilo\commands\doctor.md") | Should -BeFalse
        Test-Path (Join-Path $script:KiloProject ".kilo\skills") | Should -BeFalse
    }

    It "uses only project-local shared skills and Kilo OpenSpec commands" {
        Test-Path (Join-Path $script:CombinedProject ".agents\skills\doctor\SKILL.md") | Should -BeTrue
        Test-Path (Join-Path $script:CombinedProject ".agents\skills\1c-metadata-manage\SKILL.md") | Should -BeTrue
        Test-Path (Join-Path $script:CombinedProject ".agents\skills\openspec-propose\SKILL.md") | Should -BeTrue
        Test-Path (Join-Path $script:CombinedProject ".kilo\commands\opsx-propose.md") | Should -BeTrue
        Test-Path (Join-Path $script:CombinedProject ".kilo\commands\doctor.md") | Should -BeFalse
        Test-Path (Join-Path $script:CombinedProject ".codex\skills") | Should -BeFalse
        Test-Path (Join-Path $script:CombinedProject ".kilo\skills") | Should -BeFalse
        Test-Path (Join-Path $script:CombinedProject ".kilocode") | Should -BeFalse
    }

    It "does not create or change user-scope Codex prompts" {
        Assert-SnapshotsEqual -Before $script:PromptBefore -After $script:PromptAfter
    }

    It "writes protocol 1.1 ownership and project scope" {
        $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $script:CombinedProject ".ai-rules.json") | ConvertFrom-Json
        $manifest.protocol | Should -Be "1.1"
        foreach ($property in @($manifest.files.PSObject.Properties)) {
            @($property.Value.owners).Count | Should -BeGreaterThan 0
            $property.Value.scope | Should -Be "project"
        }
        $shared = $manifest.files.PSObject.Properties | Where-Object { $_.Name -eq ".agents/skills/1c-metadata-manage/SKILL.md" } | Select-Object -First 1
        @($shared.Value.owners | Sort-Object) | Should -Be @("codex", "kilocode")
        $workflow = $manifest.files.PSObject.Properties | Where-Object { $_.Name -eq ".agents/skills/doctor/SKILL.md" } | Select-Object -First 1
        @($workflow.Value.owners | Sort-Object) | Should -Be @("codex", "kilocode")
    }

    It "omits an optional server with an unresolved publication placeholder" {
        $codexConfig = Get-Content -Raw -Encoding UTF8 (Join-Path $script:CombinedProject ".codex\config.toml")
        $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $script:CombinedProject ".ai-rules.json") | ConvertFrom-Json
        $codexConfig | Should -Not -Match ([regex]::Escape('1c-data-mcp'))
        @($manifest.mcpServers) | Should -Not -Contain "1c-data-mcp"
        $script:CombinedInstallResult.Output | Should -Not -Match "Заполните INFOBASE_PUBLISH_URL"
        $script:CombinedInstallResult.Output | Should -Match "optional server 1c-data-mcp is disabled"
    }

    It "includes the optional server when the publication URL is populated" {
        $copy = Join-Path $script:LayoutRoot "published-data-mcp"
        Copy-Item -LiteralPath $script:CodexProject -Destination $copy -Recurse -Force
        $envPath = Join-Path $copy ".dev.env"
        $envText = Get-Content -Raw -Encoding UTF8 $envPath
        $envText = [regex]::Replace($envText, '(?m)^INFOBASE_PUBLISH_URL=.*$', 'INFOBASE_PUBLISH_URL=http://127.0.0.1:9/demo/ru')
        [System.IO.File]::WriteAllText($envPath, $envText, [System.Text.UTF8Encoding]::new($false))

        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "update", "-ProjectRoot", $copy, "-Source", $script:ForkRoot,
            "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $codexConfig = Get-Content -Raw -Encoding UTF8 (Join-Path $copy ".codex\config.toml")
        $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $copy ".ai-rules.json") | ConvertFrom-Json
        $codexConfig | Should -Match ([regex]::Escape('[mcp_servers."1c-data-mcp"]'))
        $codexConfig | Should -Match ([regex]::Escape('http://127.0.0.1:9/demo/hs/mcp'))
        @($manifest.mcpServers) | Should -Contain "1c-data-mcp"
    }

    It "fails installation when a required server placeholder is unresolved" {
        $source = Join-Path $script:LayoutRoot "required-placeholder-source"
        New-Item -ItemType Directory -Force -Path $source | Out-Null
        foreach ($item in Get-ChildItem -Force -LiteralPath $script:ForkRoot | Where-Object Name -ne '.git') {
            Copy-Item -LiteralPath $item.FullName -Destination $source -Recurse -Force
        }
        $catalogPath = Join-Path $source "content\mcp-servers.json"
        $catalog = Get-Content -Raw -Encoding UTF8 $catalogPath | ConvertFrom-Json
        ($catalog.servers | Where-Object id -eq '1c-data-mcp').required = $true
        [System.IO.File]::WriteAllText($catalogPath, (($catalog | ConvertTo-Json -Depth 10) + "`n"), [System.Text.UTF8Encoding]::new($false))
        $project = Join-Path $script:LayoutRoot "required-placeholder-project"
        New-Item -ItemType Directory -Force -Path $project | Out-Null

        $result = Invoke-TestInstall -ProjectRoot $project -Tools "codex" -SourceRoot $source
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match "is required, but its URL contains unresolved placeholder"
    }

    It "keeps a no-op update byte-idempotent" {
        $manifestPath = Join-Path $script:CombinedProject ".ai-rules.json"
        $beforeHash = (Get-FileHash -Algorithm SHA256 $manifestPath).Hash
        $beforeTime = (Get-Item $manifestPath).LastWriteTimeUtc
        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "update", "-ProjectRoot", $script:CombinedProject, "-Source", $script:ForkRoot,
            "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match "Manifest unchanged"
        (Get-FileHash -Algorithm SHA256 $manifestPath).Hash | Should -Be $beforeHash
        (Get-Item $manifestPath).LastWriteTimeUtc | Should -Be $beforeTime
    }

    It "removes one owner without deleting shared files" {
        $copy = Join-Path $script:LayoutRoot "remove-owner"
        Copy-Item -LiteralPath $script:CombinedProject -Destination $copy -Recurse -Force
        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "remove", "-ProjectRoot", $copy, "-Tool", "codex", "-NonInteractive", "-AssumeYes"
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        Test-Path (Join-Path $copy ".agents\skills\doctor\SKILL.md") | Should -BeTrue
        Test-Path (Join-Path $copy ".agents\skills\1c-metadata-manage\SKILL.md") | Should -BeTrue
        Test-Path (Join-Path $copy ".codex\agents") | Should -BeFalse
        $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $copy ".ai-rules.json") | ConvertFrom-Json
        $entry = $manifest.files.PSObject.Properties | Where-Object { $_.Name -eq ".agents/skills/doctor/SKILL.md" } | Select-Object -First 1
        @($entry.Value.owners) | Should -Be @("kilocode")
    }

    It "adds a second owner through the complete final-tool plan" {
        $copy = Join-Path $script:LayoutRoot "add-owner"
        Copy-Item -LiteralPath $script:CodexProject -Destination $copy -Recurse -Force
        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "add", "-ProjectRoot", $copy, "-Source", $script:ForkRoot, "-Tool", "kilocode",
            "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $copy ".ai-rules.json") | ConvertFrom-Json
        $entry = $manifest.files.PSObject.Properties | Where-Object { $_.Name -eq ".agents/skills/doctor/SKILL.md" } | Select-Object -First 1
        @($entry.Value.owners | Sort-Object) | Should -Be @("codex", "kilocode")
        Test-Path (Join-Path $copy ".kilo\commands\opsx-propose.md") | Should -BeTrue
    }
}

Describe "Installation plan safety" {
    It "rejects different content for one target before writing project artifacts" {
        $source = Join-Path $script:LayoutRoot "conflict-source"
        New-Item -ItemType Directory -Force -Path $source | Out-Null
        foreach ($name in @("install.ps1", "AGENTS.md", "USER-RULES.md", "memory.md", ".dev.env.example")) {
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot $name) -Destination (Join-Path $source $name) -Force
        }
        foreach ($dir in @("adapters", "content", "openspec")) {
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot $dir) -Destination (Join-Path $source $dir) -Recurse -Force
        }
        $kiloAdapter = Join-Path $source "adapters\kilocode.yaml"
        $text = Get-Content -Raw -Encoding UTF8 $kiloAdapter
        $text = $text.Replace('copyTo: ".kilo/rules-1c/{name}.md"', 'copyTo: ".codex/rules/{name}.md"')
        $text = $text.Replace('keep: [description, alwaysApply]', 'keep: [description]')
        [System.IO.File]::WriteAllText($kiloAdapter, $text, [System.Text.UTF8Encoding]::new($false))
        $project = Join-Path $script:LayoutRoot "conflict-project"
        New-Item -ItemType Directory -Force -Path $project | Out-Null
        $result = Invoke-TestInstall -ProjectRoot $project -Tools "codex,kilocode" -SourceRoot $source
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match "Installation plan conflict"
        Test-Path (Join-Path $project ".ai-rules.json") | Should -BeFalse
        Test-Path (Join-Path $project ".agents") | Should -BeFalse
        Test-Path (Join-Path $project ".codex") | Should -BeFalse
    }

    It "rejects a project destination that escapes the project root" {
        $source = Join-Path $script:LayoutRoot "escape-source"
        New-Item -ItemType Directory -Force -Path $source | Out-Null
        foreach ($name in @("install.ps1", "AGENTS.md", "USER-RULES.md", "memory.md", ".dev.env.example")) {
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot $name) -Destination (Join-Path $source $name) -Force
        }
        foreach ($dir in @("adapters", "content", "openspec")) {
            Copy-Item -LiteralPath (Join-Path $script:ForkRoot $dir) -Destination (Join-Path $source $dir) -Recurse -Force
        }
        $adapter = Join-Path $source "adapters\codex.yaml"
        $text = (Get-Content -Raw -Encoding UTF8 $adapter).Replace('copyTo: ".codex/rules/{name}.md"', 'copyTo: "../escape/{name}.md"')
        [System.IO.File]::WriteAllText($adapter, $text, [System.Text.UTF8Encoding]::new($false))
        $project = Join-Path $script:LayoutRoot "escape-project"
        New-Item -ItemType Directory -Force -Path $project | Out-Null
        $result = Invoke-TestInstall -ProjectRoot $project -Tools "codex" -SourceRoot $source
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match "escapes project root"
        Test-Path (Join-Path $project ".ai-rules.json") | Should -BeFalse
        Test-Path (Join-Path $script:LayoutRoot "escape") | Should -BeFalse
    }
}

Describe "Adapter and ITL coexistence smoke" {
    It "initializes the remaining upstream adapters" {
        foreach ($tool in @("cursor", "claude-code", "opencode", "other")) {
            $project = Join-Path $script:LayoutRoot ("adapter-" + $tool)
            New-Item -ItemType Directory -Force -Path $project | Out-Null
            $result = Invoke-TestInstall -ProjectRoot $project -Tools $tool
            $result.ExitCode | Should -Be 0 -Because "$tool`: $($result.Output)"
            Test-Path (Join-Path $project ".ai-rules.json") | Should -BeTrue
        }
    }

    It "does not alter the five ITL-owned skills beside the shared repo surface" {
        $project = Join-Path $script:LayoutRoot "itl-skills"
        $skillNames = @("1c-workflow", "1c-workflow-fast", "itl-roctup-1c-data", "itl-vanessa-ui-mcp", "product-docs")
        $before = [ordered]@{}
        foreach ($name in $skillNames) {
            $file = Join-Path $project (".agents\skills\$name\ITL-SENTINEL.txt")
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $file) | Out-Null
            [System.IO.File]::WriteAllText($file, "ITL owns $name", [System.Text.UTF8Encoding]::new($false))
            $before[$file] = (Get-FileHash -Algorithm SHA256 $file).Hash
        }
        $result = Invoke-TestInstall -ProjectRoot $project -Tools "codex,kilocode"
        $result.ExitCode | Should -Be 0 -Because $result.Output
        foreach ($file in $before.Keys) {
            Test-Path -LiteralPath $file | Should -BeTrue
            (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash | Should -Be $before[$file]
        }
    }
}

Describe "Manifest 1.0 migration" {
    It "removes clean legacy project layout and preserves user-scope files" {
        $project = Join-Path $script:LayoutRoot "legacy-clean"
        New-Item -ItemType Directory -Force -Path $project | Out-Null
        $result = Invoke-TestInstall -ProjectRoot $project -Tools "kilocode"
        $result.ExitCode | Should -Be 0 -Because $result.Output

        $legacyDir = Join-Path $project ".kilocode\workflows"
        New-Item -ItemType Directory -Force -Path $legacyDir | Out-Null
        $legacyFile = Join-Path $legacyDir "legacy-clean.md"
        [System.IO.File]::WriteAllText($legacyFile, "managed legacy", [System.Text.UTF8Encoding]::new($false))
        $outside = Join-Path $script:LayoutRoot "legacy-user-prompt.md"
        [System.IO.File]::WriteAllText($outside, "keep me", [System.Text.UTF8Encoding]::new($false))
        $outsideHash = (Get-FileHash -Algorithm SHA256 $outside).Hash
        $legacyHash = (Get-FileHash -Algorithm SHA256 $legacyFile).Hash
        $manifest = [ordered]@{
            protocol = "1.0"; source = $script:ForkRoot; version = "r1-fixture"
            installedAt = "2026-01-01T00:00:00Z"; updatedAt = "2026-01-01T00:00:00Z"
            lastChannel = "powershell"; tools = @("kilocode"); language = "en"; mcpServers = @()
            files = [ordered]@{
                ".kilocode/workflows/legacy-clean.md" = [ordered]@{ source = "legacy"; installedHash = $legacyHash }
                $outside = [ordered]@{ source = "content/commands/doctor.md"; installedHash = $outsideHash }
            }
            foreignFiles = [ordered]@{}; integrations = [ordered]@{}
        }
        [System.IO.File]::WriteAllText((Join-Path $project ".ai-rules.json"), (($manifest | ConvertTo-Json -Depth 10) + "`n"), [System.Text.UTF8Encoding]::new($false))

        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "update", "-ProjectRoot", $project, "-Source", $script:ForkRoot,
            "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        Test-Path $legacyFile | Should -BeFalse
        Test-Path (Join-Path $project ".kilocode") | Should -BeFalse
        (Get-FileHash -Algorithm SHA256 $outside).Hash | Should -Be $outsideHash
        $migrated = Get-Content -Raw -Encoding UTF8 (Join-Path $project ".ai-rules.json") | ConvertFrom-Json
        $migrated.protocol | Should -Be "1.1"
        @($migrated.legacyArtifacts.userScope).Count | Should -Be 1
    }

    It "keeps and reports a modified legacy project file" {
        $project = Join-Path $script:LayoutRoot "legacy-modified"
        New-Item -ItemType Directory -Force -Path (Join-Path $project ".kilocode\workflows") | Out-Null
        $legacyFile = Join-Path $project ".kilocode\workflows\custom.md"
        [System.IO.File]::WriteAllText($legacyFile, "original", [System.Text.UTF8Encoding]::new($false))
        $recordedHash = (Get-FileHash -Algorithm SHA256 $legacyFile).Hash
        [System.IO.File]::WriteAllText($legacyFile, "user change", [System.Text.UTF8Encoding]::new($false))
        $manifest = [ordered]@{
            protocol = "1.0"; source = $script:ForkRoot; version = "r1-fixture"
            installedAt = "2026-01-01T00:00:00Z"; updatedAt = "2026-01-01T00:00:00Z"
            lastChannel = "powershell"; tools = @("kilocode"); language = "en"; mcpServers = @()
            files = [ordered]@{ ".kilocode/workflows/custom.md" = [ordered]@{ source = "legacy"; installedHash = $recordedHash } }
            foreignFiles = [ordered]@{}; integrations = [ordered]@{}
        }
        [System.IO.File]::WriteAllText((Join-Path $project ".ai-rules.json"), (($manifest | ConvertTo-Json -Depth 10) + "`n"), [System.Text.UTF8Encoding]::new($false))
        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
            "update", "-ProjectRoot", $project, "-Source", $script:ForkRoot,
            "-NonInteractive", "-AssumeYes", "-McpMode", "managed"
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        (Get-Content -Raw -Encoding UTF8 $legacyFile) | Should -Be "user change"
        $result.Output | Should -Match "Preserved 1 user-modified legacy"
        $migrated = Get-Content -Raw -Encoding UTF8 (Join-Path $project ".ai-rules.json") | ConvertFrom-Json
        @($migrated.legacyArtifacts.preservedProject).Count | Should -Be 1
    }
}

Describe "Always-on context budget" -Tag "Fast" {
    It "keeps source AGENTS.md within 24 KiB and references real rule files" {
        $agentsPath = Join-Path $script:ForkRoot "AGENTS.md"
        (Get-Item $agentsPath).Length | Should -BeLessOrEqual 24576
        $text = Get-Content -Raw -Encoding UTF8 $agentsPath
        ([Text.UTF8Encoding]::new($false).GetByteCount(($text -replace "`r`n", "`n"))) | Should -BeLessOrEqual 7354
        foreach ($match in [regex]::Matches($text, 'content/rules/([A-Za-z0-9-]+\.md)')) {
            Test-Path (Join-Path $script:ForkRoot ("content\rules\" + $match.Groups[1].Value)) | Should -BeTrue
        }
        (Get-Item (Join-Path $script:CombinedProject "AGENTS.md")).Length | Should -BeLessOrEqual 24576
    }

    It "records all functional downstream patch identifiers" {
        $ledger = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "docs\DOWNSTREAM-PATCHES.md")
        foreach ($id in @("ITL-INSTALL-001", "ITL-MANIFEST-001", "ITL-LAYOUT-001", "ITL-CODEX-001", "ITL-KILO-001", "ITL-KILO-002", "ITL-CONTEXT-001")) {
            $ledger | Should -Match $id
        }
    }

    It "routes implementation through USER-RULES without weakening quick-fix verification" {
        $agents = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")
        $agents | Should -Match '(?is)before the first.*edit.*USER-RULES\.md.*development-process\.md'
        $agents | Should -Match '(?is)completion gate.*stale.*failed.*missing.*blocker.*not completion'

        $pipeline = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\subagent-pipeline.md")
        $pipeline | Should -Not -Match '(?i)direct edit\s*\+\s*`?syntaxcheck'
        $pipeline | Should -Not -Match '(?i)syntaxcheck only'
        $pipeline | Should -Match '(?is)quick-fix.*focused regression scenario.*project-required final gate'

        $adapter = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "adapters\kilocode.yaml")
        $adapter | Should -Match '(?ms)^projectInstructions:\s*\r?\n\s+target:\s+"\.kilo/kilo\.json"\s*\r?\n\s+files:\s+\["USER-RULES\.md"\]'
    }
}
