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
            "### Coding Standards",
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

    It "mechanically classifies quick fixes and preserves honest final evidence" {
        $rule = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\development-process.md")
        $rule | Should -Match 'mechanical gate'
        $rule | Should -Match "pre-change failing run is useful only when it is cheap"
        $rule | Should -Match "never require two complete executable gates"
        $rule | Should -Match 'explicit skipped/partial evidence'
        $rule | Should -Match 'verificationPolicy=block'
    }
}

Describe "Phase-specific OpenSpec overlays" -Tag "Fast" {
    It "installs test design and authoring contracts in every supported client" {
        $proposeFiles = Get-ChildItem -LiteralPath (Join-Path $script:ForkRoot "content\openspec-bundle") -Recurse -File | Where-Object { $_.Name -match 'propose' -or $_.Directory.Name -eq 'openspec-propose' }
        $applyFiles = Get-ChildItem -LiteralPath (Join-Path $script:ForkRoot "content\openspec-bundle") -Recurse -File | Where-Object { $_.Name -match 'apply' -or $_.Directory.Name -eq 'openspec-apply-change' }
        @($proposeFiles).Count | Should -BeGreaterThan 0
        @($applyFiles).Count | Should -BeGreaterThan 0
        foreach ($file in $proposeFiles) {
            $text = Get-Content -Raw -Encoding UTF8 $file.FullName
            $text | Should -Match "itl:propose-test-design"
            $text | Should -Match "test-plan.md"
            $text | Should -Match 'ITL_VANESSA_TESTING=off'
            $text | Should -Match 'does not create or edit executable tests'
        }
        foreach ($file in $applyFiles) {
            $text = Get-Content -Raw -Encoding UTF8 $file.FullName
            $text | Should -Match "itl:apply-test-authoring"
            $text | Should -Match 'fresh `/itl-check`'
            $text | Should -Match 'partial evidence'
        }
    }
}
