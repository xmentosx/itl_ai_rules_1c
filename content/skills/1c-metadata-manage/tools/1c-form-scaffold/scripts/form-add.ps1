# form-add v1.5 — Add managed form to 1C config object
# Source: https://github.com/Nikolay-Shirokov/cc-1c-skills
param(
	[Parameter(Mandatory)]
	[string]$ObjectPath,

	[Parameter(Mandatory)]
	[string]$FormName,

	[string]$Synonym = $FormName,

	[string]$Purpose = "Object",

	[switch]$SetDefault
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# --- Detect XML format version ---

function Detect-FormatVersion([string]$dir) {
	$d = $dir
	while ($d) {
		$cfgPath = Join-Path $d "Configuration.xml"
		if (Test-Path $cfgPath) {
			$sourceText = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8)
			$head = $sourceText.Substring(0, [Math]::Min(2000, $sourceText.Length))
			if ($head -match '<MetaDataObject[^>]+version="(\d+\.\d+)"') { return $Matches[1] }
		}
		$parent = Split-Path $d -Parent
		if ($parent -eq $d) { break }
		$d = $parent
	}
	return "2.17"
}

# --- Фаза 1: Определение типа объекта ---

# Resolve ObjectPath (directory → .xml)
if (-not [System.IO.Path]::IsPathRooted($ObjectPath)) {
	$ObjectPath = Join-Path (Get-Location).Path $ObjectPath
}
if (Test-Path $ObjectPath -PathType Container) {
	$dirName = Split-Path $ObjectPath -Leaf
	$candidate = Join-Path $ObjectPath "$dirName.xml"
	$sibling = Join-Path (Split-Path $ObjectPath) "$dirName.xml"
	if (Test-Path $candidate) { $ObjectPath = $candidate }
	elseif (Test-Path $sibling) { $ObjectPath = $sibling }
}

if (-not (Test-Path $ObjectPath)) {
	Write-Error "Файл объекта не найден: $ObjectPath"
	exit 1
}

$objectXmlFull = Resolve-Path $ObjectPath
$script:formatVersion = Detect-FormatVersion (Split-Path $objectXmlFull.Path -Parent)

$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.PreserveWhitespace = $true
$xmlDoc.Load($objectXmlFull.Path)

$nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
$nsMgr.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
$nsMgr.AddNamespace("v8", "http://v8.1c.ru/8.1/data/core")

# Определяем тип объекта по корневому тегу внутри MetaDataObject
$metaDataObject = $xmlDoc.SelectSingleNode("//md:MetaDataObject", $nsMgr)
if (-not $metaDataObject) {
	# Пробуем без namespace (fallback)
	$metaDataObject = $xmlDoc.DocumentElement
}

$supportedTypes = @(
	"Document", "Catalog", "DataProcessor", "Report",
	"ExternalDataProcessor", "ExternalReport",
	"InformationRegister", "AccumulationRegister", "ChartOfAccounts", "ChartOfCharacteristicTypes",
	"ExchangePlan", "BusinessProcess", "Task"
)

$objectType = $null
$objectNode = $null
foreach ($t in $supportedTypes) {
	$node = $xmlDoc.SelectSingleNode("//md:$t", $nsMgr)
	if ($node) {
		$objectType = $t
		$objectNode = $node
		break
	}
}

if (-not $objectType) {
	Write-Error "Не удалось определить тип объекта. Поддерживаемые типы: $($supportedTypes -join ', ')"
	exit 1
}

# Имя объекта из Properties/Name
$objectName = $xmlDoc.SelectSingleNode("//md:${objectType}/md:Properties/md:Name", $nsMgr).InnerText
if (-not $objectName) {
	Write-Error "Не удалось определить имя объекта из Properties/Name"
	exit 1
}

Write-Host ""
Write-Host "=== form-add ==="
Write-Host ""
Write-Host "Object: $objectType.$objectName"

# --- Фаза 2: Валидация Purpose ---

