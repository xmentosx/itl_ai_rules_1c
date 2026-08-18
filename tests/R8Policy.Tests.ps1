BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "r8 policy overlays" -Tag "Fast" {
    It "keeps upstream cross-reference anchors in the compact root contract" {
        $agents = Get-Content -LiteralPath (Join-Path $script:ForkRoot "AGENTS.md") -Raw -Encoding UTF8
        foreach ($anchor in @(
            "## Skills and Subagents",
            "### A.7 Platform capability discovery",
            "### A.8 Query formulation for templatesearch",
            "### A.9 Reuse a matching template"
        )) {
            $agents | Should -Match ([regex]::Escape($anchor))
        }
        (Get-Content -LiteralPath (Join-Path $script:ForkRoot "content/commands/update1cbase.md") -Raw -Encoding UTF8) |
            Should -Match ([regex]::Escape("## Update retry loop"))
    }

    It "pins upstream mode defaults without adding CAVEMAN categories" {
        $envText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot ".dev.env.example")
        foreach ($line in @(
            "UI_TESTING=", "ORCHESTRATION=", "QUICKFIX_MAX_LINES=",
            "VERIFICATION_DEPTH=", "SUPPORT_GUARD=", "AGENT_MODEL=", "PLATFORM_ARGS=", "IBCMD_ARGS=",
            "SUBAGENT_MODEL_CODING=", "SUBAGENT_MODEL_ANALYSIS=", "SUBAGENT_MODEL_LIGHT=", "CAVEMAN=", "CAVEMAN_LEVEL=full"
        )) { $envText | Should -Match ("(?m)^" + [regex]::Escape($line) + "\r?$") }
        $envText | Should -Match 'Empty / invalid = standard'
        $envText | Should -Not -Match '(?m)^CAVEMAN_(DEVELOPMENT|ANALYSIS|DOCUMENTATION)='
    }

    It "keeps standard upstream caveman semantics" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/caveman.md")
        $text | Should -Match 'on` \(default\).*all.*tasks'
        $text | Should -Match '`auto`.*development.*analysis / review / documentation'
        $text | Should -Match 'lite` / `full` / `ultra'
        $text | Should -Match 'persist <lite\|full\|ultra>'
        $text | Should -Match '`CAVEMAN_LEVEL` \(missing file / missing key / empty / invalid value = `full`\)'
        $text | Should -Match '\*\*Session-only \(no file change\):\*\* `lite` / `full` / `ultra`'
        $text | Should -Match 'Set only `CAVEMAN_LEVEL=<level>`'
        $text | Should -Match 'Do not change `CAVEMAN`'
        $text | Should -Match 'Read `.dev.env` and report, without editing anything'
        $text | Should -Not -Match 'CAVEMAN_DEVELOPMENT|CAVEMAN_ANALYSIS|CAVEMAN_DOCUMENTATION'
    }

    It "keeps doctor read-only and ITL-owned" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/doctor.md")
        $text | Should -Match 'Do not edit files'
        $text | Should -Match 'exactly one supported client'
        $text | Should -Match 'branch infobase only'
        $text | Should -Match 'OK`, `WARN`, `FAIL`, and `SKIP'
        $text | Should -Match 'pinned `update-ai-rules`'
        $text | Should -Match 'Never recommend hidden `/updaterules`'
        $text | Should -Match 'native.*natural'
        $text | Should -Match 'Expected `bundleSkipped` is `OK`'
        $text | Should -Match 'missing file from a previously managed native bundle is `FAIL`'
    }

    It "guards evolve precedence and per-entry approval" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/evolve.md")
        $text | Should -Match 'USER-RULES.md.*override.*LLM-RULES.md'
        $text | Should -Match 'Safety-relevant entries require their own explicit confirmation'
        $text | Should -Match 'Every written entry has explicit per-entry user approval'
        $text | Should -Match 'The command never runs unasked'
        $text | Should -Match 'writes \*\*only\*\* `LLM-RULES.md`'
    }

    It "uses the single-client pinned economy rerender and standard RTK commands" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/economymode.md")
        $text | Should -Match 'one active client.*\.ai-rules.json.*`tools`'
        $text | Should -Match 'OpenCode and Kilo Code.*`provider/model`'
        $text | Should -Match 'pinned `update-ai-rules`'
        $text | Should -Match '/itl-refresh'
        $text | Should -Match 'Never invoke hidden `/updaterules`'
        foreach ($command in @('rtk init -g`', 'rtk init -g --agent cursor', 'rtk init -g --codex', 'rtk init -g --opencode', 'rtk init --agent kilocode')) {
            $text | Should -Match ([regex]::Escape($command))
        }
    }

    It "routes all four legacy commands through ITL state reconciliation" {
        $expectations = @{
            "update1cbase" = "update-dev-branch-base"
            "loadfrom1cbase" = "transactional full dump"
            "getconfigfiles" = "transactional partial dump"
            "deploy-and-test" = "check-dev-branch.*trigger=command"
        }
        foreach ($name in $expectations.Keys) {
            $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/$name.md")
            $text | Should -Match 'managed `itldev/\*`'
            $text | Should -Match 'branch infobase'
            $text | Should -Match $expectations[$name]
            $text | Should -Match 'state|fingerprint|verification'
        }
    }

    It "routes structural Form.xml edits through 1c-form-edit" {
        $agentsText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")
        $skillText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/skills/1c-metadata-manage/SKILL.md")
        $formRulesText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/forms-add.md")
        $formManageText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/skills/1c-metadata-manage/docs/form-manage.md")
        $formDslText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/skills/1c-metadata-manage/docs/form-compile-dsl.md")

        $agentsText | Should -Match ([regex]::Escape('existing `Form.xml` must use `1c-form-edit`'))
        $skillText | Should -Match ([regex]::Escape('is never an unambiguous one-line fix'))
        $skillText | Should -Match ([regex]::Escape('state which form tool was considered and why it does not apply'))
        $formRulesText | Should -Match ([regex]::Escape('line count and apparent simplicity do not make structural XML insertion a manual one-line fix'))
        $formRulesText | Should -Match ([regex]::Escape('XSD validation is mandatory'))
        $formRulesText | Should -Match ([regex]::Escape('set both `changeRowSet: false` and `changeRowOrder: false`'))
        $formRulesText | Should -Match ([regex]::Escape('does not replace these properties'))
        $formRulesText | Should -Match ([regex]::Escape('do not prohibit programmatic row changes in BSL'))
        foreach ($text in @($formManageText, $formDslText)) {
            $text | Should -Match ([regex]::Escape('`changeRowSet: boolean`'))
            $text | Should -Match ([regex]::Escape('`changeRowOrder: boolean`'))
            $text | Should -Match ([regex]::Escape('"changeRowSet": false, "changeRowOrder": false'))
        }
    }

    It "preserves explicit table row-change booleans in 1c-form-edit" {
        $testRoot = New-ForkTestRoot
        try {
            $formEdit = Join-Path $script:ForkRoot "content/skills/1c-metadata-manage/tools/1c-form-edit/scripts/form-edit.ps1"
            $formTemplate = '<?xml version="1.0" encoding="UTF-8"?><Form xmlns="http://v8.1c.ru/8.3/xcf/logform" version="2.17"><ChildItems /></Form>'
            $cases = @(
                @{ Name = "FalseValues"; Definition = [ordered]@{ table = "FalseValues"; path = "FalseValues"; changeRowSet = $false; changeRowOrder = $false }; Expected = "false" },
                @{ Name = "TrueValues"; Definition = [ordered]@{ table = "TrueValues"; path = "TrueValues"; changeRowSet = $true; changeRowOrder = $true }; Expected = "true" },
                @{ Name = "AbsentValues"; Definition = [ordered]@{ table = "AbsentValues"; path = "AbsentValues" }; Expected = $null }
            )

            foreach ($case in $cases) {
                $formPath = Join-Path $testRoot "$($case.Name)-Form.xml"
                $jsonPath = Join-Path $testRoot "$($case.Name)-edit.json"
                [System.IO.File]::WriteAllText($formPath, $formTemplate, (New-Object System.Text.UTF8Encoding($true)))
                $definition = [ordered]@{ elements = @($case.Definition) } | ConvertTo-Json -Depth 5
                [System.IO.File]::WriteAllText($jsonPath, $definition, (New-Object System.Text.UTF8Encoding($false)))

                $result = Invoke-WindowsPowerShellFile -FilePath $formEdit -Arguments @("-FormPath", $formPath, "-JsonPath", $jsonPath)
                $result.ExitCode | Should -Be 0 -Because $result.Output

                [xml]$form = Get-Content -LiteralPath $formPath -Raw -Encoding UTF8
                $ns = New-Object System.Xml.XmlNamespaceManager($form.NameTable)
                $ns.AddNamespace("f", "http://v8.1c.ru/8.3/xcf/logform")
                $table = $form.SelectSingleNode("/f:Form/f:ChildItems/f:Table[@name='$($case.Name)']", $ns)
                $table | Should -Not -BeNullOrEmpty
                $rowSet = $table.SelectSingleNode("f:ChangeRowSet", $ns)
                $rowOrder = $table.SelectSingleNode("f:ChangeRowOrder", $ns)
                if ($null -eq $case.Expected) {
                    $rowSet | Should -BeNullOrEmpty
                    $rowOrder | Should -BeNullOrEmpty
                } else {
                    $rowSet.InnerText | Should -Be $case.Expected
                    $rowOrder.InnerText | Should -Be $case.Expected
                }
            }
        } finally {
            if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
        }
    }

    It "does not promote eligible internal BSL fixes solely for correcting behavior" {
        $agentsText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")
        foreach ($marker in @(
            'apply its promotion triggers exactly',
            'An internal BSL fix that preserves public contracts may remain a quick-fix',
            'do not promote it solely because it corrects existing behavior',
            'relevant Vanessa coverage exists or was updated',
            'a fresh successful `/itl-check` completed after the last change'
        )) {
            $agentsText | Should -Match ([regex]::Escape($marker))
        }

        $agentsText | Should -Not -Match 'public APIs.*changes to existing behavior always promote'
    }

    It "keeps execution path independent from planning mode" {
        $agentsText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")
        $userRulesText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "USER-RULES.md")
        $developmentProcessText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/development-process.md")
        $contract = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "tests/fixtures/triage-contract.json") | ConvertFrom-Json

        $agentsText | Should -Match ([regex]::Escape('Full-cycle is not OpenSpec'))
        @($contract.executionPaths) | Should -Be @("quick-fix", "full-cycle")
        @($contract.planningModes) | Should -Be @("direct", "OpenSpec")
        $contract.defaultPlanningMode | Should -Be "direct"
        $contract.planningModeChangesVerificationDepth | Should -BeFalse
        $contract.promotionTriggerSetsExecutionPath | Should -Be "full-cycle"
        $contract.promotionTriggerSetsPlanningMode | Should -BeNullOrEmpty
        $contract.requiresPersistedRuntimeState | Should -BeFalse
        @($contract.validCombinations).Count | Should -Be 4
        foreach ($text in @($agentsText, $userRulesText, $developmentProcessText)) {
            $text | Should -Match ([regex]::Escape('executionPath=quick-fix|full-cycle'))
            $text | Should -Match ([regex]::Escape('planningMode=direct|OpenSpec'))
        }
        $userRulesText | Should -Match 'Promotion triggers.*never change `planningMode`'
        $developmentProcessText | Should -Not -Match 'records `quick-fix` or `OpenSpec` in workflow state'
        $developmentProcessText | Should -Not -Match 'promote it to OpenSpec'
    }
}
