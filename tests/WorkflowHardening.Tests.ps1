BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")

    function Write-Utf8Fixture([string]$Path, [string]$Text) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
        [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($true))
    }

    function New-BaseConfigFixture([string]$Root) {
        $configUuid = "11111111-1111-1111-1111-111111111111"
        $languageUuid = "22222222-2222-2222-2222-222222222222"
        Write-Utf8Fixture (Join-Path $Root "Configuration.xml") @"
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses"><Configuration uuid="$configUuid"><Properties><Name>TestConfig</Name><CompatibilityMode>Version8_3_24</CompatibilityMode><InterfaceCompatibilityMode>TaxiEnableVersion8_2</InterfaceCompatibilityMode></Properties></Configuration></MetaDataObject>
"@
        $russianName = -join ([char[]](0x420,0x443,0x441,0x441,0x43A,0x438,0x439))
        Write-Utf8Fixture (Join-Path (Join-Path $Root "Languages") ($russianName + ".xml")) @"
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses"><Language uuid="$languageUuid"><Properties><Name>Russian</Name></Properties></Language></MetaDataObject>
"@
    }

    function New-DocumentFixture([string]$Root) {
        $documentRoot = Join-Path $Root "Documents"
        Write-Utf8Fixture (Join-Path $Root "Configuration.xml") '<?xml version="1.0" encoding="UTF-8"?><MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" version="2.17"><Configuration uuid="11111111-1111-1111-1111-111111111111"/></MetaDataObject>'
        Write-Utf8Fixture (Join-Path $documentRoot "Order.xml") @'
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" version="2.17"><Document uuid="33333333-3333-3333-3333-333333333333"><Properties><Name>Order</Name><DefaultObjectForm/><MainDataCompositionSchema/></Properties><ChildObjects/></Document></MetaDataObject>
'@
        return (Join-Path $documentRoot "Order.xml")
    }
}

