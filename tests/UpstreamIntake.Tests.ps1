BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    . (Join-Path $script:ForkRoot 'scripts/full-check-contract.ps1')
    $script:IntakeRoot = Join-Path (New-ForkTestRoot) 'Upstream Кириллица с пробелом'
    New-Item -ItemType Directory -Path $script:IntakeRoot -Force | Out-Null
    $script:Tools = Join-Path $script:ForkRoot 'content/skills/1c-metadata-manage/tools'
}

AfterAll {
    if ($script:IntakeRoot) {
        $parent = Split-Path -Parent $script:IntakeRoot
        if ([IO.Path]::GetFullPath($parent).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $parent -Recurse -Force
        }
    }
}

Describe 'Upstream intake preserves ITL execution and metadata contracts' -Tag 'Fast' {
    It 'includes the extension borrow regression in the actual Full catalog' {
        $stage = @(Get-ForkFullStageCatalog | Where-Object name -eq 'cfe-borrow')
        $stage.Count | Should -Be 1
        $stage[0].runtime | Should -BeExactly 'powershell'
        $stage[0].path | Should -BeExactly 'tools/tests/cfe-borrow-regression.ps1'
        (Test-Path -LiteralPath (Join-Path $script:ForkRoot $stage[0].path)) | Should -BeTrue
        @(Get-ForkRequiredFullStageNames) | Should -Contain 'cfe-borrow'
    }

    It 'accepts the File-safe Dynamic value <Value> while refusing a managed owner bypass' -ForEach @(@{Value='auto'}, @{Value='disable'}) {
        $root = Join-Path $script:IntakeRoot "Dynamic $Value"
        New-Item -ItemType Directory -Force -Path (Join-Path $root '.agent-1c') | Out-Null
        [IO.File]::WriteAllText((Join-Path $root '.agent-1c/project.json'), '{}', [Text.UTF8Encoding]::new($false))
        Push-Location -LiteralPath $root
        try {
            $run = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:Tools '1c-db-ops/scripts/db-update.ps1') -Arguments @('-Dynamic', $Value)
        } finally { Pop-Location }
        $run.ExitCode | Should -Not -Be 0
        $run.Output | Should -Match 'ITL_LIFECYCLE_HELPER_REQUIRED'
        $run.Output | Should -Not -Match 'ValidateSet|ParameterBindingValidationException'
    }

    It 'compiles the new input events and recognized scalar keys with <Runtime>' -ForEach @(@{Runtime='ps1'}, @{Runtime='py'}) {
        $root = Join-Path $script:IntakeRoot "Events $Runtime"
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        $definition = [ordered]@{
            elements = @([ordered]@{
                input = 'Поле'; markNegatives = $true; choiceListHeight = 8
                events = [ordered]@{Tuning='Регулировать'; Opening='Открыть'; StartListChoice='Выбрать'}
            })
        }
        $json = Join-Path $root 'Форма.json'
        $form = Join-Path $root 'Form.xml'
        [IO.File]::WriteAllText($json, ($definition | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        $compiler = Join-Path $script:Tools "1c-form-compile/scripts/form-compile.$Runtime"
        $arguments = @('-JsonPath', $json, '-OutputPath', $form)
        $run = if ($Runtime -eq 'ps1') {
            Invoke-WindowsPowerShellFile -FilePath $compiler -Arguments $arguments
        } else { Invoke-TestNativeCommand -FilePath 'python' -Arguments (@('-B', $compiler) + $arguments) }
        $run.ExitCode | Should -Be 0 -Because $run.Output
        $run.Output | Should -Not -Match 'unknown key|unknown event'
        [xml]$xml = [IO.File]::ReadAllText($form)
        foreach ($event in @('Tuning', 'Opening', 'StartListChoice')) {
            $xml.SelectSingleNode("//*[local-name()='Event' and @name='$event']") | Should -Not -BeNullOrEmpty
        }
        $xml.SelectSingleNode("//*[local-name()='MarkNegatives']").InnerText | Should -BeExactly 'true'
        $xml.SelectSingleNode("//*[local-name()='ChoiceListHeight']").InnerText | Should -BeExactly '8'
    }
}
