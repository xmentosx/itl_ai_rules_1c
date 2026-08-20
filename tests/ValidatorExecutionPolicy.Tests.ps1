BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "Code Checker latency policy" -Tag "Fast" {
    BeforeAll {
        $script:Gates = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/verification-gates.md")
        $script:Catalog = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/skills/mcp-1c-tools/docs/1c-code-check-mcp.md")
        $script:Policy = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content/rules/verification-policy.md")
    }

    It "defers AI validators to one coherent closing snapshot" {
        $script:Gates | Should -Match ([regex]::Escape('MUST NOT call `check_1c_code` or `review_1c_code` after intermediate edits'))
        $script:Gates | Should -Match ([regex]::Escape('One call covers one unit'))
        $script:Catalog | Should -Match ([regex]::Escape('call `check_1c_code` once after implementation'))
        $script:Catalog | Should -Match ([regex]::Escape('call `review_1c_code` once only after logic validation passes'))
    }

    It "forbids ineffective same-server parallel batches" {
        $script:Gates | Should -Match ([regex]::Escape('do not send multiple calls to the same Code Checker server via `Promise.all`'))
        $script:Catalog | Should -Match ([regex]::Escape('Do not send same-server validator calls through `Promise.all`'))
    }

    It "reuses embedded direct syntax evidence without weakening Gate 1" {
        $script:Policy | Should -Match ([regex]::Escape('Clean Gate 1 syntax evidence is mandatory'))
        $script:Gates | Should -Match ([regex]::Escape('Do not also call `syntaxcheck` / `syntaxcheck_file` on that unchanged unit'))
        $script:Gates | Should -Match ([regex]::Escape('the `check_1c_code` result lacks a successful explicit syntax section'))
        $script:Catalog | Should -Match ([regex]::Escape('Use standalone syntax validation when Code Checker is prompt-only'))
    }
}
