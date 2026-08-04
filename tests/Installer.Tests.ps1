BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "Fork bootstrap policy" -Tag "Fast" {
    It "keeps main out of project consumption" {
        $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot "docs\FORK-POLICY.md") -Raw -Encoding UTF8
        $text | Should -Match "(?s)origin/main.*never consumed"
        $text | Should -Match "synchronized to the audited upstream snapshot by every\s+pushed release"
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

    It "parses the OpenSpec downstream transformer under the PowerShell parser" {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:ForkRoot "tools\apply-openspec-downstream-overlay.ps1"),
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
        $text | Should -Match "ITL-INFRA-003"
        $text | Should -Match '`keep`'
        $text | Should -Match '`drop`'
        $text | Should -Match '`rewrite`'
        foreach ($id in @("ITL-MCP-002", "ITL-OPENSPEC-001", "ITL-CODEX-OPSX-001", "ITL-METADATA-001")) {
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

    It "keeps the upstream OpenSpec snapshot and only its five native bundles" {
        $bundle = Join-Path $script:ForkRoot "content\openspec-bundle"
        @((Get-ChildItem -LiteralPath $bundle -Directory).Name | Sort-Object) |
            Should -Be @("claude-code", "codex", "cursor", "kilocode", "opencode")
        (Get-Content -LiteralPath (Join-Path $bundle "version.txt") -Raw -Encoding UTF8).Trim() |
            Should -Be "1.2.0"
        foreach ($tool in @("kimi", "qwen", "command-code", "cline", "pi")) {
            Test-Path -LiteralPath (Join-Path $bundle $tool) | Should -BeFalse
        }
    }

    It "recreates explicit-only Codex opsx aliases without duplicating canonical skills" {
        $testRoot = New-ForkTestRoot
        try {
            $sourceRoot = Join-Path $script:ForkRoot "content\openspec-bundle\codex\.codex\skills"
            $targetRoot = Join-Path $testRoot "codex\.codex\skills"
            foreach ($canonical in @("openspec-explore", "openspec-propose", "openspec-apply-change", "openspec-archive-change")) {
                New-Item -ItemType Directory -Force -Path (Join-Path $targetRoot $canonical) | Out-Null
                Copy-Item -LiteralPath (Join-Path $sourceRoot "$canonical\SKILL.md") -Destination (Join-Path $targetRoot "$canonical\SKILL.md")
            }

            $transformer = Join-Path $script:ForkRoot "tools\apply-openspec-downstream-overlay.ps1"
            $first = Invoke-WindowsPowerShellFile -FilePath $transformer -Arguments @("-Root", $testRoot)
            $first.ExitCode | Should -Be 0 -Because $first.Output
            $first.Output | Should -Match 'ITL Codex opsx aliases: updated=8 already-present=0'

            $mapping = [ordered]@{
                "opsx-explore" = "openspec-explore"
                "opsx-propose" = "openspec-propose"
                "opsx-apply" = "openspec-apply-change"
                "opsx-archive" = "openspec-archive-change"
            }
            foreach ($alias in $mapping.Keys) {
                $skillPath = Join-Path $targetRoot "$alias\SKILL.md"
                $policyPath = Join-Path $targetRoot "$alias\agents\openai.yaml"
                (Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8) | Should -Match ([regex]::Escape("../$($mapping[$alias])/SKILL.md"))
                (Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8) | Should -Match 'allow_implicit_invocation:\s*false'
            }

            $before = @(Get-ChildItem -LiteralPath $testRoot -Recurse -File | Sort-Object FullName | ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $second = Invoke-WindowsPowerShellFile -FilePath $transformer -Arguments @("-Root", $testRoot)
            $second.ExitCode | Should -Be 0 -Because $second.Output
            $second.Output | Should -Match 'ITL Codex opsx aliases: updated=0 already-present=8'
            $after = @(Get-ChildItem -LiteralPath $testRoot -Recurse -File | Sort-Object FullName | ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $after | Should -Be $before
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "documents native and natural OpenSpec without hidden package mutation" {
        $documents = @("README.md", "AGENT-INSTALL.md", "openspec/README.md", "content/rules/sdd-integrations.md")
        $combined = ($documents | ForEach-Object {
            Get-Content -LiteralPath (Join-Path $script:ForkRoot $_) -Raw -Encoding UTF8
        }) -join "`n"
        foreach ($tool in @("Kimi", "Qwen", "Command Code", "Cline", "Pi")) {
            $combined | Should -Match ([regex]::Escape($tool))
        }
        $combined | Should -Match '(?i)native'
        $combined | Should -Match '(?i)natural'
        $combined | Should -Match 'bundleSkipped'
        $combined | Should -Match 'never installs `@fission-ai/openspec`|не ставит `@fission-ai/openspec`'
        $combined | Should -Match '(?s)Do not.*run `openspec update`'
        $combined | Should -Match '/opsx\*.*not a universal'
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

    It "repairs stale EOL markers, removes obsolete clean legacy files, and keeps invalid UTF-8 byte-strict" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "eol-migration"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"
            $initResult = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $initResult.ExitCode | Should -Be 0 -Because $initResult.Output

            $manifestPath = Join-Path $projectRoot ".ai-rules.json"
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $managedRel = @($manifest.files.PSObject.Properties.Name | Where-Object { $_ -like '.kilo/agents/*.md' })[0]
            $managedRel | Should -Not -BeNullOrEmpty
            $managedPath = Join-Path $projectRoot ($managedRel -replace '/', '\')
            $originalText = [System.IO.File]::ReadAllText($managedPath)
            $lfText = [regex]::Replace($originalText, "`r`n|`r|`n", "`n")
            $alternateText = if ($originalText.Contains("`r`n")) { $lfText } else { $lfText.Replace("`n", "`r`n") }
            $alternateText | Should -Not -BeExactly $originalText
            [System.IO.File]::WriteAllText($managedPath, $alternateText, [System.Text.UTF8Encoding]::new($false))
            $manifest.files.$managedRel | Add-Member -NotePropertyName userModified -NotePropertyValue $true -Force

            $cleanLegacyRel = '.kilo/commands/obsolete-clean.md'
            $cleanLegacyPath = Join-Path $projectRoot ($cleanLegacyRel -replace '/', '\')
            [System.IO.File]::WriteAllText($cleanLegacyPath, "legacy`n", [System.Text.UTF8Encoding]::new($false))
            $cleanLegacyHash = (Get-FileHash -LiteralPath $cleanLegacyPath -Algorithm SHA256).Hash.ToLowerInvariant()
            [System.IO.File]::WriteAllText($cleanLegacyPath, "legacy`r`n", [System.Text.UTF8Encoding]::new($false))
            $manifest.files | Add-Member -NotePropertyName $cleanLegacyRel -NotePropertyValue ([pscustomobject][ordered]@{
                source = 'legacy-test'; installedHash = $cleanLegacyHash; owners = @('legacy'); userModified = $true
            })

            $binaryLegacyRel = '.kilo/commands/obsolete-invalid-utf8.bin'
            $binaryLegacyPath = Join-Path $projectRoot ($binaryLegacyRel -replace '/', '\')
            [System.IO.File]::WriteAllBytes($binaryLegacyPath, [byte[]]@(0xFF, 0x0A, 0x41))
            $binaryLegacyHash = (Get-FileHash -LiteralPath $binaryLegacyPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $binaryCurrent = [byte[]]@(0xFF, 0x0D, 0x0A, 0x41)
            [System.IO.File]::WriteAllBytes($binaryLegacyPath, $binaryCurrent)
            $manifest.files | Add-Member -NotePropertyName $binaryLegacyRel -NotePropertyValue ([pscustomobject][ordered]@{
                source = 'legacy-test'; installedHash = $binaryLegacyHash; owners = @('legacy'); userModified = $true
            })
            [System.IO.File]::WriteAllText(
                $manifestPath,
                ($manifest | ConvertTo-Json -Depth 100),
                [System.Text.UTF8Encoding]::new($false)
            )

            $updateResult = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "update", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $updateResult.ExitCode | Should -Be 0 -Because $updateResult.Output
            $updateResult.Output | Should -Match 'Cleared 2 stale userModified marker'
            $updateResult.Output | Should -Match ([regex]::Escape($binaryLegacyRel))

            $updatedManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            @($updatedManifest.files.$managedRel.PSObject.Properties.Name) | Should -Not -Contain 'userModified'
            Test-Path -LiteralPath $cleanLegacyPath | Should -BeFalse
            @($updatedManifest.files.PSObject.Properties.Name) | Should -Not -Contain $cleanLegacyRel
            [System.IO.File]::ReadAllBytes($binaryLegacyPath) | Should -Be $binaryCurrent
            $updatedManifest.files.$binaryLegacyRel.userModified | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Legacy root dotenv protection" -Tag "Fast" {
    BeforeAll {
        $script:DotenvCanary = @"
SOURCE_IB=source-canary
IB_USER=ib-canary
IB_PASSWORD=password-canary
REPOSITORY_USER=repository-canary
REPOSITORY_PASSWORD=repository-password-canary
"@ -replace "`n", "`r`n"
    }

    It "preserves exact bytes through full remove and replacement init" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "full-remove"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"
            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "codex", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output

            $dotenvPath = Join-Path $projectRoot ".dev.env"
            [System.IO.File]::WriteAllText($dotenvPath, $script:DotenvCanary, [System.Text.UTF8Encoding]::new($false))
            $before = [System.IO.File]::ReadAllBytes($dotenvPath)
            $manifestPath = Join-Path $projectRoot ".ai-rules.json"
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            [void]$manifest.files.'.dev.env'.PSObject.Properties.Remove("template")
            $manifest.files.'.dev.env' | Add-Member -NotePropertyName userModified -NotePropertyValue $true -Force
            $manifest.files.'.dev.env' | Add-Member -NotePropertyName owners -NotePropertyValue @("codex") -Force
            [System.IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))

            $remove = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "remove", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes"
            )
            $remove.ExitCode | Should -Be 0 -Because $remove.Output
            [System.IO.File]::ReadAllBytes($dotenvPath) | Should -Be $before
            $remove.Output | Should -Not -Match "source-canary|ib-canary|password-canary|repository-canary"

            $replacement = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $replacement.ExitCode | Should -Be 0 -Because $replacement.Output
            [System.IO.File]::ReadAllBytes($dotenvPath) | Should -Be $before
            $replacement.Output | Should -Not -Match "source-canary|ib-canary|password-canary|repository-canary"
            $replacementManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $replacementManifest.files.'.dev.env'.template | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "preserves exact bytes and removes stale ownership during scoped remove" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "scoped-remove"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"
            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "codex", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output

            $dotenvPath = Join-Path $projectRoot ".dev.env"
            [System.IO.File]::WriteAllText($dotenvPath, $script:DotenvCanary, [System.Text.UTF8Encoding]::new($false))
            $before = [System.IO.File]::ReadAllBytes($dotenvPath)
            $manifestPath = Join-Path $projectRoot ".ai-rules.json"
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $manifest.tools = @("codex", "kilocode")
            [void]$manifest.files.'.dev.env'.PSObject.Properties.Remove("template")
            $manifest.files.'.dev.env' | Add-Member -NotePropertyName userModified -NotePropertyValue $true -Force
            $manifest.files.'.dev.env' | Add-Member -NotePropertyName owners -NotePropertyValue @("codex") -Force
            [System.IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))

            $remove = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "remove", "codex", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes"
            )
            $remove.ExitCode | Should -Be 0 -Because $remove.Output
            [System.IO.File]::ReadAllBytes($dotenvPath) | Should -Be $before
            $remove.Output | Should -Not -Match "source-canary|ib-canary|password-canary|repository-canary"
            $updatedManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $updatedManifest.files.'.dev.env'.template | Should -BeTrue
            @($updatedManifest.files.'.dev.env'.owners) | Should -Not -Contain "codex"
            @($updatedManifest.files.'.dev.env'.owners) | Should -Be @("core")
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "backfills template metadata without changing an existing dotenv" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "metadata-backfill"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot "install.ps1"
            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output

            $dotenvPath = Join-Path $projectRoot ".dev.env"
            [System.IO.File]::WriteAllText($dotenvPath, $script:DotenvCanary, [System.Text.UTF8Encoding]::new($false))
            $before = [System.IO.File]::ReadAllBytes($dotenvPath)
            $manifestPath = Join-Path $projectRoot ".ai-rules.json"
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            [void]$manifest.files.'.dev.env'.PSObject.Properties.Remove("template")
            $manifest.files.'.dev.env' | Add-Member -NotePropertyName userModified -NotePropertyValue $true -Force
            $installedHash = [string]$manifest.files.'.dev.env'.installedHash
            [System.IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 20) + "`n"), [System.Text.UTF8Encoding]::new($false))

            $update = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "update", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $update.ExitCode | Should -Be 0 -Because $update.Output
            [System.IO.File]::ReadAllBytes($dotenvPath) | Should -Be $before
            $update.Output | Should -Not -Match "source-canary|ib-canary|password-canary|repository-canary"
            $updatedManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $updatedManifest.files.'.dev.env'.template | Should -BeTrue
            $updatedManifest.files.'.dev.env'.userModified | Should -BeTrue
            $updatedManifest.files.'.dev.env'.installedHash | Should -Be $installedHash
        }
        finally {
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
