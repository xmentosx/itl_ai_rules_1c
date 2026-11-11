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

    It "keeps completion and repeated-obstacle routing model-neutral" {
        $root = (Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "AGENTS.md")) -replace '\s+', ' '
        $gates = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\verification-gates.md")
        $adaptation = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\model-adaptation.md")

        $root | Should -Match '## Completion and repeated obstacles Authorized work ends when the deliverable and every check its task path selects have run'
        $root | Should -Match 'A finished sub-item, a check you can run yourself or a tight context window \(hand off instead\) is not a stopping point'
        $root | Should -Match 'end earlier only at a `CONFUSION` fork, a confirmation-gated action or input only the user has'
        $root | Should -Match 'same obstacle survives two attempts without new evidence, change the route'
        $root | Should -Match 'rewording an attempt is not a new route'
        $gates | Should -Match 'a fragment checked as text is interim'
        $gates | Should -Match 'without the file tool, `syntaxcheck` on the complete saved module text'
        $adaptation | Should -Match 'completion and stopping points are shared'
        foreach ($profile in @("model-gpt6.md", "model-fable5.md", "model-sonnet5.md")) {
            $text = Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot "content\rules\$profile")
            $text | Should -Match ([regex]::Escape('AGENTS.md → Completion and repeated obstacles'))
            $text | Should -Not -Match 'Persist until met|End only when complete or blocked|Do not wrap up early'
        }
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
        $route | Should -Match 'defaults on after ready ITL setup'
        $route | Should -Match 'Explicit off/disabled persists'
        $route | Should -Match 'Missing prerequisites mean unavailable, not enabled'
        $route | Should -Match 'critical-action freshness'
        $route | Should -Match 'Seven destinations'
        $route | Should -Match 'local-project workspace \(main copy with its branch copies\), developer workplace, machine host'
        $route | Should -Match 'root `Scoped project memory` section replaces the separate standing query and the Memory line format below'
        $route | Should -Match 'partial or unavailable coverage is not absence'
        # The always-loaded core is conditional and keeps the provider boundary.
        $root=Get-Content -Raw -Encoding UTF8 (Join-Path $script:ForkRoot 'AGENTS.md')
        $root | Should -Match '## Scoped project memory'
        $root | Should -Match 'Applies only when the `memory_status` tool is available'
        $root | Should -Match 'Call `memory_status` once at session start and after a `contextChanged`'
        $root | Should -Match '`recall` the topic before designing a 1C change'
        $root | Should -Match 'never client, project or configuration data'
        $root | Should -Match 'Memory: recall N, saved N, updated N, retired N'
        $root | Should -Match '`templatesearch`\s+remains available for code templates'
        $root | Should -Match 'Do not turn on a new shared-memory\s+provider implicitly'
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

    It "routes every review entry point to one review-criteria owner without uncommitted-only scope" {
        $read = { param($relative) Get-Content -LiteralPath (Join-Path $script:ForkRoot $relative) -Raw -Encoding UTF8 }
        $criteria = & $read 'content\rules\review-criteria.md'
        foreach ($section in @('## Scope', '## What to check', '## Verdict and confidence', '## Second opinion', '## Report', '## Actions by role', '## Evidence')) {
            $criteria | Should -Match ([regex]::Escape($section))
        }
        $criteria | Should -Match ([regex]::Escape('(`@{u}`) is never a base'))
        $criteria | Should -Match ([regex]::Escape('A separately requested review: report only'))
        foreach ($relative in @(
            'content\rules\verification-delivery.md',
            'content\rules\subagent-pipeline.md',
            'content\rules\sdd-integrations.md',
            'content\rules\tooling-playbooks.md',
            'content\rules\subagents.md',
            'content\agents\code-reviewer.md',
            'content\agents\arch-reviewer.md'
        )) {
            $text = & $read $relative
            $text | Should -Match 'review-criteria\.md' -Because "$relative must route review content to the single owner"
            $text | Should -Not -Match '(?i)uncommitted (diff|architectural changes)' -Because "$relative must not limit review scope to the uncommitted diff"
        }
        $reviewer = & $read 'content\agents\code-reviewer.md'
        $reviewer | Should -Not -Match '## Confidence Scoring|## Output Format|## Cross-provider Review'
        $pipeline = & $read 'content\rules\subagent-pipeline.md'
        $pipeline | Should -Not -Match 'BSL LS warnings via'
        $playbooks = & $read 'content\rules\tooling-playbooks.md'
        foreach ($relative in @('content\rules\subagent-pipeline.md', 'content\rules\sdd-integrations.md', 'content\agents\planner.md')) {
            (& $read $relative) | Should -Match ([regex]::Escape('Writing New Code → Plan check'))
        }
        $playbooks | Should -Match ([regex]::Escape('**Plan check.**'))
        (& $read 'tools\validate-rules.ps1') | Should -Match ([regex]::Escape("'content/rules/review-criteria.md'"))
    }

    It "has the parent fix local minor findings in task lines and list the rest with a reason" {
        $read = { param($relative) Get-Content -LiteralPath (Join-Path $script:ForkRoot $relative) -Raw -Encoding UTF8 }
        $criteria = & $read 'content\rules\review-criteria.md'
        $actions = ($criteria -split '## Actions by role', 2)[1]
        $actions | Should -Match ([regex]::Escape('each `minor` in lines the current task added or changed when the fix is local'))
        $actions | Should -Match ([regex]::Escape('Recheck the affected scope after any fix'))
        foreach ($reason in @('`outside the task`', '`needs checks outside the task`', '`judgement call — user decides`')) {
            $actions | Should -Match ([regex]::Escape($reason))
        }
        $actions | Should -Not -Match ([regex]::Escape('list `minor`.'))
        foreach ($relative in @('content\rules\verification-delivery.md', 'content\rules\subagent-pipeline.md', 'content\rules\subagent-core.md')) {
            $text = & $read $relative
            $text | Should -Match ([regex]::Escape('review-criteria.md → Actions by role')) -Because "$relative must route minor handling to the owner"
            $text | Should -Not -Match '(?i)minor (issues are |\()informational|report minor ones' -Because "$relative must not keep minor findings report-only"
        }
    }

    It "accepts a project-recorded pass as Gate 1 evidence, bounds Gates 2-3 on a large scope and honours a project range choice" {
        $read = { param($relative) Get-Content -LiteralPath (Join-Path $script:ForkRoot $relative) -Raw -Encoding UTF8 }
        $criteria = (& $read 'content\rules\review-criteria.md') -replace '\s+', ' '
        $scope = (($criteria -split '## Scope', 2)[1] -split '## What to check', 2)[0]
        $scope | Should -Match ([regex]::Escape('When it asks to choose a range, relay its question and options to the user and rerun with the choice; never choose for them.'))
        $evidence = ($criteria -split '## Evidence', 2)[1]
        $evidence | Should -Match ([regex]::Escape('The author''s report is the subject of the review, not evidence'))
        $evidence | Should -Match ([regex]::Escape('A pass the project recorded and bound to the current content is evidence, not the author''s report.'))
        $evidence | Should -Match ([regex]::Escape('recommend that check in the development chat rather than starting it here'))
        $evidence | Should -Match ([regex]::Escape('run them by text on changed procedures chosen by risk'))
        $evidence | Should -Match ([regex]::Escape('report the rest with a count as «not checked automatically»'))
        $root = (& $read 'AGENTS.md') -replace '\s+', ' '
        $root | Should -Match ([regex]::Escape('ITL MCP hosts cannot validate by path (`syntaxcheck_file`, `files`); pass text.'))
    }
}
