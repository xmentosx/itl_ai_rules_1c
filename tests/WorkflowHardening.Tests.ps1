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

    It "records triage without inventing runtime state and preserves honest final evidence" {
        $rule = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\development-process.md")
        $rule | Should -Match 'record `executionPath=quick-fix\|full-cycle` and'
        $rule | Should -Match 'do not invent runtime state'
        $rule | Should -Not -Match 'mechanical gate'
        $rule | Should -Match "pre-change failing run is useful only when it is cheap"
        $rule | Should -Match "never require two complete executable gates"
        $rule | Should -Match 'explicit skipped/partial evidence'
        $rule | Should -Match 'verificationPolicy=block'
    }

    It "bounds managed-form context checks and coordinates repeated runtime defects" {
        $architecture = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\dev-standards-architecture.md")
        $debugging = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\systematic-debugging.md")
        $fixer = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\agents\error-fixer.md")
        $subagents = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\subagents.md")

        $architecture | Should -Match 'Managed-form boundary contract'
        $architecture | Should -Match 'bsl_scope_members'
        $architecture | Should -Match 'client code obtains predefined values'
        $architecture | Should -Match 'not the server-only'
        $architecture | Should -Match 'parameters and return values can cross it'
        $architecture | Should -Match 'creates no completion pass'
        $debugging | Should -Match 'Defect-class scope check'
        $debugging | Should -Match 'A second confirmed occurrence.*ends per-symptom patching'
        $debugging | Should -Match 'Repetition alone selects neither OpenSpec nor a new abstraction'
        $fixer | Should -Match 'without a partial patch'
        $fixer | Should -Not -Match 'Compilation directive \| Add proper'
        $subagents | Should -Match 'One confirmed class has one mutating owner'
        $subagents | Should -Match 'repetition alone selects neither `full-cycle`, OpenSpec, nor an abstraction'
    }
}

Describe "Phase-specific OpenSpec overlays" -Tag "Fast" {
    It "installs test design and authoring contracts in every supported client" {
        $proposeFiles = Get-ChildItem -LiteralPath (Join-Path $script:ForkRoot "content\openspec-bundle") -Recurse -File | Where-Object { $_.Name -match 'propose' -or $_.Directory.Name -eq 'openspec-propose' }
        $applyFiles = Get-ChildItem -LiteralPath (Join-Path $script:ForkRoot "content\openspec-bundle") -Recurse -File | Where-Object { $_.Name -match 'apply' -or $_.Directory.Name -eq 'openspec-apply-change' }
        @($proposeFiles).Count | Should -BeGreaterThan 0
        @($applyFiles).Count | Should -Be 9
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

    It "loads the full subagent pipeline only for delegated OpenSpec apply" {
        $applyFiles = @(Get-ChildItem -LiteralPath (Join-Path $script:ForkRoot "content\openspec-bundle") -Recurse -File | Where-Object {
            $_.Name -match 'apply' -or $_.Directory.Name -eq 'openspec-apply-change'
        })
        $applyFiles.Count | Should -Be 9
        foreach ($file in $applyFiles) {
            $text = Get-Content -Raw -Encoding UTF8 $file.FullName
            $text | Should -Match '<!-- itl:conditional-apply-routing -->'
            $text | Should -Match 'Choose the execution route and implement tasks'
            $text | Should -Match 'absence of an earlier delegation request does not select direct'
            $text | Should -Match 'If delegation is chosen, load `content/rules/subagent-pipeline\.md`'
            $text | Should -Match 'If implementation was direct, run the compact structural comparison'
            $text | Should -Match 'load `subagent-pipeline\.md` only after implementation delegation is chosen'
            $text | Should -Not -Match 'Before the first edit, load `content/rules/subagent-pipeline\.md`'
            $text | Should -Not -Match 'Either way.*pipeline Stage 4a'
        }

        $integrationRule = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'content\rules\sdd-integrations.md')
        $integrationRule | Should -Match 'Apply execution route and spec compliance'
        $integrationRule | Should -Match 'new public procedure names, parameter types, and return types match'
        $integrationRule | Should -Match 'edited-object UUIDs were preserved'
        $integrationRule | Should -Match 'module headers are present on new public procedures'
    }
}