Describe "CFE and metadata hardening" -Tag "Fast" {
    It "requires a valid ConfigPath with grep-friendly diagnostics" {
        $scriptPath = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-cfe-manage\scripts\cfe-init.ps1"
        $root = New-ForkTestRoot
        try {
            $missing = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @("-Name", "Test", "-OutputDir", (Join-Path $root "cfe"))
            $missing.ExitCode | Should -Not -Be 0
            $missing.Output | Should -Match "CFE_CONFIG_PATH_REQUIRED"

            $invalid = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @("-Name", "Test", "-OutputDir", (Join-Path $root "cfe"), "-ConfigPath", (Join-Path $root "missing"))
            $invalid.ExitCode | Should -Not -Be 0
            $invalid.Output | Should -Match "CFE_BASE_CONFIG_INVALID"
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "creates a loadable adopted scaffold from the base dump" {
        $root = New-ForkTestRoot
        try {
            $base = Join-Path $root "cf"; New-BaseConfigFixture $base
            $cfe = Join-Path $root "cfe"
            $init = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-cfe-manage\scripts\cfe-init.ps1") -Arguments @("-Name", "Test", "-OutputDir", $cfe, "-ConfigPath", $base)
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $text = Get-Content -Raw -Encoding UTF8 (Join-Path $cfe "Configuration.xml")
            $text | Should -Match "<ObjectBelonging>Adopted</ObjectBelonging>"
            $languageFile = Get-ChildItem -LiteralPath (Join-Path $cfe "Languages") -File | Select-Object -First 1
            (Get-Content -Raw -Encoding UTF8 $languageFile.FullName) | Should -Match "22222222-2222-2222-2222-222222222222"
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "keeps form and template operations idempotent" {
        $root = New-ForkTestRoot
        try {
            $objectPath = New-DocumentFixture $root
            $formScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-form-scaffold\scripts\form-add.ps1"
            $firstForm = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm")
            $firstForm.ExitCode | Should -Be 0 -Because $firstForm.Output
            $secondForm = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm")
            $secondForm.ExitCode | Should -Be 0 -Because $secondForm.Output

            $templateScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-template-manage\scripts\add-template.ps1"
            $firstTemplate = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Order", "-TemplateName", "Print", "-TemplateType", "Text", "-SrcDir", (Join-Path $root "Documents"))
            $firstTemplate.ExitCode | Should -Be 0 -Because $firstTemplate.Output
            $secondTemplate = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Order", "-TemplateName", "Print", "-TemplateType", "Text", "-SrcDir", (Join-Path $root "Documents"))
            $secondTemplate.ExitCode | Should -Be 0 -Because $secondTemplate.Output

            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            @($object.SelectNodes("//md:ChildObjects/md:Form[text()='ObjectForm']", $ns)).Count | Should -Be 1
            @($object.SelectNodes("//md:ChildObjects/md:Template[text()='Print']", $ns)).Count | Should -Be 1
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "reports fatal extension structure failures with stable codes" {
        $root = New-ForkTestRoot
        try {
            $base = Join-Path $root "cf"; New-BaseConfigFixture $base
            $cfe = Join-Path $root "cfe"
            $initPath = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-cfe-manage\scripts\cfe-init.ps1"
            $validatePath = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-cfe-manage\scripts\cfe-validate.ps1"
            $init = Invoke-WindowsPowerShellFile -FilePath $initPath -Arguments @("-Name", "Test", "-OutputDir", $cfe, "-ConfigPath", $base)
            $init.ExitCode | Should -Be 0 -Because $init.Output
            $configurationPath = Join-Path $cfe "Configuration.xml"
            $original = Get-Content -Raw -Encoding UTF8 $configurationPath

            Write-Utf8Fixture $configurationPath ($original.Replace("<ObjectBelonging>Adopted</ObjectBelonging>", "<ObjectBelonging>Independent</ObjectBelonging>"))
            $belonging = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $belonging.ExitCode | Should -Not -Be 0
            $belonging.Output | Should -Match "CFE_OBJECT_BELONGING_INVALID"

            $languageMatch = [regex]::Match($original, '<Language>[^<]+</Language>')
            $languageMatch.Success | Should -BeTrue
            Write-Utf8Fixture $configurationPath ($original.Replace($languageMatch.Value, $languageMatch.Value + $languageMatch.Value))
            $duplicate = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $duplicate.ExitCode | Should -Not -Be 0
            $duplicate.Output | Should -Match "CFE_CHILD_OBJECT_DUPLICATE"

            Write-Utf8Fixture $configurationPath $original
            Get-ChildItem -LiteralPath (Join-Path $cfe "Languages") -File | Remove-Item -Force
            $missing = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $missing.ExitCode | Should -Not -Be 0
            $missing.Output | Should -Match "CFE_CHILD_OBJECT_TARGET_MISSING"

            Write-Utf8Fixture $configurationPath ($original.Substring(0, [Math]::Min(80, $original.Length)))
            $invalidXml = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $invalidXml.ExitCode | Should -Not -Be 0
            $invalidXml.Output | Should -Match "CFE_XML_INVALID"
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "detects a form UUID mismatch between the parent metadata and form file" {
        $root = New-ForkTestRoot
        try {
            $base = Join-Path $root "cf"; New-BaseConfigFixture $base
            $cfe = Join-Path $root "cfe"
            $initPath = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-cfe-manage\scripts\cfe-init.ps1"
            $validatePath = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-cfe-manage\scripts\cfe-validate.ps1"
            $init = Invoke-WindowsPowerShellFile -FilePath $initPath -Arguments @("-Name", "Test", "-OutputDir", $cfe, "-ConfigPath", $base)
            $init.ExitCode | Should -Be 0 -Because $init.Output

            $configurationPath = Join-Path $cfe "Configuration.xml"
            $configuration = Get-Content -Raw -Encoding UTF8 $configurationPath
            Write-Utf8Fixture $configurationPath ($configuration.Replace("</ChildObjects>", "<Document>Order</Document></ChildObjects>"))
            $objectPath = Join-Path $cfe "Documents\Order.xml"
            Write-Utf8Fixture $objectPath @'
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" version="2.17"><Document uuid="33333333-3333-3333-3333-333333333333"><Properties><Name>Order</Name><ObjectBelonging>Adopted</ObjectBelonging><ExtendedConfigurationObject>44444444-4444-4444-4444-444444444444</ExtendedConfigurationObject><DefaultObjectForm/><MainDataCompositionSchema/></Properties><ChildObjects/></Document></MetaDataObject>
'@
            $formPath = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-form-scaffold\scripts\form-add.ps1"
            $form = Invoke-WindowsPowerShellFile -FilePath $formPath -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm")
            $form.ExitCode | Should -Be 0 -Because $form.Output
            [xml]$objectXml = Get-Content -Raw -Encoding UTF8 $objectPath
            $objectNs = [System.Xml.XmlNamespaceManager]::new($objectXml.NameTable); $objectNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $objectXml.SelectSingleNode("//md:ChildObjects/md:Form[text()='ObjectForm']", $objectNs).SetAttribute("uuid", "55555555-5555-5555-5555-555555555555")
            $objectXml.Save($objectPath)
            $formMetaPath = Join-Path $cfe "Documents\Order\Forms\ObjectForm.xml"
            $formMeta = Get-Content -Raw -Encoding UTF8 $formMetaPath
            Write-Utf8Fixture $formMetaPath ([regex]::Replace($formMeta, '(<Form\s+uuid=")[^"]+', '${1}aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 1))

            $validation = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $validation.ExitCode | Should -Not -Be 0
            $validation.Output | Should -Match "CFE_CHILD_OBJECT_UUID_MISMATCH"
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "rejects generic form and template creation routes" {
        $metaEditPath = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-meta-edit\scripts\meta-edit.ps1"
        $metaEdit = Get-Content -Raw -Encoding UTF8 $metaEditPath
        $parameterBlock = (Get-Content -Encoding UTF8 $metaEditPath | Select-Object -First 30) -join "`n"
        $parameterBlock | Should -Not -Match '"add-form"'
        $parameterBlock | Should -Not -Match '"add-template"'
        $metaEdit | Should -Match "META_EDIT_SPECIALIZED_TOOL_REQUIRED"
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
            $text | Should -Match 'Do not read `VANESSA-TESTS-GUIDE.md`'
        }
        foreach ($file in $applyFiles) {
            $text = Get-Content -Raw -Encoding UTF8 $file.FullName
            $text | Should -Match "itl:apply-test-authoring"
            $text | Should -Match "test-report.md"
            $text | Should -Match 'Before the first actual `.feature` edit'
        }
    }
}
