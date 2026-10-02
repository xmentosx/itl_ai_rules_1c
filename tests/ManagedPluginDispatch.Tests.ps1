BeforeAll {
    $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\plugins\1c-rules\scripts\invoke-install.ps1')).Path
    $pluginPath = (Resolve-Path (Join-Path $PSScriptRoot '..\plugins\1c-rules\plugin.mjs')).Path
    $eventHarnessPath = Join-Path $PSScriptRoot 'plugin-event-harness.mjs'
}

Describe 'Managed ITL plugin dispatch' {
    It 'does not install or add a client merely because a standalone project opens' {
        $root = Join-Path $TestDrive ('Standalone проект ' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path (Join-Path $root 'src/cf') | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'src/cf/Configuration.xml') -Encoding UTF8 -Value '<Configuration />'
        $source = 'https://example.invalid/unpinned.git'

        $planText = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action ensure -Tool codex -ProjectRoot $root -Source $source -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($planText -join ' ')
        $plan = ($planText -join "`n") | ConvertFrom-Json
        $plan.action | Should -Be 'skip'
        $plan.reason | Should -Be 'explicit-install-required'
        $plan.source | Should -Be ''

        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action ensure -Tool codex -ProjectRoot $root -Source $source 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join ' ')
        Test-Path -LiteralPath (Join-Path $root '.ai-rules.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root '.codex') | Should -BeFalse

        Set-Content -LiteralPath (Join-Path $root '.ai-rules.json') -Encoding UTF8 -Value '{"tools":["cursor"]}'
        $addPlanText = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action add -Tool codex -ProjectRoot $root -Source $source -DryRun 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($addPlanText -join ' ')
        (($addPlanText -join "`n") | ConvertFrom-Json).action | Should -Be 'add'
    }

    It 'keeps session ensure read-only even with a separate URL source' {
        $root = Join-Path $TestDrive ('Проект с пробелом ' + [guid]::NewGuid().ToString('N'))
        $helperRoot = Join-Path $root '.agents\skills\1c-workflow\scripts'
        New-Item -ItemType Directory -Force -Path $helperRoot | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $root '.agent-1c') | Out-Null
        Set-Content -LiteralPath (Join-Path $root '.agent-1c\project.json') -Value '{}' -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $root '.agent-1c\dependency-lock.json') -Value ('{"dependencies":{"aiRules1c":{"commit":"' + ('a' * 40) + '"}}}') -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $helperRoot 'plugin-dispatch.json') -Value '{"protocolVersion":1,"owner":"itl-workflow"}' -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $helperRoot 'agent-1c.ps1') -Value 'param($Action,$Mode,$Client,$ProjectRoot); [IO.File]::WriteAllText((Join-Path $PSScriptRoot "called"), "$Action|$Mode|$Client|$ProjectRoot", [Text.UTF8Encoding]::new($false))' -Encoding UTF8

        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action ensure -Tool codex -ProjectRoot $root -Source 'https://example.invalid/unpinned.git' 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join ' ')
        ($output -join ' ') | Should -Match 'no session-time mutation'
        Test-Path -LiteralPath (Join-Path $helperRoot 'called') | Should -BeFalse

        $attachOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action init -Tool codex -ProjectRoot $root -Source 'https://example.invalid/unpinned.git' 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($attachOutput -join ' ')
        (Get-Content -LiteralPath (Join-Path $helperRoot 'called') -Raw -Encoding UTF8).Trim() | Should -Be "itl-switch-client|attach|codex|$root"
        $addOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action add -Tool codex -ProjectRoot $root -Source 'https://example.invalid/unpinned.git' 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($addOutput -join ' ')
        (Get-Content -LiteralPath (Join-Path $helperRoot 'called') -Raw -Encoding UTF8).Trim() | Should -Be "itl-switch-client|attach|codex|$root"
        $updateOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action update -Tool codex -ProjectRoot $root -Source 'https://example.invalid/unpinned.git' 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($updateOutput -join ' ')
        (Get-Content -LiteralPath (Join-Path $helperRoot 'called') -Raw -Encoding UTF8).Trim() | Should -Be "update-ai-rules|||$root"
    }

    It 'refuses a managed mutation when its pinned helper protocol is absent' {
        $root = Join-Path $TestDrive ('Старый проект ' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path (Join-Path $root '.agent-1c') | Out-Null
        Set-Content -LiteralPath (Join-Path $root '.agent-1c\project.json') -Value '{}' -Encoding UTF8
        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Action update -Tool codex -ProjectRoot $root 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join ' ') | Should -Match 'ITL_PLUGIN_PROTOCOL_UNAVAILABLE'
    }

    It 'propagates real session ensure failures and keeps successful OpenCode and Kilo events read-only' {
        $root = Join-Path $TestDrive ('Plugin события ' + [guid]::NewGuid().ToString('N'))
        $node = Get-Command node -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Source
        $output = & $node $eventHarnessPath $pluginPath $root 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join ' ')
        $proof = ($output -join "`n") | ConvertFrom-Json
        @($proof.hosts).Count | Should -Be 2
        foreach ($hostProof in $proof.hosts) {
            $hostProof.unrelatedEventPassed | Should -BeTrue
            $hostProof.standaloneReadOnlyPassed | Should -BeTrue
            $hostProof.managedReadOnlyPassed | Should -BeTrue
            $hostProof.unicodeDiagnosticPassed | Should -BeTrue
            $hostProof.failure.exitCode | Should -Be 1
            $hostProof.failure.code | Should -Be 'ONEC_RULES_ENSURE_FAILED'
            $hostProof.failure.diagnostic | Should -Match 'ITL_PLUGIN_PROTOCOL_UNAVAILABLE'
            $hostProof.failure.diagnostic | Should -Match '/itl-update-workflow'
        }
    }
}
