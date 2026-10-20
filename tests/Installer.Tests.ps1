BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "Fork bootstrap policy" -Tag "Fast" {
    It 'preserves untracked and user-modified OpenSpec bytes even when Force is requested: <Kind>' -TestCases @(
        @{Kind='identical-untracked'}, @{Kind='different-untracked'}, @{Kind='user-modified'}
    ) {
        param($Kind)
        $installer = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'install.ps1') -Raw -Encoding UTF8
        $prefix = $installer.Substring(0, $installer.IndexOf('# SECTION 14: MAIN DISPATCH'))
        . ([scriptblock]::Create($prefix)) -Command doctor -McpMode delegated -AssumeYes -Force
        Set-StrictMode -Off
        $root = Join-Path $TestDrive "OpenSpec пользователь $Kind"
        $source = Join-Path $TestDrive "OpenSpec источник $Kind"
        $relative = '.agents/skills/openspec-propose/SKILL.md'
        $bundlePath = Join-Path $source "content/openspec-bundle/codex/$relative"
        $targetPath = Join-Path $root $relative
        Write-TextFile -Path $bundlePath -Content "# Canonical proposal`nUTF-8 источник`n"
        $targetText = if ($Kind -eq 'identical-untracked') { Read-TextFile $bundlePath } else { "# Пользовательская версия`r`nс пробелом`r`n" }
        Write-TextFile -Path $targetPath -Content $targetText
        $before = Get-FileSha256 $targetPath
        $manifest = [ordered]@{files=[ordered]@{};integrations=[ordered]@{}}
        if ($Kind -eq 'user-modified') {
            $manifest.files[$relative] = [ordered]@{source="content/openspec-bundle/codex/$relative";installedHash=$before;userModified=$true}
        }
        Invoke-OpenSpecArtifacts -Root $root -SourceRoot $source -ActiveTools @('codex') -Manifest $manifest
        (Get-FileSha256 $targetPath) | Should -Be $before
        if ($Kind -eq 'user-modified') { $manifest.files[$relative].userModified | Should -BeTrue }
        else { $manifest.files.Contains($relative) | Should -BeFalse }
    }

    It 'detects BSP within its own UTF-8 procedure rather than the next platform return: <Kind>' -TestCases @(
        @{Kind='modern';Expected='3.1.12.27'}, @{Kind='legacy';Expected='2.4.7.14'}, @{Kind='expression';Expected=''}
    ) {
        param($Kind,$Expected)
        $installer = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'install.ps1') -Raw -Encoding UTF8
        $prefix = $installer.Substring(0, $installer.IndexOf('# SECTION 14: MAIN DISPATCH'))
        . ([scriptblock]::Create($prefix)) -Command doctor -McpMode delegated -AssumeYes
        Set-StrictMode -Off
        $root = Join-Path $TestDrive "БСП конфигурация $Kind"
        Write-TextFile -Path (Join-Path $root 'Configuration.xml') -Content '<MetaDataObject xmlns:v8="http://v8.1c.ru/8.1/data/core"><Configuration><Properties><Name>Fixture</Name><Synonym><v8:item><v8:lang>ru</v8:lang><v8:content>Конфигурация с пробелом</v8:content></v8:item></Synonym></Properties></Configuration></MetaDataObject>'
        $serverText = @'
Функция ВерсияБиблиотеки() Экспорт
    Возврат ОбновлениеИнформационнойБазыБСП.ВерсияПодсистемы();
КонецФункции
Функция МинимальнаяВерсияПлатформы() Экспорт
    Возврат "8.3.24.1234";
