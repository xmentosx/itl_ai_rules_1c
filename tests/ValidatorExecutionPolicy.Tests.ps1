BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "Code Checker latency policy" -Tag "Fast" {
    BeforeAll {
        $script:Gates = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/verification-gates.md")
        $script:Catalog = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/skills/mcp-1c-tools/docs/1c-code-check-mcp.md")
        $script:Policy = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/verification-policy.md")
        $script:Agents = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")
    }

    It "defers AI validators to one coherent closing snapshot" {
        $script:Gates | Should -Match ([regex]::Escape('MUST NOT call `check_1c_logic`, `check_1c_code`, or `review_1c_code` after intermediate edits'))
        $script:Gates | Should -Match ([regex]::Escape('One call covers one unit'))
        $script:Catalog | Should -Match ([regex]::Escape('call the exposed Gate 2 tool once after implementation'))
        $script:Catalog | Should -Match ([regex]::Escape('call `review_1c_code` once only after logic validation passes'))
    }

    It "forbids ineffective same-server parallel batches" {
        $script:Gates | Should -Match ([regex]::Escape('do not send multiple calls to the same Code Checker server via `Promise.all`'))
        $script:Catalog | Should -Match ([regex]::Escape('Do not send same-server validator calls through `Promise.all`'))
    }

    It "restores standalone syntax before the preferred logic-only Gate 2 tool" {
        $script:Policy | Should -Match ([regex]::Escape('Standalone Gate 1 syntax evidence from `syntaxcheck` / `syntaxcheck_file` is mandatory'))
        $script:Gates | Should -Match ([regex]::Escape('Run standalone `syntaxcheck` / `syntaxcheck_file` on every touched `.bsl` module'))
        $script:Gates | Should -Match ([regex]::Escape('Prefer `check_1c_logic` when it is exposed'))
        $script:Gates | Should -Match ([regex]::Escape('use the upstream-compatible `check_1c_code` fallback'))
        $script:Catalog | Should -Match ([regex]::Escape('does not accept syntax evidence as an argument'))
        $script:Agents | Should -Match ([regex]::Escape('obtain standalone `syntaxcheck` / `syntaxcheck_file` evidence first'))
    }

    It "does not accept Code Checker syntax output as Gate 1 evidence" {
        $script:Policy | Should -Not -Match 'syntax section returned by `check_1c_code`'
        $script:Gates | Should -Not -Match 'satisfies Gate 1'
        $script:Catalog | Should -Not -Match 'do not duplicate it with `syntaxcheck`'
    }

    It "limits ROCTUP Gate 3a equivalence to the qualified read-only query capability" {
        $environment = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/dev-standards-env.md")
        $script:Gates | Should -Match ([regex]::Escape('`TOOL_DATA=off` excludes both providers'))
        $script:Gates | Should -Match ([regex]::Escape('`get_metadata` / bounded `execute_query`'))
        $script:Gates | Should -Match ([regex]::Escape('ROCTUP `execute_code` is not an automatic substitute'))
        $script:Gates | Should -Match ([regex]::Escape('read permission never grants it'))
        $environment | Should -Match ([regex]::Escape('`off` excludes both'))
    }

    It "routes direct roles and command entrypoints to the same preferred Gate 2 provider" {
        $entrypoints = @(
            'content/agents/code-reviewer.md',
            'content/agents/refactoring.md',
            'content/agents/performance-optimizer.md',
            'content/commands/checkmcp.md',
            'content/commands/evolve.md',
            'content/rules/dev-standards-env.md',
            'content/rules/edt-workflow.md',
            'content/rules/orchestrator-economy.md',
            'content/rules/subagent-core.md',
            'content/rules/subagents.md',
            'content/rules/tooling-playbooks.md'
        )
        foreach ($relative in $entrypoints) {
            $route = Get-Content -LiteralPath (Join-Path $script:ForkRoot $relative) -Raw -Encoding UTF8
            $route | Should -Match 'check_1c_logic' -Because "$relative must expose the selected Gate 2 route"
            $route | Should -Match 'check_1c_code' -Because "$relative must keep the compatibility fallback"
        }
    }
}
