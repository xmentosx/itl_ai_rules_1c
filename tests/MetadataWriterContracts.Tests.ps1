BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $script:WriterTempRoot = $null
    $script:WriterRoot = if ($env:ITL_METADATA_WRITER_TEST_ROOT) {
        [IO.Path]::GetFullPath($env:ITL_METADATA_WRITER_TEST_ROOT)
    } else {
        $script:WriterTempRoot = New-ForkTestRoot
        Join-Path $script:WriterTempRoot 'Метаданные с пробелом'
    }
    New-Item -ItemType Directory -Force -Path $script:WriterRoot | Out-Null
    $script:Tools = Join-Path $script:ForkRoot 'content/skills/1c-metadata-manage/tools'
    $script:Utf8 = [Text.UTF8Encoding]::new($false)

    function Write-WriterFixture([string]$Path, [string]$Text) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
        [IO.File]::WriteAllText($Path, $Text, $script:Utf8)
    }

    function New-CompiledWriterFixture([string]$Runtime, [string]$Case, [bool]$Aliases) {
        $root = Join-Path $script:WriterRoot "$Runtime $Case"
        $json = Join-Path $root 'Форма.json'
        $form = Join-Path $root 'Ext/Form.xml'
        $definition = [ordered]@{
            title = 'Проверка порядка'
            elements = @([ordered]@{
                button = 'Выполнить'; type = 'usual'; visible = $false; enabled = $false
                representation = $(if ($Aliases) { 'TextPicture' } else { 'PictureAndText' })
                defaultButton = $true; command = 'Выполнить'; picture = 'StdPicture.Execute'; title = 'Выполнить'
                locationInCommandBar = 'InCommandBar'; extendedTooltip = 'Подсказка'
            })
            commands = @([ordered]@{
                name = 'Выполнить'; title = 'Выполнить'; shortcut = 'F5'; picture = 'StdPicture.Execute'
                action = 'Выполнить'; representation = $(if ($Aliases) { 'PictureAndText' } else { 'TextPicture' })
            })
        }
        Write-WriterFixture $json ($definition | ConvertTo-Json -Depth 8)
        Write-WriterFixture (Join-Path $root 'Ext/Module.bsl') "&НаКлиенте`nПроцедура Выполнить(Команда)`nКонецПроцедуры`n"
        $scriptPath = Join-Path $script:Tools "1c-form-compile/scripts/form-compile.$Runtime"
        $arguments = @('-JsonPath', $json, '-OutputPath', $form)
        $compiled = if ($Runtime -eq 'ps1') {
            Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments $arguments
        } else { Invoke-TestNativeCommand -FilePath 'python' -Arguments (@('-B', $scriptPath) + $arguments) }
        $compiled.ExitCode | Should -Be 0 -Because $compiled.Output
        $validated = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:Tools '1c-form-validate/scripts/form-validate.ps1') -Arguments @('-FormPath', $form)
        [xml]$xml = [IO.File]::ReadAllText($form)
        [pscustomobject]@{ Root = $root; Form = $form; Xml = $xml; Validation = $validated }
    }

    function Get-WriterChildOrder($Node, [string[]]$Names) {
        @($Node.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.LocalName -in $Names } | ForEach-Object { $_.LocalName }) -join ','
    }
}

AfterAll {
    if ($script:WriterTempRoot -and [IO.Path]::GetFullPath($script:WriterTempRoot).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $script:WriterTempRoot -Recurse -Force
    }
}

