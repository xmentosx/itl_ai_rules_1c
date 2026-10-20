BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")

    $script:ValidatorTestRoot = New-ForkTestRoot
    $script:UuidValidator = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-uuid-check\scripts\uuid-check.ps1"
    $script:MetadataValidator = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-meta-validate\scripts\meta-validate.ps1"
    $script:PythonMetadataValidator = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-meta-validate\scripts\meta-validate.py"

    function Write-ValidatorFixture {
        param([string]$Path, [string]$Content)
        $parent = Split-Path -Parent $Path
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
    }

    function New-GeneratedTypeMetadataXml {
        param([string]$Name, [string]$ObjectUuid, [string]$TypeId, [string]$ValueId)
        return @"
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" xmlns:xr="http://v8.1c.ru/8.3/xcf/readable" version="2.17">
  <DefinedType uuid="$ObjectUuid">
    <InternalInfo>
      <xr:GeneratedType name="DefinedType.$Name" category="Ref">
        <xr:TypeId>$TypeId</xr:TypeId>
        <xr:ValueId>$ValueId</xr:ValueId>
      </xr:GeneratedType>
    </InternalInfo>
    <Properties><Name>$Name</Name></Properties>
  </DefinedType>
</MetaDataObject>
"@
    }
}

AfterAll {
    Remove-Item -LiteralPath $script:ValidatorTestRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Metadata integrity validator regressions" -Tag "Fast" {
    It "ignores generated type references in forms while retaining the metadata identity definition" {
        $caseRoot = Join-Path $script:ValidatorTestRoot "type-reference"
        $typeId = "10ffa7c3-3d5d-4edd-9ebe-1acc0592d242"
        $valueId = "20ffa7c3-3d5d-4edd-9ebe-1acc0592d242"
        Write-ValidatorFixture -Path (Join-Path $caseRoot "DefinedTypes\Recipient.xml") -Content (
            New-GeneratedTypeMetadataXml -Name "Recipient" -ObjectUuid "30ffa7c3-3d5d-4edd-9ebe-1acc0592d242" -TypeId $typeId -ValueId $valueId
        )
        Write-ValidatorFixture -Path (Join-Path $caseRoot "Forms\Example\Ext\Form.xml") -Content @"
<?xml version="1.0" encoding="UTF-8"?>
<Form xmlns="http://v8.1c.ru/8.3/xcf/logform" xmlns:v8="http://v8.1c.ru/8.1/data/core">
  <Attributes>
    <Attribute name="Recipient" id="1"><Type><v8:TypeId>$typeId</v8:TypeId></Type></Attribute>
    <Attribute name="RecipientValue" id="2"><Type><v8:ValueId>$valueId</v8:ValueId></Type></Attribute>
  </Attributes>
</Form>
"@

        $result = Invoke-WindowsPowerShellFile -FilePath $script:UuidValidator -Arguments @("-ConfigPath", $caseRoot)
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match "No duplicate UUIDs found"
    }

    It "still rejects duplicate generated type identities from metadata InternalInfo" {
        $caseRoot = Join-Path $script:ValidatorTestRoot "generated-identity-duplicate"
        $typeId = "40ffa7c3-3d5d-4edd-9ebe-1acc0592d242"
        Write-ValidatorFixture -Path (Join-Path $caseRoot "DefinedTypes\First.xml") -Content (
            New-GeneratedTypeMetadataXml -Name "First" -ObjectUuid "50ffa7c3-3d5d-4edd-9ebe-1acc0592d242" -TypeId $typeId -ValueId "60ffa7c3-3d5d-4edd-9ebe-1acc0592d242"
        )
        Write-ValidatorFixture -Path (Join-Path $caseRoot "DefinedTypes\Second.xml") -Content (
            New-GeneratedTypeMetadataXml -Name "Second" -ObjectUuid "70ffa7c3-3d5d-4edd-9ebe-1acc0592d242" -TypeId $typeId -ValueId "80ffa7c3-3d5d-4edd-9ebe-1acc0592d242"
        )

        $result = Invoke-WindowsPowerShellFile -FilePath $script:UuidValidator -Arguments @("-ConfigPath", $caseRoot)
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match "Duplicate UUIDs: 1"
        $result.Output | Should -Match "\[TypeId\]"
    }

    It "still rejects duplicate uuid attributes across files" {
        $caseRoot = Join-Path $script:ValidatorTestRoot "object-identity-duplicate"
        $objectUuid = "90ffa7c3-3d5d-4edd-9ebe-1acc0592d242"
        Write-ValidatorFixture -Path (Join-Path $caseRoot "First.xml") -Content "<Form uuid=""$objectUuid"" />"
        Write-ValidatorFixture -Path (Join-Path $caseRoot "Second.xml") -Content "<Form uuid=""$objectUuid"" />"

        $result = Invoke-WindowsPowerShellFile -FilePath $script:UuidValidator -Arguments @("-ConfigPath", $caseRoot)
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match "Duplicate UUIDs: 1"
        $result.Output | Should -Match "\[uuid\]"
    }

    It "scans only the explicit lifecycle delta when an include path list is supplied" {
        $caseRoot = Join-Path $script:ValidatorTestRoot "explicit-delta"
        $unrelatedUuid = "b0ffa7c3-3d5d-4edd-9ebe-1acc0592d242"
        Write-ValidatorFixture -Path (Join-Path $caseRoot "Configuration.xml") -Content '<MetaDataObject><Configuration uuid="c0ffa7c3-3d5d-4edd-9ebe-1acc0592d242" /></MetaDataObject>'
        Write-ValidatorFixture -Path (Join-Path $caseRoot "Changed.xml") -Content '<MetaDataObject><Catalog uuid="d0ffa7c3-3d5d-4edd-9ebe-1acc0592d242" /></MetaDataObject>'
        Write-ValidatorFixture -Path (Join-Path $caseRoot "Unchanged\First.xml") -Content ('<Form uuid="{0}" />' -f $unrelatedUuid)
        Write-ValidatorFixture -Path (Join-Path $caseRoot "Unchanged\Second.xml") -Content ('<Form uuid="{0}" />' -f $unrelatedUuid)
        $includePath = Join-Path $caseRoot "include-paths.txt"
        Write-ValidatorFixture -Path $includePath -Content "Configuration.xml`nChanged.xml`n"

        $result = Invoke-WindowsPowerShellFile -FilePath $script:UuidValidator -Arguments @(
            "-ConfigPath", $caseRoot, "-IncludePathList", $includePath
        )
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match "Scanned files: 2"
        $result.Output | Should -Match "No duplicate UUIDs found"
    }

    It "accepts a metadata Form descriptor as a structural metadata object" {
        $objectPath = Join-Path $script:ValidatorTestRoot "form-descriptor\Example.xml"
        Write-ValidatorFixture -Path $objectPath -Content @'
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" version="2.17">
  <Form uuid="a0ffa7c3-3d5d-4edd-9ebe-1acc0592d242">
    <Properties><Name>PreliminaryDiagnostics</Name></Properties>
  </Form>
</MetaDataObject>
'@

        $result = Invoke-WindowsPowerShellFile -FilePath $script:MetadataValidator -Arguments @("-ObjectPath", $objectPath)
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match "Validation OK: Form\.PreliminaryDiagnostics"
        $pythonOutput = @(& python $script:PythonMetadataValidator -ObjectPath $objectPath 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($pythonOutput -join "`n")
        ($pythonOutput -join "`n") | Should -Match "Validation OK: Form\.PreliminaryDiagnostics"
    }

    It "accepts a metadata <Type> descriptor as a structural metadata object" -TestCases @(
        @{ Type = "Template"; Name = "MainDataCompositionSchema"; Uuid = "b0ffa7c3-3d5d-4edd-9ebe-1acc0592d242"; Extra = "<TemplateType>DataCompositionSchema</TemplateType>" }
        @{ Type = "IntegrationService"; Name = "MessageExchange"; Uuid = "c0ffa7c3-3d5d-4edd-9ebe-1acc0592d242"; Extra = "<ExternalIntegrationServiceAddress />" }
    ) {
        param($Type, $Name, $Uuid, $Extra)

        $objectPath = Join-Path $script:ValidatorTestRoot ("structural-descriptor\{0}.xml" -f $Type)
        Write-ValidatorFixture -Path $objectPath -Content @"
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" version="2.20">
  <$Type uuid="$Uuid">
    <Properties><Name>$Name</Name>$Extra</Properties>
  </$Type>
</MetaDataObject>
"@

        $result = Invoke-WindowsPowerShellFile -FilePath $script:MetadataValidator -Arguments @("-ObjectPath", $objectPath)
        $result.ExitCode | Should -Be 0 -Because $result.Output
        $result.Output | Should -Match ("Validation OK: {0}\.{1}" -f $Type, $Name)
        $pythonOutput = @(& python $script:PythonMetadataValidator -ObjectPath $objectPath 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($pythonOutput -join "`n")
        ($pythonOutput -join "`n") | Should -Match ("Validation OK: {0}\.{1}" -f $Type, $Name)
    }
}
