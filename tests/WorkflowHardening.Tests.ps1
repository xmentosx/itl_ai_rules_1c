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

    function New-ReportFixture([string]$Root) {
        $reportRoot = Join-Path $Root "Reports"
        Write-Utf8Fixture (Join-Path $Root "Configuration.xml") '<?xml version="1.0" encoding="UTF-8"?><MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" version="2.17"><Configuration uuid="11111111-1111-1111-1111-111111111111"/></MetaDataObject>'
        Write-Utf8Fixture (Join-Path $reportRoot "Sales.xml") @'
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" version="2.17"><Report uuid="33333333-3333-3333-3333-333333333333"><Properties><Name>Sales</Name><DefaultForm/><MainDataCompositionSchema/></Properties><ChildObjects/></Report></MetaDataObject>
'@
        return (Join-Path $reportRoot "Sales.xml")
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

    It "updates explicit form metadata while preserving authored form content and normalizing legacy references" {
        $root = New-ForkTestRoot
        try {
            $objectPath = New-DocumentFixture $root
            $formScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-form-scaffold\scripts\form-add.ps1"
            $created = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm")
            $created.ExitCode | Should -Be 0 -Because $created.Output

            $formMetaPath = Join-Path $root "Documents\Order\Forms\ObjectForm.xml"
            $formXmlPath = Join-Path $root "Documents\Order\Forms\ObjectForm\Ext\Form.xml"
            $modulePath = Join-Path $root "Documents\Order\Forms\ObjectForm\Ext\Form\Module.bsl"
            [System.IO.File]::AppendAllText($formXmlPath, "`r`n<!-- authored -->", [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($modulePath, "&НаКлиенте`r`nПроцедура Авторская()`r`nКонецПроцедуры", [System.Text.UTF8Encoding]::new($true))
            $formHash = (Get-FileHash -LiteralPath $formXmlPath -Algorithm SHA256).Hash
            $moduleHash = (Get-FileHash -LiteralPath $modulePath -Algorithm SHA256).Hash

            [xml]$formMeta = Get-Content -Raw -Encoding UTF8 $formMetaPath
            $formUuid = $formMeta.DocumentElement.FirstChild.GetAttribute("uuid")
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $object.SelectSingleNode("//md:ChildObjects/md:Form[text()='ObjectForm']", $ns).SetAttribute("uuid", $formUuid)
            $object.Save($objectPath)

            $updated = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm", "-Synonym", "Updated form", "-SetDefault")
            $updated.ExitCode | Should -Be 0 -Because $updated.Output
            (Get-FileHash -LiteralPath $formXmlPath -Algorithm SHA256).Hash | Should -Be $formHash
            (Get-FileHash -LiteralPath $modulePath -Algorithm SHA256).Hash | Should -Be $moduleHash

            [xml]$updatedObject = Get-Content -Raw -Encoding UTF8 $objectPath
            $updatedNs = [System.Xml.XmlNamespaceManager]::new($updatedObject.NameTable); $updatedNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $reference = $updatedObject.SelectSingleNode("//md:ChildObjects/md:Form[text()='ObjectForm']", $updatedNs)
            $reference.Attributes.Count | Should -Be 0
            $updatedObject.SelectSingleNode("//md:Document/md:Properties/md:DefaultObjectForm", $updatedNs).InnerText | Should -Be "Document.Order.Form.ObjectForm"
            (Get-Content -Raw -Encoding UTF8 $formMetaPath) | Should -Match "Updated form"

            $updatedObject.SelectSingleNode("//md:Document/md:Properties/md:DefaultObjectForm", $updatedNs).InnerText = "Document.Order.Form.OtherForm"
            $updatedObject.Save($objectPath)
            $conflict = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm", "-SetDefault")
            $conflict.ExitCode | Should -Not -Be 0
            $conflict.Output | Should -Match "FORM_PURPOSE_CONFLICT"
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "safely completes supported partial form states and rejects an unprovable UUID" {
        $root = New-ForkTestRoot
        try {
            $objectPath = New-DocumentFixture $root
            $formScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-form-scaffold\scripts\form-add.ps1"
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $childObjects = $object.SelectSingleNode("//md:ChildObjects", $ns)
            $short = $object.CreateElement("Form", "http://v8.1c.ru/8.3/MDClasses"); $short.InnerText = "RegisteredOnly"; $childObjects.AppendChild($short) | Out-Null
            $object.Save($objectPath)
            $registeredOnly = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "RegisteredOnly")
            $registeredOnly.ExitCode | Should -Be 0 -Because $registeredOnly.Output
            Test-Path (Join-Path $root "Documents\Order\Forms\RegisteredOnly\Ext\Form.xml") | Should -BeTrue

            $created = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "MetadataOnly")
            $created.ExitCode | Should -Be 0 -Because $created.Output
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $reference = $object.SelectSingleNode("//md:ChildObjects/md:Form[text()='MetadataOnly']", $ns)
            $reference.ParentNode.RemoveChild($reference) | Out-Null
            $object.Save($objectPath)
            Remove-Item -LiteralPath (Join-Path $root "Documents\Order\Forms\MetadataOnly") -Recurse -Force
            $metadataOnly = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "MetadataOnly")
            $metadataOnly.ExitCode | Should -Be 0 -Because $metadataOnly.Output

            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $unknown = $object.CreateElement("Form", "http://v8.1c.ru/8.3/MDClasses"); $unknown.InnerText = "UnknownUuid"; $unknown.SetAttribute("uuid", "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
            $object.SelectSingleNode("//md:ChildObjects", $ns).AppendChild($unknown) | Out-Null
            $object.Save($objectPath)
            $ambiguous = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "UnknownUuid")
            $ambiguous.ExitCode | Should -Not -Be 0
            $ambiguous.Output | Should -Match "CFE_CHILD_OBJECT_REFERENCE_AMBIGUOUS"
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "enforces template type while preserving content and applying explicit metadata changes" {
        $root = New-ForkTestRoot
        try {
            $reportPath = New-ReportFixture $root
            $templateScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-template-manage\scripts\add-template.ps1"
            $created = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Sales", "-TemplateName", "MainSchema", "-TemplateType", "DataCompositionSchema", "-SrcDir", (Join-Path $root "Reports"))
            $created.ExitCode | Should -Be 0 -Because $created.Output

            $contentPath = Join-Path $root "Reports\Sales\Templates\MainSchema\Ext\Template.xml"
            [System.IO.File]::AppendAllText($contentPath, "`r`n<!-- authored schema -->", [System.Text.UTF8Encoding]::new($false))
            $contentHash = (Get-FileHash -LiteralPath $contentPath -Algorithm SHA256).Hash
            $updated = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Sales", "-TemplateName", "MainSchema", "-TemplateType", "DataCompositionSchema", "-Synonym", "Updated schema", "-SetMainSKD", "-SrcDir", (Join-Path $root "Reports"))
            $updated.ExitCode | Should -Be 0 -Because $updated.Output
            (Get-FileHash -LiteralPath $contentPath -Algorithm SHA256).Hash | Should -Be $contentHash
            (Get-Content -Raw -Encoding UTF8 (Join-Path $root "Reports\Sales\Templates\MainSchema.xml")) | Should -Match "Updated schema"
            [xml]$report = Get-Content -Raw -Encoding UTF8 $reportPath
            $ns = [System.Xml.XmlNamespaceManager]::new($report.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $report.SelectSingleNode("//md:Report/md:Properties/md:MainDataCompositionSchema", $ns).InnerText | Should -Be "Report.Sales.Template.MainSchema"

            $beforeMeta = (Get-FileHash -LiteralPath (Join-Path $root "Reports\Sales\Templates\MainSchema.xml") -Algorithm SHA256).Hash
            $conflict = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Sales", "-TemplateName", "MainSchema", "-TemplateType", "Text", "-SrcDir", (Join-Path $root "Reports"))
            $conflict.ExitCode | Should -Not -Be 0
            $conflict.Output | Should -Match "TEMPLATE_TYPE_CONFLICT"
            (Get-FileHash -LiteralPath (Join-Path $root "Reports\Sales\Templates\MainSchema.xml") -Algorithm SHA256).Hash | Should -Be $beforeMeta
            (Get-FileHash -LiteralPath $contentPath -Algorithm SHA256).Hash | Should -Be $contentHash
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "safely completes supported partial template states and rejects an unprovable UUID" {
        $root = New-ForkTestRoot
        try {
            $objectPath = New-DocumentFixture $root
            $templateScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-template-manage\scripts\add-template.ps1"
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $short = $object.CreateElement("Template", "http://v8.1c.ru/8.3/MDClasses"); $short.InnerText = "RegisteredOnly"; $object.SelectSingleNode("//md:ChildObjects", $ns).AppendChild($short) | Out-Null
            $object.Save($objectPath)
            $registeredOnly = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Order", "-TemplateName", "RegisteredOnly", "-TemplateType", "Text", "-SrcDir", (Join-Path $root "Documents"))
            $registeredOnly.ExitCode | Should -Be 0 -Because $registeredOnly.Output

            $created = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Order", "-TemplateName", "MetadataOnly", "-TemplateType", "Text", "-SrcDir", (Join-Path $root "Documents"))
            $created.ExitCode | Should -Be 0 -Because $created.Output
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $reference = $object.SelectSingleNode("//md:ChildObjects/md:Template[text()='MetadataOnly']", $ns)
            $reference.ParentNode.RemoveChild($reference) | Out-Null
            $object.Save($objectPath)
            Remove-Item -LiteralPath (Join-Path $root "Documents\Order\Templates\MetadataOnly") -Recurse -Force
            $metadataOnly = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Order", "-TemplateName", "MetadataOnly", "-TemplateType", "Text", "-SrcDir", (Join-Path $root "Documents"))
            $metadataOnly.ExitCode | Should -Be 0 -Because $metadataOnly.Output

            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $unknown = $object.CreateElement("Template", "http://v8.1c.ru/8.3/MDClasses"); $unknown.InnerText = "UnknownUuid"; $unknown.SetAttribute("uuid", "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
            $object.SelectSingleNode("//md:ChildObjects", $ns).AppendChild($unknown) | Out-Null
            $object.Save($objectPath)
            $ambiguous = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Order", "-TemplateName", "UnknownUuid", "-TemplateType", "Text", "-SrcDir", (Join-Path $root "Documents"))
            $ambiguous.ExitCode | Should -Not -Be 0
            $ambiguous.Output | Should -Match "CFE_CHILD_OBJECT_REFERENCE_AMBIGUOUS"
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

    It "diagnoses matching legacy UUID references as non-canonical and lets the specialized tool normalize them" {
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
            $created = Invoke-WindowsPowerShellFile -FilePath $formPath -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm")
            $created.ExitCode | Should -Be 0 -Because $created.Output
            [xml]$formMeta = Get-Content -Raw -Encoding UTF8 (Join-Path $cfe "Documents\Order\Forms\ObjectForm.xml")
            $uuid = $formMeta.DocumentElement.FirstChild.GetAttribute("uuid")
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $object.SelectSingleNode("//md:ChildObjects/md:Form[text()='ObjectForm']", $ns).SetAttribute("uuid", $uuid)
            $object.Save($objectPath)

            $ambiguous = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $ambiguous.ExitCode | Should -Not -Be 0
            $ambiguous.Output | Should -Match "CFE_CHILD_OBJECT_REFERENCE_AMBIGUOUS"
            $normalized = Invoke-WindowsPowerShellFile -FilePath $formPath -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm")
            $normalized.ExitCode | Should -Be 0 -Because $normalized.Output
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $object.SelectSingleNode("//md:ChildObjects/md:Form[text()='ObjectForm']", $ns).Attributes.Count | Should -Be 0

            $templatePath = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-template-manage\scripts\add-template.ps1"
            $template = Invoke-WindowsPowerShellFile -FilePath $templatePath -Arguments @("-ObjectName", "Order", "-TemplateName", "Print", "-TemplateType", "Text", "-SrcDir", (Join-Path $cfe "Documents"))
            $template.ExitCode | Should -Be 0 -Because $template.Output
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $templateReference = $object.SelectSingleNode("//md:ChildObjects/md:Template[text()='Print']", $ns)
            $templateReference.SetAttribute("uuid", "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
            $object.Save($objectPath)
            $mismatch = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $mismatch.ExitCode | Should -Not -Be 0
            $mismatch.Output | Should -Match "CFE_CHILD_OBJECT_UUID_MISMATCH"

            [xml]$templateMeta = Get-Content -Raw -Encoding UTF8 (Join-Path $cfe "Documents\Order\Templates\Print.xml")
            $templateUuid = $templateMeta.DocumentElement.FirstChild.GetAttribute("uuid")
            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $object.SelectSingleNode("//md:ChildObjects/md:Template[text()='Print']", $ns).SetAttribute("uuid", $templateUuid)
            $object.Save($objectPath)
            $templateAmbiguous = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $templateAmbiguous.ExitCode | Should -Not -Be 0
            $templateAmbiguous.Output | Should -Match "CFE_CHILD_OBJECT_REFERENCE_AMBIGUOUS"
            $normalizedTemplate = Invoke-WindowsPowerShellFile -FilePath $templatePath -Arguments @("-ObjectName", "Order", "-TemplateName", "Print", "-TemplateType", "Text", "-SrcDir", (Join-Path $cfe "Documents"))
            $normalizedTemplate.ExitCode | Should -Be 0 -Because $normalizedTemplate.Output

            [xml]$object = Get-Content -Raw -Encoding UTF8 $objectPath
            $ns = [System.Xml.XmlNamespaceManager]::new($object.NameTable); $ns.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $duplicate = $object.CreateElement("Template", "http://v8.1c.ru/8.3/MDClasses"); $duplicate.InnerText = "Print"
            $object.SelectSingleNode("//md:ChildObjects", $ns).AppendChild($duplicate) | Out-Null
            $object.Save($objectPath)
            $duplicateResult = Invoke-WindowsPowerShellFile -FilePath $validatePath -Arguments @("-ExtensionPath", $cfe)
            $duplicateResult.ExitCode | Should -Not -Be 0
            $duplicateResult.Output | Should -Match "CFE_CHILD_OBJECT_DUPLICATE"
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "rolls back form and template updates when real Windows file locks block replacement" -Skip:($env:OS -ne 'Windows_NT') {
        $root = New-ForkTestRoot
        try {
            $objectPath = New-DocumentFixture $root
            $formScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-form-scaffold\scripts\form-add.ps1"
            (Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm")).ExitCode | Should -Be 0
            $formMetaPath = Join-Path $root "Documents\Order\Forms\ObjectForm.xml"
            $formXmlPath = Join-Path $root "Documents\Order\Forms\ObjectForm\Ext\Form.xml"
            $objectHash = (Get-FileHash -LiteralPath $objectPath -Algorithm SHA256).Hash
            $metaHash = (Get-FileHash -LiteralPath $formMetaPath -Algorithm SHA256).Hash
            $lock = [System.IO.File]::Open($formXmlPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            try {
                $blocked = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @("-ObjectPath", $objectPath, "-FormName", "ObjectForm", "-Synonym", "Must roll back")
            } finally { $lock.Dispose() }
            $blocked.ExitCode | Should -Not -Be 0
            $blocked.Output | Should -Match "FORM_ADD_TRANSACTION_FAILED"
            (Get-FileHash -LiteralPath $objectPath -Algorithm SHA256).Hash | Should -Be $objectHash
            (Get-FileHash -LiteralPath $formMetaPath -Algorithm SHA256).Hash | Should -Be $metaHash

            $templateScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-template-manage\scripts\add-template.ps1"
            (Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Order", "-TemplateName", "Print", "-TemplateType", "Text", "-SrcDir", (Join-Path $root "Documents"))).ExitCode | Should -Be 0
            $templateMetaPath = Join-Path $root "Documents\Order\Templates\Print.xml"
            $templateContentPath = Join-Path $root "Documents\Order\Templates\Print\Ext\Template.txt"
            $objectHash = (Get-FileHash -LiteralPath $objectPath -Algorithm SHA256).Hash
            $metaHash = (Get-FileHash -LiteralPath $templateMetaPath -Algorithm SHA256).Hash
            $lock = [System.IO.File]::Open($templateContentPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            try {
                $blocked = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @("-ObjectName", "Order", "-TemplateName", "Print", "-TemplateType", "Text", "-Synonym", "Must roll back", "-SrcDir", (Join-Path $root "Documents"))
            } finally { $lock.Dispose() }
            $blocked.ExitCode | Should -Not -Be 0
            $blocked.Output | Should -Match "TEMPLATE_ADD_TRANSACTION_FAILED"
            (Get-FileHash -LiteralPath $objectPath -Algorithm SHA256).Hash | Should -Be $objectHash
            (Get-FileHash -LiteralPath $templateMetaPath -Algorithm SHA256).Hash | Should -Be $metaHash
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
