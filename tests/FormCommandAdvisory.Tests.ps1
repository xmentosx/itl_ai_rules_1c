BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
    $script:FormTestRoot = New-ForkTestRoot
    $script:FormValidator = Join-Path $script:ForkRoot "content/skills/1c-metadata-manage/tools/1c-form-validate/scripts/form-validate.ps1"

    function New-CommandFormFixture {
        param([string]$Commands, [string]$Events = "")
        $directory = Join-Path $script:FormTestRoot (([guid]::NewGuid().ToString('N')) + '/Форма с пробелом/Ext')
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $path = Join-Path $directory 'Form.xml'
        [IO.File]::WriteAllText($path, @"
<Form xmlns="http://v8.1c.ru/8.3/xcf/logform" version="2.17">
  <AutoCommandBar name="ПанельКоманд" id="-1" />
  <Commands>$Commands</Commands>
  $Events
</Form>
"@, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $directory 'Module.bsl'), "// Existing business source must remain byte-identical.`n", [Text.UTF8Encoding]::new($false))
        return $path
    }

    function Get-FormFixtureState {
        param([string]$Path)
        return @(Get-ChildItem -LiteralPath (Split-Path $Path) -File -Recurse | Sort-Object FullName | ForEach-Object {
            $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        })
    }
}

AfterAll {
    if ($script:FormTestRoot -and [IO.Path]::GetFullPath($script:FormTestRoot).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $script:FormTestRoot -Recurse -Force
    }
}

Describe "Unassigned form command actions" -Tag "Fast" {
    It "reports <Kind> Action without failure or source changes" -TestCases @(
        @{ Kind = 'absent'; Action = '' },
        @{ Kind = 'empty'; Action = '<Action />' },
        @{ Kind = 'whitespace'; Action = '<Action>  &#x9;&#xA; </Action>' }
    ) {
        param($Kind, $Action)
        $path = New-CommandFormFixture -Commands ('<Command name="КомандаБезДействия" id="1">' + $Action + '</Command>')
        $before = Get-FormFixtureState $path
        $result = Invoke-WindowsPowerShellFile -FilePath $script:FormValidator -Arguments @('-FormPath', $path)
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match '\[WARN\].*COMMAND_ACTION_UNASSIGNED.*КомандаБезДействия'
        $result.Output | Should -Match '0 errors, 1 warnings'
        $result.Output | Should -Match 'report to the user, do not create dummy handlers or bindings'
        $result.Output | Should -Not -Match '\[ERROR\]|Fix and re-run'
        (Get-FormFixtureState $path) | Should -Be $before
    }

    It "accepts a bound command without an unassigned-action diagnostic" {
        $path = New-CommandFormFixture -Commands '<Command name="Открыть" id="1"><Action>Открыть</Action></Command>'
        $result = Invoke-WindowsPowerShellFile -FilePath $script:FormValidator -Arguments @('-FormPath', $path)
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Not -Match 'COMMAND_ACTION_UNASSIGNED|\[WARN\]|\[ERROR\]'
    }

    It "keeps <Kind> structural errors blocking alongside advisory commands" -TestCases @(
        @{ Kind = 'duplicate command ID'; Commands = '<Command name="Вторая" id="1"><Action>Вторая</Action></Command>'; Events = ''; Error = 'Duplicate command id=1' },
        @{ Kind = 'empty event binding'; Commands = ''; Events = '<Events><Event name="OnOpen" /></Events>'; Error = 'empty handler name' },
        @{ Kind = 'invalid command callType'; Commands = '<Command name="Вторая" id="2"><Action callType="Invalid">Вторая</Action></Command>'; Events = '<BaseForm version="2.17" />'; Error = 'invalid callType' }
    ) {
        param($Kind, $Commands, $Events, $Error)
        $path = New-CommandFormFixture -Commands ('<Command name="БезДействия" id="1" />' + $Commands) -Events $Events
        $before = Get-FormFixtureState $path
        $result = Invoke-WindowsPowerShellFile -FilePath $script:FormValidator -Arguments @('-FormPath', $path)
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match ('\[ERROR\].*' + $Error)
        $result.Output | Should -Match '\[WARN\].*COMMAND_ACTION_UNASSIGNED'
        (Get-FormFixtureState $path) | Should -Be $before
    }

    It "does not let advisory commands exhaust MaxErrors before later structural checks" {
        $path = New-CommandFormFixture -Commands '<Command name="Первая" id="1" /><Command name="Вторая" id="2" /><Command name="Третья" id="3"><Action callType="Invalid">Третья</Action></Command>' -Events '<BaseForm version="2.17" />'
        $result = Invoke-WindowsPowerShellFile -FilePath $script:FormValidator -Arguments @('-FormPath', $path, '-MaxErrors', '1')
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'invalid callType'
        $result.Output | Should -Match '1 errors,'
        [regex]::Matches($result.Output, 'COMMAND_ACTION_UNASSIGNED').Count | Should -Be 2
    }

    It "continues to reject malformed XML" {
        $path = New-CommandFormFixture -Commands '<Command'
        $result = Invoke-WindowsPowerShellFile -FilePath $script:FormValidator -Arguments @('-FormPath', $path)
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match '\[ERROR\] XML parse error'
    }
}