Describe 'Metadata writer output contracts' -Tag 'Fast', 'MetadataWriters' {
    It 'propagates the real configuration validator failure and completes the same edit after repair' {
        $root = Join-Path $script:WriterRoot 'Конфигурация проверка'
        $config = Join-Path $root 'Configuration.xml'
        if (Test-Path -LiteralPath $config) { Remove-Item -LiteralPath $config }
        $init = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:Tools '1c-cf-manage/scripts/cf-init.ps1') -Arguments @('-Name', 'Проверка', '-OutputDir', $root)
        $init.ExitCode | Should -Be 0 -Because $init.Output
        $editor = Join-Path $script:Tools '1c-cf-manage/scripts/cf-edit.ps1'
        $invalid = Invoke-WindowsPowerShellFile -FilePath $editor -Arguments @('-ConfigPath', $config, '-Operation', 'modify-property', '-Value', 'Name=')
        $invalid.Output | Should -Match 'Running cf-validate'
        $invalid.Output | Should -Match 'Name is missing or empty'
        $invalid.ExitCode | Should -Be 1 -Because $invalid.Output
        ([xml][IO.File]::ReadAllText($config)).MetaDataObject.Configuration.Properties.Name | Should -BeNullOrEmpty
        $repaired = Invoke-WindowsPowerShellFile -FilePath $editor -Arguments @('-ConfigPath', $config, '-Operation', 'modify-property', '-Value', 'Name=Проверка')
        $repaired.ExitCode | Should -Be 0 -Because $repaired.Output
        $repaired.Output | Should -Match 'Validation OK'
        $explicitSkip = Invoke-WindowsPowerShellFile -FilePath $editor -Arguments @('-ConfigPath', $config, '-Operation', 'modify-property', '-Value', 'Name=', '-NoValidate')
        $explicitSkip.ExitCode | Should -Be 0 -Because $explicitSkip.Output
        $explicitSkip.Output | Should -Not -Match 'Running cf-validate'
    }

    It 'compiles <Runtime> representation aliases to values accepted by the real validator' -ForEach @(@{ Runtime = 'ps1' }, @{ Runtime = 'py' }) {
        $fixture = New-CompiledWriterFixture -Runtime $Runtime -Case 'Алиасы' -Aliases $true
        $fixture.Validation.ExitCode | Should -Be 0 -Because $fixture.Validation.Output
        $button = $fixture.Xml.SelectSingleNode("//*[local-name()='Button' and @name='Выполнить']")
        $command = $fixture.Xml.SelectSingleNode("//*[local-name()='Command' and @name='Выполнить']")
        $button.Representation | Should -BeExactly 'PictureAndText'
        $command.Representation | Should -BeExactly 'TextPicture'
    }

    It 'preserves <Runtime> canonical button and command property order when creating a form' -ForEach @(@{ Runtime = 'ps1' }, @{ Runtime = 'py' }) {
        $fixture = New-CompiledWriterFixture -Runtime $Runtime -Case 'Порядок' -Aliases $false
        $fixture.Validation.ExitCode | Should -Be 0 -Because $fixture.Validation.Output
        $button = $fixture.Xml.SelectSingleNode("//*[local-name()='Button' and @name='Выполнить']")
        $command = $fixture.Xml.SelectSingleNode("//*[local-name()='Command' and @name='Выполнить']")
        $buttonOrder = @('Type', 'Visible', 'Representation', 'DefaultButton', 'Enabled', 'CommandName', 'Picture', 'Title', 'LocationInCommandBar')
        (Get-WriterChildOrder $button $buttonOrder) | Should -BeExactly ($buttonOrder -join ',')
        (Get-WriterChildOrder $command @('Title', 'Shortcut', 'Picture', 'Action', 'Representation')) | Should -BeExactly 'Title,Shortcut,Picture,Action,Representation'
        $button.CommandName | Should -BeExactly 'Form.Command.Выполнить'
        $button.ExtendedTooltip | Should -Not -BeNullOrEmpty
        $command.Action | Should -BeExactly 'Выполнить'
    }

    It 'keeps invalid representation blocking alongside an advisory unassigned Action' {
        $form = Join-Path $script:WriterRoot 'Неверное перечисление/Ext/Form.xml'
        Write-WriterFixture $form '<Form xmlns="http://v8.1c.ru/8.3/xcf/logform" version="2.17"><AutoCommandBar name="Панель" id="-1"/><Commands><Command name="БезДействия" id="1"/><Command name="Неверная" id="2"><Action>Выполнить</Action><Representation>PictureAndText</Representation></Command></Commands></Form>'
        $before = (Get-FileHash -LiteralPath $form).Hash
        $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:Tools '1c-form-validate/scripts/form-validate.ps1') -Arguments @('-FormPath', $form, '-MaxErrors', '1')
        $result.ExitCode | Should -Be 1 -Because $result.Output
        $result.Output | Should -Match 'COMMAND_ACTION_UNASSIGNED'
        $result.Output | Should -Match '\[ERROR\] 15\..*Representation'
        (Get-FileHash -LiteralPath $form).Hash | Should -BeExactly $before
    }
}
