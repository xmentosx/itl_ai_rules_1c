BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $scaffold = Join-Path $script:ForkRoot 'content/skills/1c-metadata-manage/tools/1c-erf-scaffold/scripts/init.ps1'
    $validator = Join-Path $script:ForkRoot 'content/skills/1c-metadata-manage/tools/1c-epf-validate/scripts/epf-validate.ps1'
}

Describe 'On-demand routing retains managed ITL boundaries' -Tag 'Fast' {
    It 'enters memory without loading the non-memory 1C router and preserves isolated routing' {
        $memory = Get-Content (Join-Path $script:ForkRoot 'content/rules/project-memory.md') -Raw -Encoding UTF8
        $policy = Get-Content (Join-Path $script:ForkRoot 'content/rules/tool-policy.md') -Raw -Encoding UTF8
        $memory | Should -Match 'no `mcp-policy.md`, `mcp-1c-tools` router or template skill is needed'
        $memory | Should -Match 'Even an exposed tool.*not a verified project-isolated destination'
        $memory | Should -Match 'required.*no qualified binding.*stop only the dependent memory operation'
        foreach ($value in @('auto','off','required')) { $policy | Should -Match ([regex]::Escape('`' + $value + '`')) }
        $policy | Should -Match 'Memory.*uses `project-memory.md`'
    }

    It 'moves the catalog without losing logic validation, ROCTUP or the distinct managed UI route' {
        $router = Get-Content (Join-Path $script:ForkRoot 'content/skills/mcp-1c-tools/SKILL.md') -Raw -Encoding UTF8
        $catalog = Get-Content (Join-Path $script:ForkRoot 'content/skills/mcp-1c-tools/docs/server-catalog.md') -Raw -Encoding UTF8
        $router | Should -Match 'server-catalog.md.*only to identify an unfamiliar server'
        $router | Should -Match 'managed Vanessa UI or distinct qa'
        $catalog | Should -Match 'preferred `check_1c_logic`.*`check_1c_code` fallback'
        $catalog | Should -Match '`itl-roctup-data`.*Managed branch data through ROCTUP'
        $catalog | Should -Match 'standalone test manager/client; distinct from managed Vanessa UI'
    }

    It 'keeps the preview refusal before mutation reachable from the compact metadata entrypoint' {
        $skill = Get-Content (Join-Path $script:ForkRoot 'content/skills/1c-metadata-manage/SKILL.md') -Raw -Encoding UTF8
        $skill | Should -Match 'Before using the wrapper, read.*edit-preview.md'
        $skill | Should -Match 'ITL managed worktree, rollback preview refuses before mutation'
        $skill | Should -Match 'preview-only request never becomes an apply automatically'
        $skill | Should -Match 'itl-managed-form-context.md'
    }
}

Describe 'External report common forms' -Tag 'Fast' {
    It 'preserves the default scaffold and accepts opt-in BSP references without hiding missing local forms' {
        $unicodeName = -join @([char]0x041e,[char]0x0442,[char]0x0447,[char]0x0435,[char]0x0442)
        $source = Join-Path $TestDrive ('Source with spaces ' + $unicodeName)
        $plain = Invoke-WindowsPowerShellFile $scaffold @('-Name','Plain','-SrcDir',$source)
        $plain.ExitCode | Should -Be 0 -Because $plain.Output
        [xml]$plainXml = Get-Content (Join-Path $source 'Plain.xml') -Raw -Encoding UTF8
        [string]$plainXml.MetaDataObject.ExternalReport.Properties.DefaultForm | Should -Be ''

        $bsp = Invoke-WindowsPowerShellFile $scaffold @('-Name',$unicodeName,'-SrcDir',$source,'-BspForms','-WithSKD')
        $bsp.ExitCode | Should -Be 0 -Because $bsp.Output
        $path = Join-Path $source ($unicodeName + '.xml')
        [xml]$xml = Get-Content $path -Raw -Encoding UTF8
        $properties = $xml.MetaDataObject.ExternalReport.Properties
        foreach ($field in @('DefaultForm','DefaultSettingsForm','DefaultVariantForm')) {
            [string]$properties.$field | Should -Match '^CommonForm\.'
        }
        [string]$properties.MainDataCompositionSchema | Should -Not -BeNullOrEmpty
        $valid = Invoke-WindowsPowerShellFile $validator @('-ObjectPath',$path,'-Detailed')
        $valid.ExitCode | Should -Be 0 -Because $valid.Output
        $valid.Output | Should -Match '0 errors, 0 warnings'

        $properties.DefaultForm = 'ExternalReport.' + $unicodeName + '.Form.Missing'
        $xml.Save($path)
        $invalid = Invoke-WindowsPowerShellFile $validator @('-ObjectPath',$path)
        $invalid.ExitCode | Should -Not -Be 0
        $invalid.Output | Should -Match 'no such Form in ChildObjects'
    }
}
