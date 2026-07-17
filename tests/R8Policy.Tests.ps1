BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "r8 policy overlays" -Tag "Fast" {
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
}