$Purpose = $Purpose.Substring(0,1).ToUpper() + $Purpose.Substring(1).ToLower()
# Нормализация
switch ($Purpose) {
	"Object" { }
	"List"   { }
	"Choice" { }
	"Record" { }
	default {
		Write-Error "Недопустимое назначение: $Purpose. Допустимые: Object, List, Choice, Record"
		exit 1
	}
}

$objectLikeTypes = @("Document", "Catalog", "ChartOfAccounts", "ChartOfCharacteristicTypes", "ExchangePlan", "BusinessProcess", "Task")
$processorLikeTypes = @("DataProcessor", "Report", "ExternalDataProcessor", "ExternalReport")

switch ($Purpose) {
	"Object" {
		# допустимо для всех типов
	}
	"List" {
		if ($objectType -eq "DataProcessor") {
			Write-Error "Purpose=List недопустим для DataProcessor"
			exit 1
		}
	}
	"Choice" {
		if ($objectType -in $processorLikeTypes -or $objectType -eq "InformationRegister") {
			Write-Error "Purpose=Choice недопустим для $objectType"
			exit 1
		}
	}
	"Record" {
		if ($objectType -ne "InformationRegister") {
			Write-Error "Purpose=Record допустим только для InformationRegister"
			exit 1
		}
	}
}

# --- Фаза 3: Создание файлов ---

$objectDir = [System.IO.Path]::ChangeExtension($objectXmlFull.Path, $null).TrimEnd('.')
$formsDir = Join-Path $objectDir "Forms"
$formMetaPath = Join-Path $formsDir "$FormName.xml"
$formDir = Join-Path $formsDir $FormName
$formExtDir = Join-Path $formDir "Ext"
$formModuleDir = Join-Path $formExtDir "Form"
$synonymWasSpecified = $PSBoundParameters.ContainsKey("Synonym")

