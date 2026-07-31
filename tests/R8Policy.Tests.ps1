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
            "UI_TESTING=manual", "ORCHESTRATION=standard", "QUICKFIX_MAX_LINES=40",
            "VERIFICATION_DEPTH=full", "SUBAGENT_MODEL_CODING=", "SUBAGENT_MODEL_ANALYSIS=",
            "SUBAGENT_MODEL_LIGHT=", "CAVEMAN="
        )) { $envText | Should -Match ("(?m)^" + [regex]::Escape($line) + "\r?$") }
        $envText | Should -Not -Match '(?m)^CAVEMAN_(DEVELOPMENT|ANALYSIS|DOCUMENTATION)='
    }

    It "keeps standard upstream caveman semantics" {
        $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/commands/caveman.md")
        $text | Should -Match 'on` \(default\).*all.*tasks'
        $text | Should -Match '`auto`.*development.*analysis / review / documentation'
        $text | Should -Match 'lite` / `full` / `ultra'
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
        $text | Should -Match 'cannot be weakened or bypassed'
        $text | Should -Match 'separate explicit approval for every entry'
        $text | Should -Match 'controlled fork.*immutable release'
        $text | Should -Match 'migration snapshot and rollback'
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

        $agentsText | Should -Match ([regex]::Escape('existing `Form.xml` must use `1c-form-edit`'))
        $skillText | Should -Match ([regex]::Escape('is never an unambiguous one-line fix'))
        $skillText | Should -Match ([regex]::Escape('state which form tool was considered and why it does not apply'))
        $formRulesText | Should -Match ([regex]::Escape('line count and apparent simplicity do not make structural XML insertion a manual one-line fix'))
        $formRulesText | Should -Match ([regex]::Escape('XSD validation is mandatory'))
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

    It "keeps full-cycle execution separate from OpenSpec planning" {
        $agentsText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")
        $userRulesText = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "USER-RULES.md")

        $agentsText | Should -Match ([regex]::Escape('Full-cycle is not OpenSpec'))
        $userRulesText | Should -Match ([regex]::Escape('executionPath=quick-fix|full-cycle'))
        $userRulesText | Should -Match ([regex]::Escape('planningMode=direct|OpenSpec'))
        $userRulesText | Should -Match 'Promotion triggers.*never force OpenSpec'
        $userRulesText | Should -Not -Match 'record `quick-fix` or `OpenSpec`'
    }
}
