BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "Current upstream hardening contracts" -Tag "Fast" {
    It "keeps the compact root addressable by upstream headings" {
        $root = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")
        foreach ($heading in @(
            "## Core Principles",
            "## Active model adaptation",
            "## Development Procedure",
            "## MCP Tool Calling",
            "## Coding Standards",
            "## Skills and Subagents",
            "## Project memory",
            "## Rules self-improvement"
        )) {
            $root | Should -Match ([regex]::Escape($heading))
        }
        ([System.Text.Encoding]::UTF8.GetByteCount($root)) | Should -BeLessThan 22000
    }

    It "keeps support protection fail-closed by default for edit and removal" {
        $edit = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-meta-edit\scripts\meta-edit.ps1")
        $remove = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-meta-remove\scripts\meta-remove.ps1")
        foreach ($text in @($edit, $remove)) {
            $text | Should -Match "SUPPORT_GUARD \(deny\|warn\|off, default deny"
            $text | Should -Match 'if \(\$mode -eq ''off''\) \{ return \}'
            $text | Should -Match 'if \(\$mode -eq ''warn''\)'
            $text | Should -Match "unreadable / unparseable support state"
            $text | Should -Match "exit 1"
            $text | Should -Match "support-edit"
        }
        $remove | Should -Match "Assert-EditAllowed .*'removed'"
        $remove | Should -Match 'code = "not-removed"'
    }

    It "uses the new common environment resolver and DT operations" {
        Test-Path (Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\_common\DevEnv.ps1") | Should -BeTrue
        Test-Path (Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\_common\Resolve-V8Exe.ps1") | Should -BeFalse
        foreach ($name in @("db-dump-dt.ps1", "db-load-dt.ps1")) {
            $path = Join-Path $script:ForkRoot ("content\skills\1c-metadata-manage\tools\1c-db-ops\scripts\" + $name)
            Test-Path $path | Should -BeTrue
            (Get-Content -Raw -Encoding UTF8 $path) | Should -Match "Assert-ItlLifecycleOwnership"
        }
    }

    It "records triage without inventing runtime state and preserves honest final evidence" {
        $rule = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\verification-policy.md")
        $rule | Should -Match 'record `executionPath=quick-fix\|full-cycle` and'
        $rule | Should -Match 'do not invent runtime state'
        $rule | Should -Match 'evidence needed \*\*now\*\*'
        $rule | Should -Match "pre-change failing run is useful only when cheap"
        $rule | Should -Match "never require two complete executable gates"
        $rule | Should -Match 'Decide separately whether a repeatable regression should be retained'
        $rule | Should -Match 'does not require a saved suite or a mandatory test-plan.md'
        $rule | Should -Match 'explicit skipped/partial evidence'
        $rule | Should -Match 'verificationPolicy=block'
    }

    It "keeps managed ITL memory project-scoped in the placed-once root file" {
        $memory = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'memory.md')
        $route = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content\rules\project-memory.md')
        $memory | Should -Match '(?s)managed ITL project.*project-root file under all four strict criteria'
        $memory | Should -Match 'Do not route\s+project facts to Cognee or OpenViking'
        $memory | Should -Match 'Outside managed ITL projects'
        $route | Should -Match 'The generic Cognee → OpenViking priority and multi-provider recall below apply outside managed ITL projects'
    }

    It "qualifies scoped memory conditionally while preserving generic policy and strict root criteria" {
        $route=Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content/rules/project-memory.md')
        $route | Should -Match 'ITL-SCOPED-MEMORY-V1'
        $route | Should -Match 'explicit ITL opt-in'
        $route | Should -Match 'Six destinations'
        $route | Should -Match 'One fact, one durable write'
        $route | Should -Match 'private user-local pending'
        $route | Should -Match 'Old cycles are explicit history'
        $route | Should -Match 'Preserve TOOL policy, full-cycle/spec versus quick-fix'
        $route | Should -Match '## Gates \(hard\)'
        $route | Should -Match 'Promote to `memory.md` only when all four'
        $route | Should -Match 'Only requested `/evolve`'
        $route | Should -Match 'Memory: searched'
        $route | Should -Match 'Outside|outside managed ITL projects'
    }

    It "bounds managed-form context checks and coordinates repeated runtime defects" {
        $architecture = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\dev-standards-architecture.md")
        $managedForm = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\itl-managed-form-context.md")
        $debugging = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\systematic-debugging.md")
        $fixer = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\agents\error-fixer.md")
        $subagents = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\subagents.md")

        $architecture | Should -Match 'standards\(name="dev-standards-architecture"\)'
        $managedForm | Should -Match 'bsl_scope_members'
        $managedForm | Should -Match 'Client code obtains a predefined value'
        $managedForm | Should -Match 'not a server-only'
        $managedForm | Should -Match 'parameters and return values can cross'
        $managedForm | Should -Match 'not a completion pass'
        $debugging | Should -Match 'standards\(name="systematic-debugging"\)'
        $fixer | Should -Match 'without a partial patch'
        $fixer | Should -Not -Match 'Compilation directive \| Add proper'
        $subagents | Should -Match 'One confirmed defect class has one mutating owner'
        $subagents | Should -Match 'repetition alone selects neither `full-cycle`, OpenSpec, nor an abstraction'
    }
}

Describe "Phase-specific OpenSpec overlays" -Tag "Fast" {
    It "keeps new OpenSpec phases and the upstream optional test-retention contract" {
        $bundle = Join-Path $script:ForkRoot 'content\openspec-bundle'
        $sdd = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'content\rules\sdd-integrations.md') -Raw -Encoding UTF8
        $root = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'AGENTS.md') -Raw -Encoding UTF8
        foreach ($client in @('codex', 'kilocode', 'cursor', 'claude-code', 'opencode')) {
            $files = @(Get-ChildItem -LiteralPath (Join-Path $bundle $client) -Recurse -File -Force)
            foreach ($phase in @('explore', 'propose', 'apply', 'archive', 'update', 'sync')) {
                @($files | Where-Object { $_.Name -match "(?:^|-)${phase}(?:\.|-|$)" -or $_.Directory.Name -match "(?:^|-)${phase}(?:\.|-|$)" }).Count |
                    Should -BeGreaterThan 0 -Because "$client must expose $phase"
            }
        }
        $root | Should -Match 'before OpenSpec work load `content/rules/sdd-integrations\.md`'
        $sdd | Should -Match 'test planning is supported'
        $sdd | Should -Match 'not an implicit full-cycle obligation'
        $sdd | Should -Match 'compare expected and actual outcomes'
        $sdd | Should -Not -Match 'MUST.*test-plan\.md'
    }

    It "retains parent review while leaving implementation delegation optional" {
        $integrationRule = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'content\rules\sdd-integrations.md') -Raw -Encoding UTF8
        $catalog = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'content\rules\subagents.md') -Raw -Encoding UTF8
        $pipeline = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'content\rules\subagent-pipeline.md') -Raw -Encoding UTF8
        $integrationRule | Should -Match 'parent implements directly; delegation is not a prerequisite'
        $integrationRule | Should -Match 'parent owns them unless delegated'
        $integrationRule | Should -Match 'Perform a final change review unless explicitly prohibited'
        $catalog | Should -Match 'Otherwise execute directly'
        $catalog | Should -Match 'pipeline in `subagent-pipeline\.md` applies only when delegation is chosen'
        $pipeline | Should -Match 'Stage 4a — Spec-compliance review'
    }
}