КонецФункции
'@
        if ($Kind -eq 'legacy') { $serverText = $serverText.Replace('ОбновлениеИнформационнойБазыБСП.ВерсияПодсистемы()', '"2.4.7.14"') }
        Write-TextFile -Path (Join-Path $root 'CommonModules/СтандартныеПодсистемыСервер/Ext/Module.bsl') -Content $serverText
        if ($Kind -eq 'modern') {
            Write-TextFile -Path (Join-Path $root 'CommonModules/ОбновлениеИнформационнойБазыБСП/Ext/Module.bsl') -Content @'
Процедура ПриДобавленииПодсистемы(Описание) Экспорт
    Описание.Версия = "3.1.12.27";
КонецПроцедуры
Процедура ДругаяПроцедура(Описание) Экспорт
    Описание.Версия = "9.9.9";
КонецПроцедуры
'@
        }
        $info = Get-1cProjectInfo -Root $root
        $info.Detected | Should -BeTrue
        $info.Synonym | Should -Be 'Конфигурация с пробелом'
        $info.BspDetected | Should -BeTrue
        $info.BspVersion | Should -Be $Expected
        $info.BspVersion | Should -Not -Be '8.3.24.1234'
    }

    It 'updates all six canonical Codex OpenSpec phases and removes only unchanged owned legacy aliases' {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot 'Codex OpenSpec миграция'
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $installer = Join-Path $script:ForkRoot 'install.ps1'
            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                'init','-ProjectRoot',$projectRoot,'-Source',$script:ForkRoot,
                '-Tools','codex','-NonInteractive','-AssumeYes','-McpMode','delegated')
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $phases = @('explore','propose','apply-change','archive-change','update-change','sync-specs')
            $manifestPath = Join-Path $projectRoot '.ai-rules.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($phase in $phases) {
                $rel = ".agents/skills/openspec-$phase/SKILL.md"
                $path = Join-Path $projectRoot $rel
                $text = [IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
                $text | Should -Match 'itl:openspec-integration-v2:start'
                $text | Should -Match 'CAVEMAN=auto.*session level `full`'
                $text | Should -Not -Match 'CAVEMAN_LEVEL|missing or invalid values mean `on/full`'
                Test-Path -LiteralPath (Join-Path $projectRoot ".codex/skills/openspec-$phase/SKILL.md") | Should -BeFalse
                $alias = ".codex/skills/openspec-$phase/SKILL.md"
                $aliasPath = Join-Path $projectRoot $alias
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $aliasPath) | Out-Null
                [IO.File]::WriteAllText($aliasPath,$text,[Text.UTF8Encoding]::new($false))
                $manifest.files | Add-Member -MemberType NoteProperty -Name $alias -Value ([pscustomobject]@{
                    source="content/openspec-bundle/codex/.agents/skills/openspec-$phase/SKILL.md"
                    installedHash=(Get-FileHash -LiteralPath $aliasPath -Algorithm SHA256).Hash.ToLowerInvariant()
                })
            }
            $opsxAliases = [System.Collections.Generic.List[string]]::new()
            # Published r33 also installed four opsx aliases in the canonical
            # directory, with invocation metadata. They are retired too.
            foreach ($stage in @('explore','propose','apply','archive')) {
                foreach ($leaf in @('SKILL.md','agents/openai.yaml')) {
                    $alias = ".agents/skills/opsx-$stage/$leaf"
                    $aliasPath = Join-Path $projectRoot $alias
                    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $aliasPath) | Out-Null
                    [IO.File]::WriteAllText($aliasPath,"r33 alias $stage $leaf CAVEMAN_LEVEL`r`nUTF-8 migration line`r`n",[Text.UTF8Encoding]::new($false))
                    $manifest.files | Add-Member -MemberType NoteProperty -Name $alias -Value ([pscustomobject]@{
                        source="content/openspec-bundle/codex/.codex/skills/opsx-$stage/$leaf"
                        installedHash=(Get-FileHash -LiteralPath $aliasPath -Algorithm SHA256).Hash.ToLowerInvariant()
                    })
                    $opsxAliases.Add($alias)
                }
            }
            # A real Git checkout normalizes only EOL bytes; every original
            # recorded hash stays CRLF while the owned working files become LF.
            $git = Invoke-TestNativeCommand -FilePath 'git' -Arguments @('-C',$projectRoot,'init','--quiet')
            $git.ExitCode | Should -Be 0 -Because $git.Output
            [IO.File]::WriteAllText((Join-Path $projectRoot '.gitattributes'),"* text eol=lf`n",[Text.UTF8Encoding]::new($false))
            $git = Invoke-TestNativeCommand -FilePath 'git' -Arguments (@('-C',$projectRoot,'-c','core.autocrlf=false','add','--','.gitattributes') + @($opsxAliases))
            $git.ExitCode | Should -Be 0 -Because $git.Output
            $git = Invoke-TestNativeCommand -FilePath 'git' -Arguments @('-C',$projectRoot,'-c','user.name=ITL Alias Test','-c','user.email=alias@example.invalid','commit','--quiet','-m','record CRLF aliases normalized in index')
            $git.ExitCode | Should -Be 0 -Because $git.Output
            foreach ($alias in $opsxAliases) { Remove-Item -LiteralPath (Join-Path $projectRoot $alias) -Force }
            $git = Invoke-TestNativeCommand -FilePath 'git' -Arguments (@('-C',$projectRoot,'-c','core.autocrlf=false','checkout','--') + @($opsxAliases))
            $git.ExitCode | Should -Be 0 -Because $git.Output
            foreach ($alias in $opsxAliases) {
                $aliasPath = Join-Path $projectRoot $alias
                [IO.File]::ReadAllText($aliasPath,[Text.Encoding]::UTF8) | Should -Not -Match "`r"
                (Get-FileHash -LiteralPath $aliasPath -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Not -Be $manifest.files.$alias.installedHash
            }
            $invalidAlias = '.agents/skills/opsx-update/SKILL.md'
            $unknownAlias = '.agents/skills/opsx-sync/SKILL.md'
            foreach ($alias in @($invalidAlias,$unknownAlias)) {
                $aliasPath = Join-Path $projectRoot $alias
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $aliasPath) | Out-Null
                [IO.File]::WriteAllText($aliasPath,"negative alias seed`n",[Text.UTF8Encoding]::new($false))
                $manifest.files | Add-Member -MemberType NoteProperty -Name $alias -Value ([pscustomobject]@{
                    source="content/openspec-bundle/codex/.codex/skills/$(Split-Path -Leaf (Split-Path -Parent $alias))/SKILL.md"
                    installedHash=$(if ($alias -eq $unknownAlias) { 'unknown' } else { (Get-FileHash -LiteralPath $aliasPath -Algorithm SHA256).Hash.ToLowerInvariant() })
                })
            }
            $invalidBytes = [byte[]]@(0xC3,0x28,0x0A)
            [IO.File]::WriteAllBytes((Join-Path $projectRoot $invalidAlias),$invalidBytes)
            $foreignAliasFile = Join-Path $projectRoot '.agents/skills/opsx-explore/user-note.md'
            [IO.File]::WriteAllText($foreignAliasFile,'unowned user note',[Text.UTF8Encoding]::new($false))
            # Reproduce the r33 managed destination with its old Caveman policy.
            $legacyPath = Join-Path $projectRoot '.agents/skills/openspec-explore/SKILL.md'
            [IO.File]::WriteAllText($legacyPath,'legacy four-phase bundle: CAVEMAN_LEVEL; missing or invalid values mean `on/full`',[Text.UTF8Encoding]::new($false))
            $manifest.files.'.agents/skills/openspec-explore/SKILL.md'.source = 'content/openspec-bundle/codex/.codex/skills/openspec-explore/SKILL.md'
            $manifest.files.'.agents/skills/openspec-explore/SKILL.md'.installedHash = (Get-FileHash -LiteralPath $legacyPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $manifest.files.'.agents/skills/opsx-propose/SKILL.md' | Add-Member -NotePropertyName userModified -NotePropertyValue $true
            [IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
            $userAlias = Join-Path $projectRoot '.codex/skills/openspec-propose/SKILL.md'
            [IO.File]::WriteAllText($userAlias,'user-authored duplicate must survive',[Text.UTF8Encoding]::new($false))
            $userOpsxAlias = Join-Path $projectRoot '.agents/skills/opsx-propose/SKILL.md'
            [IO.File]::WriteAllText($userOpsxAlias,'user-authored r33 alias must survive',[Text.UTF8Encoding]::new($false))
            $update = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                'update','-ProjectRoot',$projectRoot,'-Source',$script:ForkRoot,'-NonInteractive','-AssumeYes','-McpMode','delegated')
            $update.ExitCode | Should -Be 0 -Because $update.Output
            $update.Output | Should -Match 'Preserved user-modified legacy Codex OpenSpec artifact'
            foreach ($phase in $phases) {
                $canonical = Join-Path $projectRoot ".agents/skills/openspec-$phase/SKILL.md"
                [IO.File]::ReadAllText($canonical,[Text.Encoding]::UTF8) | Should -Match 'itl:openspec-integration-v2:start'
                if ($phase -ne 'propose') {
                    Test-Path -LiteralPath (Join-Path $projectRoot ".codex/skills/openspec-$phase/SKILL.md") | Should -BeFalse
                }
            }
            [IO.File]::ReadAllText($userAlias,[Text.Encoding]::UTF8) | Should -Be 'user-authored duplicate must survive'
            [IO.File]::ReadAllText($userOpsxAlias,[Text.Encoding]::UTF8) | Should -Be 'user-authored r33 alias must survive'
            [IO.File]::ReadAllText($foreignAliasFile,[Text.Encoding]::UTF8) | Should -Be 'unowned user note'
            ([IO.File]::ReadAllBytes((Join-Path $projectRoot $invalidAlias)) -join ',') | Should -Be ($invalidBytes -join ',')
            [IO.File]::ReadAllText((Join-Path $projectRoot $unknownAlias),[Text.Encoding]::UTF8) | Should -Be "negative alias seed`n"
            $updatedManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $updatedManifest.files.'.agents/skills/opsx-propose/SKILL.md'.userModified | Should -BeTrue
            $updatedManifest.files.PSObject.Properties[$invalidAlias] | Should -Not -BeNullOrEmpty
            $updatedManifest.files.PSObject.Properties[$unknownAlias] | Should -Not -BeNullOrEmpty
            foreach ($stage in @('explore','propose','apply','archive')) {
                foreach ($leaf in @('SKILL.md','agents/openai.yaml')) {
                    $alias = ".agents/skills/opsx-$stage/$leaf"
                    if ($stage -eq 'propose' -and $leaf -eq 'SKILL.md') { continue }
                    Test-Path -LiteralPath (Join-Path $projectRoot $alias) | Should -BeFalse
                    $updatedManifest.files.PSObject.Properties[$alias] | Should -BeNullOrEmpty
                }
            }
            [IO.File]::ReadAllText($legacyPath,[Text.Encoding]::UTF8) | Should -Not -Match 'CAVEMAN_LEVEL'
        } finally {
            $resolved = [IO.Path]::GetFullPath($testRoot)
            if (-not $resolved.StartsWith(([IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture cleanup escaped the temp root' }
            Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

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

    It "ships the managed project contract in all six native OpenSpec phases" {
        $bundle = Join-Path $script:ForkRoot "content\openspec-bundle"
        $targets = @(Get-ChildItem -LiteralPath $bundle -Recurse -File -Filter "*.md" | Where-Object {
            $_.FullName -match '[\\/]openspec-bundle[\\/](cursor|claude-code|codex|opencode|kilocode)[\\/]' -and
            ($_.Name -match '^opsx-(explore|propose|apply|archive|update|sync)\.md$' -or
             ($_.Directory.Name -eq 'opsx' -and $_.Name -match '^(explore|propose|apply|archive|update|sync)\.md$') -or
             ($_.Name -eq 'SKILL.md' -and $_.Directory.Name -match '^openspec-(explore|propose|apply-change|archive-change|update-change|sync-specs)$'))
        })
        $targets.Count | Should -Be 54
        foreach ($target in $targets) {
            $text = Get-Content -LiteralPath $target.FullName -Raw -Encoding UTF8
            $text | Should -Match '<!-- itl:openspec-integration-v2:start -->'
            $text | Should -Match '<!-- itl:openspec-integration-v2:end -->'
            $text | Should -Match '<!-- itl:project-skill-preflight -->'
            $text | Should -Match '<!-- itl:caveman-response-style -->'
            $text | Should -Match 'managed ITL project.*read project-root `AGENTS.md` and `USER-RULES.md`'
            $text | Should -Match 'CLI pinned to the installed workflow checkout'
            $text | Should -Match 'ITL `openspec-context` action'
            $text | Should -Match 'OPEN_SPEC_EXTERNAL_STORE_DEFERRED'
            $text | Should -Match 'ITL pinned `openspec-new-change` or `openspec-archive-change` action'
            $text | Should -Match 'An existing authorization for this phase and selected change remains valid'
            $text | Should -Match '`CAVEMAN=auto` by default, with session level `full`'
        }
        $update = Get-Content -LiteralPath (Join-Path $bundle 'codex/.agents/skills/openspec-update-change/SKILL.md') -Raw -Encoding UTF8
        $update | Should -Match 'upstream per-artifact confirmation steps apply only to a newly proposed material revision'
        @($targets | Where-Object { $_.FullName -match '[\\/]codex[\\/]' }).Count | Should -Be 6
        (Get-Content -LiteralPath (Join-Path $script:ForkRoot "tools\refresh-openspec-bundle.ps1") -Raw -Encoding UTF8) |
            Should -Match 'apply-openspec-downstream-overlay\.ps1'
    }

    It "keeps the upstream OpenSpec snapshot and only its five native bundles" {
        $bundle = Join-Path $script:ForkRoot "content\openspec-bundle"
        @((Get-ChildItem -LiteralPath $bundle -Directory).Name | Sort-Object) |
            Should -Be @("claude-code", "codex", "cursor", "kilocode", "opencode")
        (Get-Content -LiteralPath (Join-Path $bundle "version.txt") -Raw -Encoding UTF8).Trim() |
            Should -Be "1.13.1"
        foreach ($tool in @("kimi", "qwen", "command-code", "cline", "pi")) {
            Test-Path -LiteralPath (Join-Path $bundle $tool) | Should -BeFalse
        }
    }

    It "keeps the official Codex skill names without duplicate aliases" {
        $bundle = Join-Path $script:ForkRoot "content\openspec-bundle"
        $codexRoot = Join-Path $bundle 'codex\.agents\skills'
        @((Get-ChildItem -LiteralPath $codexRoot -Directory).Name | Sort-Object) |
            Should -Be @('openspec-apply-change', 'openspec-archive-change', 'openspec-explore',
                'openspec-propose', 'openspec-sync-specs', 'openspec-update-change')
        Test-Path -LiteralPath (Join-Path $bundle 'codex\.codex\skills') | Should -BeFalse
    }

    It "installs an OpenSpec config accepted as a mapping by the pinned CLI" {
        # A comment-only YAML document resolves to null and OpenSpec 1.13.1
        # reports that config.yaml is not a valid YAML object.
        $config = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'openspec/config.yaml') -Raw -Encoding UTF8
        $config | Should -Match '(?m)^schema: spec-driven\r?$'
    }

    It "retains all six official command names in each native client layout" {
        $bundle = Join-Path $script:ForkRoot "content\openspec-bundle"
        $stages = @("explore", "propose", "apply", "archive", "sync", "update")
        $roots = [ordered]@{
            "claude-code" = ".claude\commands\opsx"
            "cursor" = ".cursor\commands"
            "kilocode" = ".kilocode\workflows"
            "opencode" = ".opencode\commands"
        }
        foreach ($client in $roots.Keys) {
            $commandRoot = Join-Path (Join-Path $bundle $client) $roots[$client]
            $expected = if ($client -eq 'claude-code') { @($stages | Sort-Object) }
                else { @($stages | ForEach-Object { "opsx-$_" } | Sort-Object) }
            @((Get-ChildItem -LiteralPath $commandRoot -File -Filter '*.md').BaseName | Sort-Object) |
                Should -Be $expected
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
        $combined | Should -Match 'Do not run\s+`openspec update` or install `@fission-ai/openspec` globally'
        $combined | Should -Match '/opsx\*` is not a universal'
    }

    It "repairs one OpenSpec overlay without changing the other native files" {
        $testRoot = New-ForkTestRoot
        try {
            $bundle = Join-Path $script:ForkRoot 'content\openspec-bundle'
            foreach ($tool in @('cursor', 'claude-code', 'codex', 'opencode', 'kilocode')) {
                Copy-Item -LiteralPath (Join-Path $bundle $tool) -Destination $testRoot -Recurse
            }
            $sampleRelative = 'codex\.agents\skills\openspec-propose\SKILL.md'
            $sample = Join-Path $testRoot $sampleRelative
            $originalHash = (Get-FileHash -LiteralPath $sample -Algorithm SHA256).Hash
            $raw = Get-Content -LiteralPath $sample -Raw -Encoding UTF8
            $withoutOverlay = [regex]::Replace($raw,
                '(?s)\n?<!-- itl:openspec-integration-v2:start -->.*?<!-- itl:openspec-integration-v2:end -->\n*', "`n")
            [IO.File]::WriteAllText($sample, $withoutOverlay, [Text.UTF8Encoding]::new($false))
            $transformer = Join-Path $script:ForkRoot "tools\apply-openspec-downstream-overlay.ps1"
            $first = Invoke-WindowsPowerShellFile -FilePath $transformer -Arguments @("-Root", $testRoot)
            $first.ExitCode | Should -Be 0 -Because $first.Output
            $first.Output | Should -Match 'OpenSpec ITL overlay: files=54 changed=1'
            (Get-FileHash -LiteralPath $sample -Algorithm SHA256).Hash | Should -Be $originalHash
            $before = @(Get-ChildItem -LiteralPath $testRoot -Recurse -File | Sort-Object FullName |
                ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $second = Invoke-WindowsPowerShellFile -FilePath $transformer -Arguments @("-Root", $testRoot)
            $second.ExitCode | Should -Be 0 -Because $second.Output
            $after = @(Get-ChildItem -LiteralPath $testRoot -Recurse -File | Sort-Object FullName |
                ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $after | Should -Be $before
            $second.Output | Should -Match 'OpenSpec ITL overlay: files=54 changed=0'
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'preserves <Eol> and BOM=<Bom> in an exact OpenSpec overlay repair and no-op' -TestCases @(
        @{Eol='LF';Bom=$false}, @{Eol='CRLF';Bom=$false},
        @{Eol='LF';Bom=$true}, @{Eol='CRLF';Bom=$true}
    ) {
        param($Eol,$Bom)
        $testRoot = New-ForkTestRoot
        try {
            $root = Join-Path $testRoot 'OpenSpec байты с пробелом'
            New-Item -ItemType Directory -Path $root | Out-Null
            $bundle = Join-Path $script:ForkRoot 'content/openspec-bundle'
            foreach ($tool in @('cursor','claude-code','codex','opencode','kilocode')) {
                Copy-Item -LiteralPath (Join-Path $bundle $tool) -Destination $root -Recurse
            }
            $sample = Join-Path $root 'codex/.agents/skills/openspec-propose/SKILL.md'
            $original = [IO.File]::ReadAllText($sample).Replace("`r`n","`n")
            if ($Eol -eq 'CRLF') { $original = $original.Replace("`n","`r`n") }
            $encoding = [Text.UTF8Encoding]::new($Bom)
            [IO.File]::WriteAllText($sample,$original,$encoding)
            $before = @(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName |
                ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $withoutOverlay = [regex]::Replace($original.Replace("`r`n","`n"),
                '(?s)\n?<!-- itl:openspec-integration-v2:start -->.*?<!-- itl:openspec-integration-v2:end -->\n*',"`n")
            if ($Eol -eq 'CRLF') { $withoutOverlay = $withoutOverlay.Replace("`n","`r`n") }
            [IO.File]::WriteAllText($sample,$withoutOverlay,$encoding)
            $transformer = Join-Path $script:ForkRoot 'tools/apply-openspec-downstream-overlay.ps1'
            $first = Invoke-WindowsPowerShellFile -FilePath $transformer -Arguments @('-Root',$root)
            $first.ExitCode | Should -Be 0 -Because $first.Output
            $first.Output | Should -Match 'OpenSpec ITL overlay: files=54 changed=1'
            $after = @(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName |
                ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $after | Should -Be $before
            $second = Invoke-WindowsPowerShellFile -FilePath $transformer -Arguments @('-Root',$root)
            $second.ExitCode | Should -Be 0 -Because $second.Output
            $second.Output | Should -Match 'OpenSpec ITL overlay: files=54 changed=0'
            $noop = @(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName |
                ForEach-Object { (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash })
            $noop | Should -Be $before
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
    It "preserves delegated MCP data and routes Kilo through root AGENTS" {
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
            @($kilo.PSObject.Properties.Name) | Should -Not -Contain 'instructions'
            (Get-Content -LiteralPath (Join-Path $projectRoot 'AGENTS.md') -Raw -Encoding UTF8) |
                Should -Match 'USER-RULES\.md'
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            $manifest.integrations.mcp.owner | Should -Be "ITL"
            @($manifest.mcpServers) | Should -BeNullOrEmpty
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".codex/config.toml"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
            $result.Output | Should -Match 'MCP: delegated to ITL workflow; client configs remain untouched'
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
            @($kilo.PSObject.Properties.Name) | Should -Not -Contain 'instructions'
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".codex/config.toml"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "adds a second delegated client while preserving the foreign Kilo config" {
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
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $kilo = Get-Content -Raw -Encoding UTF8 $kiloPath | ConvertFrom-Json
            $kilo.permission.bash | Should -Be "ask"
            $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot ".ai-rules.json") | ConvertFrom-Json
            @($manifest.tools) | Should -Be @("codex", "kilocode")
            $manifest.integrations.mcp.mode | Should -Be "delegated"
            @($manifest.files.PSObject.Properties.Name) | Should -Not -Contain ".kilo/kilo.json"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Kilo foreign project configuration" -Tag "Fast" {
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

    It "leaves a foreign Kilo config byte-identical and loads USER-RULES from AGENTS" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "kilo-instructions"
            $kiloPath = Join-Path $projectRoot ".kilo\kilo.json"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $kiloPath) | Out-Null
            $source = '{"$schema":"https://example.test/kilo.schema.json","instructions":["docs/a.md","user-rules.md","USER-RULES.md","docs/b.md"],"mcp":{"custom":{"type":"remote","url":"http://127.0.0.1:9999/mcp"}},"permission":{"bash":"ask"},"agent":{"review":{"model":"custom"}},"skills":{"paths":["skills"]},"theme":"user"}'
            [System.IO.File]::WriteAllText($kiloPath, $source, [System.Text.UTF8Encoding]::new($false))
            $before = (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash
            $installer = Join-Path $script:ForkRoot "install.ps1"

            $init = Invoke-WindowsPowerShellFile -FilePath $installer -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $init.ExitCode | Should -Be 0 -Because $init.Output
            (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash | Should -Be $before
            $config = Get-Content -Raw -Encoding UTF8 $kiloPath | ConvertFrom-Json
            @($config.instructions) | Should -Be @("docs/a.md", "user-rules.md", "USER-RULES.md", "docs/b.md")
            $config.'$schema' | Should -Be "https://example.test/kilo.schema.json"
            $config.mcp.custom.url | Should -Be "http://127.0.0.1:9999/mcp"
            $config.permission.bash | Should -Be "ask"
            $config.agent.review.model | Should -Be "custom"
            @($config.skills.paths) | Should -Be @("skills")
            $config.theme | Should -Be "user"

            (Get-Content -LiteralPath (Join-Path $projectRoot 'AGENTS.md') -Raw -Encoding UTF8) |
                Should -Match 'USER-RULES\.md'
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

    It "does not create a Kilo config when delegated MCP has no config to own" {
        $testRoot = New-ForkTestRoot
        try {
            $projectRoot = Join-Path $testRoot "kilo-empty"
            New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
            $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
                "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                "-Tools", "kilocode", "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            Test-Path -LiteralPath (Join-Path $projectRoot '.kilo\kilo.json') | Should -BeFalse
            (Get-Content -LiteralPath (Join-Path $projectRoot 'AGENTS.md') -Raw -Encoding UTF8) |
                Should -Match 'USER-RULES\.md'
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "preserves foreign Kilo JSON even when its instructions are invalid" -TestCases @(
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
            $result.ExitCode | Should -Be 0 -Because $result.Output
            (Get-FileHash -Algorithm SHA256 -LiteralPath $kiloPath).Hash | Should -Be $before
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
