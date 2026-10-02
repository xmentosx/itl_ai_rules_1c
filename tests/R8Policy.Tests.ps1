BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "r8 policy overlays" -Tag "Fast" {
    It "keeps new upstream root routes and platform/template obligations" {
        $agents = Get-Content -LiteralPath (Join-Path $script:ForkRoot "AGENTS.md") -Raw -Encoding UTF8
        foreach ($anchor in @(
            "## Skills and Subagents",
            "**Platform first:**",
            '**`templatesearch`:**',
            "**Template reuse:**"
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
            "SUBAGENT_MODEL_CODING=", "SUBAGENT_MODEL_ANALYSIS=", "SUBAGENT_MODEL_LIGHT=", "CAVEMAN="
        )) { $envText | Should -Match ("(?m)^" + [regex]::Escape($line) + "\r?$") }
        (Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/rules/dev-standards-env.md')) | Should -Match 'Empty / invalid = `standard`'
        $envText | Should -Not -Match '(?m)^CAVEMAN_LEVEL='
        $envText | Should -Not -Match '(?m)^CAVEMAN_(DEVELOPMENT|ANALYSIS|DOCUMENTATION)='
    }

    It "keeps accepted auto/full and session-only caveman semantics" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/caveman.md")
        $text | Should -Match 'on.*off.*auto'
        $text | Should -Match '`full` \(default\)'
        $text | Should -Match '\*\*Session-only \(no file change\):\*\* `lite` / `full` / `ultra`'
        $text | Should -Not -Match 'persist <lite\|full\|ultra>'
        $text | Should -Match 'The command edits \*\*only\*\* the `CAVEMAN` line'
        $text | Should -Match 'Read `.dev.env` and report, without editing anything'
        $text | Should -Not -Match 'CAVEMAN_DEVELOPMENT|CAVEMAN_ANALYSIS|CAVEMAN_DOCUMENTATION'
    }

    It "keeps named UI runs session-scoped while respecting no-UI and provider limits" {
        $environment = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/rules/dev-standards-env.md')
        $loop = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/commands/test-fix-loop.md')
        $editor = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/commands/uitests.md')
        $tester = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/rules/subagents.md')
        $deploy = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/commands/deploy-and-test.md')
        $agent = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/agents/tester.md')
        $doctor = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/commands/doctor.md')
        $qa = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/skills/1c-qa-testing/SKILL.md')
        $qa | Should -Match '`manual` / `off` only for an explicitly named one-off UI run, for that invocation only'
        $qa | Should -Match 'broader current no-UI instruction still forbids the run'
        $qa | Should -Not -Match 'never under `off`'
        $environment | Should -Match 'explicitly named one-off UI run.*for that invocation only'
        $environment | Should -Match 'broader current no-UI instruction still forbids'
        $uiPolicy = [regex]::Match($environment, '(?s)#### `UI_TESTING`.*?(?=####)').Value
        $offPolicy = [regex]::Match($uiPolicy, '(?m)^\| `off` \|.*$').Value
        $offPolicy | Should -Match 'explicitly named one-off UI run may override.*for that invocation only'
        $offPolicy | Should -Not -Match 'disabled on every route|A run request alone does not enable'
        # Q23 adopts the upstream default/fallback while retaining the scoped override.
        $environment | Should -Match 'empty resolves to `essential`, an invalid value to `manual`'
        $environment | Should -Match '\| `essential` \(default / empty\).*important new or changed user-visible behaviour'
        $environment | Should -Match 'independent `ITL_VANESSA_TESTING` switch'
        $loop | Should -Match 'exact `/test-fix-loop` request.*under `manual` or `off`'
        $loop | Should -Match 'begin-verification-repair -VerificationRepairKind\s+scenario-loop'
        $loop | Should -Match 'VerificationRepairMaxAttempts N'
        $loop | Should -Match 'same persisted attempt'
        $loop | Should -Match 'Only fresh full evidence completes'
        $loop | Should -Match 'Target and provider prerequisites still apply'
        $editor | Should -Match 'Neither changes the persistent value'
        $tester | Should -Match 'named one-off UI request under `manual`/`off`'
        $deploy | Should -Match 'exact named one-off UI run permits this step'
        $agent | Should -Match 'exact named run may override it'
        $agent | Should -Match 'managed ITL projects use the installed `itl-vanessa-ui-mcp` route'
        $doctor | Should -Match 'invalid `UI_TESTING`.*manual'
    }

    It "keeps doctor read-only and ITL-owned" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/doctor.md")
        $text | Should -Match 'Do not modify files'
        $text | Should -Match 'aiRules.tools'
        $text | Should -Match 'explicit empty set is valid'
        $text | Should -Match 'pinned `agent-1c.ps1 -Action update-ai-rules`'
        $text | Should -Match 'File presence proves placement only'
        $text | Should -Match 'callable tools'
        $text | Should -Match 'no install, attach, repair'
    }

    It "guards evolve precedence and per-entry approval" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/evolve.md")
        $text | Should -Match 'USER-RULES.md.*override.*LLM-RULES.md'
        $text | Should -Match 'Safety-relevant entries require their own explicit confirmation'
        $text | Should -Match 'Every written entry has explicit per-entry user approval'
        $text | Should -Match 'The command never runs unasked'
        $text | Should -Match 'writes \*\*only\*\* `LLM-RULES.md`'
    }

    It "routes economy model changes to the selected client and pinned rerender" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/economymode.md")
        $text | Should -Match 'aiRules.modelTiersByClient'
        $text | Should -Match 'do not copy another client'
        $text | Should -Match 'analysisExplicit: true'
        $text | Should -Match 'pinned `agent-1c.ps1 -Action update-ai-rules`'
        $text | Should -Match '/install-rtk'
    }

    It "routes all four legacy commands through ITL state reconciliation" {
        $expectations = @{
            "update1cbase" = "update-dev-branch-base"
            "loadfrom1cbase" = "matching transactional ITL lifecycle helper"
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

        $agentsText | Should -Match ([regex]::Escape('Read the matching on-demand ITL rule before changing a'))
        $skillText | Should -Match 'form-edit'
        $formRulesText | Should -Match ([regex]::Escape('mandatory execution path'))
        $formRulesText | Should -Match ([regex]::Escape('Hand-editing is allowed only within the narrow exceptions'))
        $formRulesText | Should -Match ([regex]::Escape('XSD validation is mandatory'))
        $formDslText | Should -Match 'changeRowSet'
        $formDslText | Should -Match 'changeRowOrder'
        $formManageText | Should -Match 'form-compile-dsl.md'
        $formDslText | Should -Match ([regex]::Escape('`changeRowSet: boolean`'))
        $formDslText | Should -Match ([regex]::Escape('`changeRowOrder: boolean`'))
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
        $policyText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/verification-policy.md")
        $agentsText | Should -Match 'Quick-fix'
        $policyText | Should -Match ([regex]::Escape('purely internal fix inside an export routine that preserves the contract'))
        $policyText | Should -Match ([regex]::Escape('Gate 1 (`syntaxcheck`) is mandatory'))
        $policyText | Should -Match 'promotion-trigger'
    }

    It "keeps execution path independent from planning mode" {
        $agentsText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")
        $userRulesText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "USER-RULES.md")
        $verificationPolicyText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/verification-policy.md")
        $contract = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "tests/fixtures/triage-contract.json") | ConvertFrom-Json

        $agentsText | Should -Match ([regex]::Escape('Full-cycle does not by itself'))
        @($contract.executionPaths) | Should -Be @("quick-fix", "full-cycle")
        @($contract.planningModes) | Should -Be @("direct", "OpenSpec")
        $contract.defaultPlanningMode | Should -Be "direct"
        $contract.planningModeChangesVerificationDepth | Should -BeFalse
        $contract.promotionTriggerSetsExecutionPath | Should -Be "full-cycle"
        $contract.promotionTriggerSetsPlanningMode | Should -BeNullOrEmpty
        $contract.requiresPersistedRuntimeState | Should -BeFalse
        @($contract.validCombinations).Count | Should -Be 4
        foreach ($text in @($agentsText, $userRulesText)) {
            $text | Should -Match ([regex]::Escape('executionPath=quick-fix|full-cycle'))
            $text | Should -Match ([regex]::Escape('planningMode=direct|OpenSpec'))
        }
        $verificationPolicyText | Should -Match 'task paths.*remain risk-based'
        $userRulesText | Should -Match 'Promotion triggers.*never change `planningMode`'
        $verificationPolicyText | Should -Not -Match 'promotion-trigger.*sets planningMode=OpenSpec'
    }
}