$childObjects = $xmlDoc.SelectSingleNode("//md:${objectType}/md:ChildObjects", $nsMgr)
if (-not $childObjects) {
	Write-Error "Не найден элемент ChildObjects в $ObjectPath"
	exit 1
}
$registeredForms = @()
foreach ($candidateForm in $childObjects.SelectNodes("md:Form", $nsMgr)) {
	$elementChild = @($candidateForm.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
	$nameNode = $candidateForm.SelectSingleNode("md:Properties/md:Name", $nsMgr)
	$candidateName = if ($nameNode -and $nameNode.InnerText) { $nameNode.InnerText.Trim() } else { $candidateForm.InnerText.Trim() }
	if ($candidateName -eq $FormName) {
		if ($elementChild.Count -gt 0) {
			Write-Error "CFE_CHILD_OBJECT_REFERENCE_AMBIGUOUS: Form.$FormName uses an unsupported structured reference"
			exit 1
		}
		$registeredForms += $candidateForm
	}
}
if ($registeredForms.Count -gt 1) {
	Write-Error "CFE_CHILD_OBJECT_DUPLICATE: Form.$FormName registered $($registeredForms.Count) times"
	exit 1
}
$formMetadataExists = Test-Path $formMetaPath -PathType Leaf
$formTreeExists = Test-Path $formDir -PathType Container
$formUuid = $null
if (Test-Path $formMetaPath -PathType Leaf) {
	$formDoc = New-Object System.Xml.XmlDocument
	$formDoc.PreserveWhitespace = $true
	try { $formDoc.Load($formMetaPath) } catch { Write-Error "FORM_METADATA_INVALID: $($_.Exception.Message)"; exit 1 }
	$formNs = New-Object System.Xml.XmlNamespaceManager($formDoc.NameTable)
	$formNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
	$formNs.AddNamespace("v8", "http://v8.1c.ru/8.1/data/core")
	$formRoot = $formDoc.SelectSingleNode("/md:MetaDataObject/md:Form", $formNs)
	if (-not $formRoot -or -not $formRoot.GetAttribute("uuid")) { Write-Error "FORM_METADATA_INVALID: Form.$FormName UUID is missing"; exit 1 }
	$formUuid = $formRoot.GetAttribute("uuid")
	$metadataName = $formDoc.SelectSingleNode("/md:MetaDataObject/md:Form/md:Properties/md:Name", $formNs)
	if (-not $metadataName -or $metadataName.InnerText -ne $FormName) {
		Write-Error "FORM_METADATA_INVALID: Form metadata Name does not match '$FormName'"
		exit 1
	}
	if ($registeredForms.Count -eq 1 -and $registeredForms[0].GetAttribute("uuid") -and $registeredForms[0].GetAttribute("uuid") -ne $formUuid) {
		Write-Error "CFE_CHILD_OBJECT_UUID_MISMATCH: Form.$FormName parent UUID does not match metadata UUID"
		exit 1
	}
}

if (-not $formMetadataExists -and $formTreeExists -and $registeredForms.Count -eq 0) {
	Write-Error "FORM_EXISTING_CONTENT_CONFLICT: Form.$FormName has content without trusted metadata or registration"
	exit 1
}

if (-not $formMetadataExists -and $registeredForms.Count -eq 1 -and $registeredForms[0].GetAttribute("uuid")) {
	Write-Error "CFE_CHILD_OBJECT_REFERENCE_AMBIGUOUS: Form.$FormName has a legacy UUID but no metadata target to prove it"
	exit 1
}

if (-not $formUuid) { $formUuid = [guid]::NewGuid().ToString() }

foreach ($otherForm in $childObjects.SelectNodes("md:Form", $nsMgr)) {
	$otherUuid = $otherForm.GetAttribute("uuid")
	if (-not $otherUuid -or $otherUuid -ne $formUuid) { continue }
	$otherNameNode = $otherForm.SelectSingleNode("md:Properties/md:Name", $nsMgr)
	$otherName = if ($otherNameNode -and $otherNameNode.InnerText) { $otherNameNode.InnerText.Trim() } else { $otherForm.InnerText.Trim() }
	if ($otherName -ne $FormName) {
		Write-Error "CFE_CHILD_OBJECT_REFERENCE_AMBIGUOUS: UUID '$formUuid' is also used by Form.$otherName"
		exit 1
	}
}

$transactionRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("form-add-" + [guid]::NewGuid().ToString("N"))
$stagedFormsDir = Join-Path $transactionRoot "Forms"
$stagedFormMetaPath = Join-Path $stagedFormsDir "$FormName.xml"
$stagedFormDir = Join-Path $stagedFormsDir $FormName
$stagedFormExtDir = Join-Path $stagedFormDir "Ext"
$stagedFormModuleDir = Join-Path $stagedFormExtDir "Form"
New-Item -ItemType Directory -Path $stagedFormsDir -Force | Out-Null
if ($formTreeExists) {
	Copy-Item -LiteralPath $formDir -Destination $stagedFormsDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagedFormModuleDir -Force | Out-Null
if ($formMetadataExists) {
	Copy-Item -LiteralPath $formMetaPath -Destination $stagedFormMetaPath -Force
}

$encBom = New-Object System.Text.UTF8Encoding($true)

# --- 3a. Метаданные формы ---

# ExtendedPresentation — only for DataProcessor, Report, ExternalDataProcessor, ExternalReport forms
$extPresentationLine = ""
if ($objectType -in $processorLikeTypes) {
	$extPresentationLine = "`n`t`t`t<ExtendedPresentation/>"
}

$formMetaXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" xmlns:app="http://v8.1c.ru/8.2/managed-application/core" xmlns:cfg="http://v8.1c.ru/8.1/data/enterprise/current-config" xmlns:cmi="http://v8.1c.ru/8.2/managed-application/cmi" xmlns:ent="http://v8.1c.ru/8.1/data/enterprise" xmlns:lf="http://v8.1c.ru/8.2/managed-application/logform" xmlns:style="http://v8.1c.ru/8.1/data/ui/style" xmlns:sys="http://v8.1c.ru/8.1/data/ui/fonts/system" xmlns:v8="http://v8.1c.ru/8.1/data/core" xmlns:v8ui="http://v8.1c.ru/8.1/data/ui" xmlns:web="http://v8.1c.ru/8.1/data/ui/colors/web" xmlns:win="http://v8.1c.ru/8.1/data/ui/colors/windows" xmlns:xen="http://v8.1c.ru/8.3/xcf/enums" xmlns:xpr="http://v8.1c.ru/8.3/xcf/predef" xmlns:xr="http://v8.1c.ru/8.3/xcf/readable" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="$($script:formatVersion)">
	<Form uuid="$formUuid">
		<Properties>
			<Name>$FormName</Name>
			<Synonym>
				<v8:item>
					<v8:lang>ru</v8:lang>
					<v8:content>$Synonym</v8:content>
				</v8:item>
			</Synonym>
			<Comment/>
			<FormType>Managed</FormType>
			<IncludeHelpInContents>false</IncludeHelpInContents>
			<UsePurposes>
				<v8:Value xsi:type="app:ApplicationUsePurpose">PlatformApplication</v8:Value>
				<v8:Value xsi:type="app:ApplicationUsePurpose">MobilePlatformApplication</v8:Value>
			</UsePurposes>$extPresentationLine
		</Properties>
	</Form>
</MetaDataObject>
"@

if (-not $formMetadataExists) {
	[System.IO.File]::WriteAllText($stagedFormMetaPath, $formMetaXml, $encBom)
} elseif ($synonymWasSpecified) {
	$stagedMetaDoc = New-Object System.Xml.XmlDocument
	$stagedMetaDoc.PreserveWhitespace = $true
	$stagedMetaDoc.Load($stagedFormMetaPath)
	$stagedMetaNs = New-Object System.Xml.XmlNamespaceManager($stagedMetaDoc.NameTable)
	$stagedMetaNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
	$stagedMetaNs.AddNamespace("v8", "http://v8.1c.ru/8.1/data/core")
	$synonymContent = $stagedMetaDoc.SelectSingleNode("/md:MetaDataObject/md:Form/md:Properties/md:Synonym/v8:item[v8:lang='ru']/v8:content", $stagedMetaNs)
	if (-not $synonymContent) {
		Write-Error "FORM_METADATA_INVALID: Form.$FormName has no Russian synonym slot"
		exit 1
	}
	$synonymContent.InnerText = $Synonym
	$stagedMetaDoc.Save($stagedFormMetaPath)
}

# --- 3b. Form.xml ---

$formXmlPath = Join-Path $formExtDir "Form.xml"
$stagedFormXmlPath = Join-Path $stagedFormExtDir "Form.xml"

$formNsDecl = 'xmlns="http://v8.1c.ru/8.3/xcf/logform" xmlns:app="http://v8.1c.ru/8.2/managed-application/core" xmlns:cfg="http://v8.1c.ru/8.1/data/enterprise/current-config" xmlns:dcscor="http://v8.1c.ru/8.1/data-composition-system/core" xmlns:dcsset="http://v8.1c.ru/8.1/data-composition-system/settings" xmlns:ent="http://v8.1c.ru/8.1/data/enterprise" xmlns:lf="http://v8.1c.ru/8.2/managed-application/logform" xmlns:style="http://v8.1c.ru/8.1/data/ui/style" xmlns:sys="http://v8.1c.ru/8.1/data/ui/fonts/system" xmlns:v8="http://v8.1c.ru/8.1/data/core" xmlns:v8ui="http://v8.1c.ru/8.1/data/ui" xmlns:web="http://v8.1c.ru/8.1/data/ui/colors/web" xmlns:win="http://v8.1c.ru/8.1/data/ui/colors/windows" xmlns:xr="http://v8.1c.ru/8.3/xcf/readable" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'

if ($Purpose -eq "List" -or $Purpose -eq "Choice") {
	# Динамический список
	# MainTable: тип.имя
	$mainTable = "$objectType.$objectName"

	$formXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Form $formNsDecl version="$($script:formatVersion)">
	<AutoCommandBar name="ФормаКоманднаяПанель" id="-1">
		<Autofill>true</Autofill>
	</AutoCommandBar>
	<ChildItems/>
	<Attributes>
		<Attribute name="Список" id="1">
			<Type>
				<v8:Type>cfg:DynamicList</v8:Type>
			</Type>
			<MainAttribute>true</MainAttribute>
			<Settings xsi:type="DynamicList">
				<MainTable>$mainTable</MainTable>
			</Settings>
		</Attribute>
	</Attributes>
</Form>
"@
} elseif ($Purpose -eq "Record") {
	# Запись регистра сведений
	$mainAttrName = "Запись"
	$mainAttrType = "InformationRegisterRecordManager.$objectName"

	$formXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Form $formNsDecl version="$($script:formatVersion)">
	<AutoCommandBar name="ФормаКоманднаяПанель" id="-1">
		<Autofill>true</Autofill>
	</AutoCommandBar>
	<ChildItems/>
	<Attributes>
		<Attribute name="$mainAttrName" id="1">
			<Type>
				<v8:Type>cfg:$mainAttrType</v8:Type>
			</Type>
			<MainAttribute>true</MainAttribute>
			<SavedData>true</SavedData>
		</Attribute>
	</Attributes>
</Form>
"@
} else {
	# Object — форма объекта
	$mainAttrName = "Объект"

	# Маппинг типа объекта на тип реквизита
	$attrTypeMap = @{
		"Document"                    = "DocumentObject"
		"Catalog"                     = "CatalogObject"
		"DataProcessor"               = "DataProcessorObject"
		"Report"                      = "ReportObject"
		"ExternalDataProcessor"       = "ExternalDataProcessorObject"
		"ExternalReport"              = "ExternalReportObject"
		"ChartOfAccounts"             = "ChartOfAccountsObject"
		"ChartOfCharacteristicTypes"  = "ChartOfCharacteristicTypesObject"
		"ExchangePlan"                = "ExchangePlanObject"
		"BusinessProcess"             = "BusinessProcessObject"
		"Task"                        = "TaskObject"
		"InformationRegister"         = "InformationRegisterRecordManager"
		"AccumulationRegister"        = "AccumulationRegisterRecordSet"
	}

	$mainAttrType = "$($attrTypeMap[$objectType]).$objectName"

	# SavedData: standard for Catalog/Document/etc, but not for processor-like (DataProcessor/Report/External*)
	$savedDataLine = ""
	if ($objectType -notin $processorLikeTypes) {
		$savedDataLine = "`n`t`t`t<SavedData>true</SavedData>"
	}

	$formXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Form $formNsDecl version="$($script:formatVersion)">
	<AutoCommandBar name="ФормаКоманднаяПанель" id="-1">
		<Autofill>true</Autofill>
	</AutoCommandBar>
	<ChildItems/>
	<Attributes>
		<Attribute name="$mainAttrName" id="1">
			<Type>
				<v8:Type>cfg:$mainAttrType</v8:Type>
			</Type>
			<MainAttribute>true</MainAttribute>$savedDataLine
		</Attribute>
	</Attributes>
</Form>
"@
}

if (-not (Test-Path $stagedFormXmlPath -PathType Leaf)) {
	[System.IO.File]::WriteAllText($stagedFormXmlPath, $formXml, $encBom)
}

# --- 3c. Module.bsl ---

$modulePath = Join-Path $formModuleDir "Module.bsl"
$stagedModulePath = Join-Path $stagedFormModuleDir "Module.bsl"

$moduleBsl = @"
#Область ОбработчикиСобытийФормы

#КонецОбласти

#Область ОбработчикиСобытийЭлементовФормы

#КонецОбласти

#Область ОбработчикиКомандФормы

#КонецОбласти

#Область ОбработчикиОповещений

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

#КонецОбласти
"@

if (-not (Test-Path $stagedModulePath -PathType Leaf)) {
	[System.IO.File]::WriteAllText($stagedModulePath, $moduleBsl, $encBom)
}

# --- Фаза 4: Регистрация в родительском объекте ---

if ($registeredForms.Count -eq 1) {
	# Normalize a matching legacy UUID-bearing reference to the canonical short form.
	$formElem = $registeredForms[0]
	$formElem.RemoveAll()
	$formElem.InnerText = $FormName
} else {
	# Add the only canonical registration: <Form>Name</Form>.
	$formElem = $xmlDoc.CreateElement("Form", "http://v8.1c.ru/8.3/MDClasses")
	$formElem.InnerText = $FormName
	$firstTemplate = $childObjects.SelectSingleNode("md:Template", $nsMgr)
	$firstTabular = $childObjects.SelectSingleNode("md:TabularSection", $nsMgr)
	$insertBefore = if ($firstTemplate) { $firstTemplate } elseif ($firstTabular) { $firstTabular } else { $null }
	if ($insertBefore) {
		$childObjects.InsertBefore($formElem, $insertBefore) | Out-Null
		$childObjects.InsertBefore($xmlDoc.CreateWhitespace("`n`t`t`t"), $insertBefore) | Out-Null
	} elseif ($childObjects.ChildNodes.Count -eq 0) {
		$childObjects.AppendChild($xmlDoc.CreateWhitespace("`n`t`t`t")) | Out-Null
		$childObjects.AppendChild($formElem) | Out-Null
		$childObjects.AppendChild($xmlDoc.CreateWhitespace("`n`t`t")) | Out-Null
	} else {
		$lastChild = $childObjects.LastChild
		if ($lastChild.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) {
			$childObjects.InsertBefore($xmlDoc.CreateWhitespace("`n`t`t`t"), $lastChild) | Out-Null
			$childObjects.InsertBefore($formElem, $lastChild) | Out-Null
		} else {
			$childObjects.AppendChild($xmlDoc.CreateWhitespace("`n`t`t`t")) | Out-Null
			$childObjects.AppendChild($formElem) | Out-Null
			$childObjects.AppendChild($xmlDoc.CreateWhitespace("`n`t`t")) | Out-Null
		}
	}
}

# --- SetDefault ---

$defaultPropName = $null
$defaultValue = "$objectType.$objectName.Form.$FormName"

# Определяем имя свойства для DefaultForm
switch ($Purpose) {
	"Object" {
		if ($objectType -in $processorLikeTypes) {
			$defaultPropName = "DefaultForm"
		} else {
			$defaultPropName = "DefaultObjectForm"
		}
	}
	"List"   { $defaultPropName = "DefaultListForm" }
	"Choice" { $defaultPropName = "DefaultChoiceForm" }
	"Record" { $defaultPropName = "DefaultRecordForm" }
}

$defaultNode = $xmlDoc.SelectSingleNode("//md:${objectType}/md:Properties/md:$defaultPropName", $nsMgr)
$defaultUpdated = $false
if ($SetDefault) {
	if (-not $defaultNode) {
		Write-Host "FORM_PURPOSE_CONFLICT"
		Write-Error "FORM_PURPOSE_CONFLICT: $defaultPropName is not available on $objectType.$objectName"
		exit 1
	}
	if (-not [string]::IsNullOrWhiteSpace($defaultNode.InnerText) -and $defaultNode.InnerText -ne $defaultValue) {
		Write-Host "FORM_PURPOSE_CONFLICT"
		Write-Error "FORM_PURPOSE_CONFLICT: $defaultPropName already points to '$($defaultNode.InnerText)'"
		exit 1
	}
	if ($defaultNode.InnerText -ne $defaultValue) {
		$defaultNode.InnerText = $defaultValue
		$defaultUpdated = $true
	}
}

# Save the parent into the transaction tree before changing any target file.
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = $encBom
$settings.Indent = $false
$stagedObjectPath = Join-Path $transactionRoot "Object.xml"
$stream = New-Object System.IO.FileStream($stagedObjectPath, [System.IO.FileMode]::Create)
$writer = [System.Xml.XmlWriter]::Create($stream, $settings)
$xmlDoc.Save($writer)
$writer.Close()
$stream.Close()

$backupRoot = Join-Path $transactionRoot "backup"
$backupFormMetaPath = Join-Path $backupRoot "$FormName.xml"
$backupFormDir = Join-Path $backupRoot $FormName
$backupObjectPath = Join-Path $backupRoot "Object.xml"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
Copy-Item -LiteralPath $objectXmlFull.Path -Destination $backupObjectPath -Force
if ($formMetadataExists) { Copy-Item -LiteralPath $formMetaPath -Destination $backupFormMetaPath -Force }
if ($formTreeExists) { Copy-Item -LiteralPath $formDir -Destination $backupRoot -Recurse -Force }

$metaReplaced = $false
$treeRemoved = $false
$treeInstalled = $false
$parentReplaced = $false
try {
	New-Item -ItemType Directory -Path $formsDir -Force | Out-Null
	Copy-Item -LiteralPath $stagedFormMetaPath -Destination $formMetaPath -Force
	$metaReplaced = $true
	if (Test-Path $formDir -PathType Container) {
		Remove-Item -LiteralPath $formDir -Recurse -Force
		$treeRemoved = $true
	}
	Copy-Item -LiteralPath $stagedFormDir -Destination $formsDir -Recurse -Force
	$treeInstalled = $true
	Copy-Item -LiteralPath $stagedObjectPath -Destination $objectXmlFull.Path -Force
	$parentReplaced = $true
} catch {
	$transactionError = $_.Exception.Message
	try {
		if ($parentReplaced) { Copy-Item -LiteralPath $backupObjectPath -Destination $objectXmlFull.Path -Force }
		if ($treeInstalled -or $treeRemoved) {
			if (Test-Path $formDir) { Remove-Item -LiteralPath $formDir -Recurse -Force }
			if ($formTreeExists) { Copy-Item -LiteralPath $backupFormDir -Destination $formsDir -Recurse -Force }
		}
		if ($metaReplaced) {
			if ($formMetadataExists) { Copy-Item -LiteralPath $backupFormMetaPath -Destination $formMetaPath -Force }
			elseif (Test-Path $formMetaPath) { Remove-Item -LiteralPath $formMetaPath -Force }
		}
	} catch {
		Write-Warning "FORM_ADD_ROLLBACK_FAILED: $($_.Exception.Message)"
	}
	Write-Error "FORM_ADD_TRANSACTION_FAILED: $transactionError"
	exit 1
} finally {
	if (Test-Path $transactionRoot) { Remove-Item -LiteralPath $transactionRoot -Recurse -Force }
}

# --- Фаза 5: Вывод ---

# Относительные пути для вывода
$basePath = Split-Path $objectXmlFull.Path -Parent
# Определяем корень (ищем родительский каталог типа Documents, Catalogs и т.д.)
$relFormMeta = $formMetaPath.Replace($basePath, "").TrimStart("\", "/")
$relFormXml = $formXmlPath.Replace($basePath, "").TrimStart("\", "/")
$relModule = $modulePath.Replace($basePath, "").TrimStart("\", "/")

$objFileName = [System.IO.Path]::GetFileName($ObjectPath)
$objDirName = Split-Path $ObjectPath -Parent
$objBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ObjectPath)

Write-Host "Created:"
Write-Host "  Metadata: $objDirName\$objBaseName\Forms\$FormName.xml"
Write-Host "  Form:     $objDirName\$objBaseName\Forms\$FormName\Ext\Form.xml"
Write-Host "  Module:   $objDirName\$objBaseName\Forms\$FormName\Ext\Form\Module.bsl"
Write-Host ""
Write-Host "Registered: <Form>$FormName</Form> in ChildObjects"
if ($defaultUpdated) {
	Write-Host "${defaultPropName}: $defaultValue"
}
Write-Host ""
