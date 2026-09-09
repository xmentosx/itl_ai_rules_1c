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
}
