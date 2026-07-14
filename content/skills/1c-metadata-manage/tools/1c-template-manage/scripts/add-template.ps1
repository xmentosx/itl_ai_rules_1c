# template-add v1.5 — Add template to 1C object
# Source: https://github.com/Nikolay-Shirokov/cc-1c-skills
param(
	[Parameter(Mandatory)]
	[Alias("ProcessorName")]
	[string]$ObjectName,

	[Parameter(Mandatory)]
	[string]$TemplateName,

	[Parameter(Mandatory)]
	[ValidateSet("HTML", "Text", "SpreadsheetDocument", "BinaryData", "DataCompositionSchema")]
	[string]$TemplateType,

	[string]$Synonym = $TemplateName,

	[string]$SrcDir = "src",

	[switch]$SetMainSKD
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# --- Маппинг типов ---

$typeMap = @{
	"HTML"                = @{ TemplateType = "HTMLDocument";        Ext = ".html" }
	"Text"                = @{ TemplateType = "TextDocument";        Ext = ".txt" }
	"SpreadsheetDocument" = @{ TemplateType = "SpreadsheetDocument"; Ext = ".xml" }
	"BinaryData"          = @{ TemplateType = "BinaryData";          Ext = ".bin" }
	"DataCompositionSchema" = @{ TemplateType = "DataCompositionSchema"; Ext = ".xml" }
}

$tmpl = $typeMap[$TemplateType]

# --- Проверки ---

$objectTypeFolders = @(
	"Reports", "DataProcessors", "Documents", "Catalogs",
	"InformationRegisters", "AccumulationRegisters",
	"ChartsOfCharacteristicTypes", "ChartsOfAccounts", "ChartsOfCalculationTypes",
	"BusinessProcesses", "Tasks", "ExchangePlans"
)

$rootXmlPath = Join-Path $SrcDir "$ObjectName.xml"
if (-not (Test-Path $rootXmlPath)) {
	$candidates = @()
	foreach ($folder in $objectTypeFolders) {
		$probe = Join-Path (Join-Path $SrcDir $folder) "$ObjectName.xml"
		if (Test-Path $probe) { $candidates += (Join-Path $SrcDir $folder) }
	}
	if ($candidates.Count -eq 1) {
		$SrcDir = $candidates[0]
		$rootXmlPath = Join-Path $SrcDir "$ObjectName.xml"
		Write-Host "[INFO] SrcDir расширен до: $SrcDir"
	} elseif ($candidates.Count -gt 1) {
		Write-Error "Объект '$ObjectName' найден в нескольких подпапках: $($candidates -join ', ')`nУкажи SrcDir явно"
		exit 1
	} else {
		Write-Error "Корневой файл объекта не найден: $rootXmlPath`nОжидается: <SrcDir>/<ObjectName>.xml`nПодсказка: SrcDir должен указывать на папку типа объектов (например Reports), а не на корень конфигурации"
		exit 1
	}
}

$processorDir = Join-Path $SrcDir $ObjectName
$templatesDir = Join-Path $processorDir "Templates"
$templateMetaPath = Join-Path $templatesDir "$TemplateName.xml"

$rootXmlFull = Resolve-Path $rootXmlPath
$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.PreserveWhitespace = $true
$xmlDoc.Load($rootXmlFull.Path)
$nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
$nsMgr.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
$childObjects = $xmlDoc.SelectSingleNode("//md:ChildObjects", $nsMgr)
if (-not $childObjects) {
	Write-Error "Не найден элемент ChildObjects в $rootXmlPath"
	exit 1
}
$registeredTemplates = @($childObjects.SelectNodes("md:Template", $nsMgr) | Where-Object { $_.InnerText -eq $TemplateName })
if ($registeredTemplates.Count -gt 1) {
	Write-Error "CFE_CHILD_OBJECT_DUPLICATE: Template.$TemplateName registered $($registeredTemplates.Count) times"
	exit 1
}

# --- Создание каталогов ---

$templateDir = Join-Path $templatesDir $TemplateName
$templateExtDir = Join-Path $templateDir "Ext"
$templateFilePath = Join-Path $templateExtDir "Template$($tmpl.Ext)"
if (Test-Path $templateMetaPath -PathType Leaf) {
	if ($registeredTemplates.Count -eq 1 -and (Test-Path $templateFilePath -PathType Leaf)) {
		Write-Host "[OK] Template.$TemplateName already exists and is registered once"
		exit 0
	}
	Write-Error "CFE_CHILD_OBJECT_TARGET_MISSING: Template.$TemplateName is only partially present"
	exit 1
}
if ($registeredTemplates.Count -eq 1) {
	Write-Error "CFE_CHILD_OBJECT_TARGET_MISSING: Template.$TemplateName is registered but metadata file is missing"
	exit 1
}

$transactionRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("template-add-" + [guid]::NewGuid().ToString("N"))
$stagedTemplatesDir = Join-Path $transactionRoot "Templates"
$stagedTemplateMetaPath = Join-Path $stagedTemplatesDir "$TemplateName.xml"
$stagedTemplateDir = Join-Path $stagedTemplatesDir $TemplateName
$stagedTemplateExtDir = Join-Path $stagedTemplateDir "Ext"
New-Item -ItemType Directory -Path $stagedTemplateExtDir -Force | Out-Null

# --- Кодировка ---

$encBom = New-Object System.Text.UTF8Encoding($true)

# --- Detect format version ---

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

$formatVersion = Detect-FormatVersion (Resolve-Path $SrcDir).Path

# --- 1. Метаданные макета (Templates/<TemplateName>.xml) ---

$templateUuid = [guid]::NewGuid().ToString()

$templateMetaXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" xmlns:app="http://v8.1c.ru/8.2/managed-application/core" xmlns:cfg="http://v8.1c.ru/8.1/data/enterprise/current-config" xmlns:cmi="http://v8.1c.ru/8.2/managed-application/cmi" xmlns:ent="http://v8.1c.ru/8.1/data/enterprise" xmlns:lf="http://v8.1c.ru/8.2/managed-application/logform" xmlns:style="http://v8.1c.ru/8.1/data/ui/style" xmlns:sys="http://v8.1c.ru/8.1/data/ui/fonts/system" xmlns:v8="http://v8.1c.ru/8.1/data/core" xmlns:v8ui="http://v8.1c.ru/8.1/data/ui" xmlns:web="http://v8.1c.ru/8.1/data/ui/colors/web" xmlns:win="http://v8.1c.ru/8.1/data/ui/colors/windows" xmlns:xen="http://v8.1c.ru/8.3/xcf/enums" xmlns:xpr="http://v8.1c.ru/8.3/xcf/predef" xmlns:xr="http://v8.1c.ru/8.3/xcf/readable" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version=`"$formatVersion`">
	<Template uuid="$templateUuid">
		<Properties>
			<Name>$TemplateName</Name>
			<Synonym>
				<v8:item>
					<v8:lang>ru</v8:lang>
					<v8:content>$Synonym</v8:content>
				</v8:item>
			</Synonym>
			<Comment/>
			<TemplateType>$($tmpl.TemplateType)</TemplateType>
		</Properties>
	</Template>
</MetaDataObject>
"@

[System.IO.File]::WriteAllText($stagedTemplateMetaPath, $templateMetaXml, $encBom)

# --- 2. Содержимое макета (Templates/<TemplateName>/Ext/Template.<ext>) ---

$stagedTemplateFilePath = Join-Path $stagedTemplateExtDir "Template$($tmpl.Ext)"

switch ($TemplateType) {
	"HTML" {
		$content = @"
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<title></title>
</head>
<body>
</body>
</html>
"@
		[System.IO.File]::WriteAllText($stagedTemplateFilePath, $content, $encBom)
	}
	"Text" {
		[System.IO.File]::WriteAllText($stagedTemplateFilePath, "", $encBom)
	}
	"SpreadsheetDocument" {
		$content = @"
<?xml version="1.0" encoding="UTF-8"?>
<SpreadsheetDocument xmlns="http://v8.1c.ru/spreadsheet/document" xmlns:ss="http://v8.1c.ru/spreadsheet/document" xmlns:v8="http://v8.1c.ru/8.1/data/core" xmlns:xs="http://www.w3.org/2001/XMLSchema">
</SpreadsheetDocument>
"@
		[System.IO.File]::WriteAllText($stagedTemplateFilePath, $content, $encBom)
	}
	"BinaryData" {
		[System.IO.File]::WriteAllBytes($stagedTemplateFilePath, @())
	}
	"DataCompositionSchema" {
		$content = @"
<?xml version="1.0" encoding="UTF-8"?>
<DataCompositionSchema xmlns="http://v8.1c.ru/8.1/data-composition-system/schema"
		xmlns:dcscom="http://v8.1c.ru/8.1/data-composition-system/common"
		xmlns:dcscor="http://v8.1c.ru/8.1/data-composition-system/core"
		xmlns:dcsset="http://v8.1c.ru/8.1/data-composition-system/settings"
		xmlns:v8="http://v8.1c.ru/8.1/data/core"
		xmlns:v8ui="http://v8.1c.ru/8.1/data/ui"
		xmlns:xs="http://www.w3.org/2001/XMLSchema"
		xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<dataSource>
		<name>ИсточникДанных1</name>
		<dataSourceType>Local</dataSourceType>
	</dataSource>
</DataCompositionSchema>
"@
		[System.IO.File]::WriteAllText($stagedTemplateFilePath, $content, $encBom)
	}
}

# --- 3. Модификация корневого XML ---

# Добавить <Template> в конец ChildObjects
$templateElem = $xmlDoc.CreateElement("Template", "http://v8.1c.ru/8.3/MDClasses")
$templateElem.InnerText = $TemplateName

if ($childObjects.ChildNodes.Count -eq 0) {
	$childObjects.AppendChild($xmlDoc.CreateWhitespace("`n`t`t`t")) | Out-Null
	$childObjects.AppendChild($templateElem) | Out-Null
	$childObjects.AppendChild($xmlDoc.CreateWhitespace("`n`t`t")) | Out-Null
} else {
	$lastChild = $childObjects.LastChild
	# Вставить перед закрывающим whitespace (если есть), или в конец
	if ($lastChild.NodeType -eq [System.Xml.XmlNodeType]::Whitespace) {
		$childObjects.InsertBefore($xmlDoc.CreateWhitespace("`n`t`t`t"), $lastChild) | Out-Null
		$childObjects.InsertBefore($templateElem, $lastChild) | Out-Null
	} else {
		$childObjects.AppendChild($xmlDoc.CreateWhitespace("`n`t`t`t")) | Out-Null
		$childObjects.AppendChild($templateElem) | Out-Null
		$childObjects.AppendChild($xmlDoc.CreateWhitespace("`n`t`t")) | Out-Null
	}
}

# --- 4. MainDataCompositionSchema (для ExternalReport / Report) ---

$mainDCSUpdated = $false
if ($TemplateType -eq "DataCompositionSchema") {
	# Определяем корневой элемент объекта
	$reportLikeTypes = @("ExternalReport", "Report")
	$objectTypeNode = $null
	$objectTypeName = $null
	foreach ($rt in $reportLikeTypes) {
		$node = $xmlDoc.SelectSingleNode("//md:$rt", $nsMgr)
		if ($node) {
			$objectTypeNode = $node
			$objectTypeName = $rt
			break
		}
	}

	if ($objectTypeNode) {
		$mainDCS = $xmlDoc.SelectSingleNode("//md:${objectTypeName}/md:Properties/md:MainDataCompositionSchema", $nsMgr)
		if ($mainDCS) {
			$isEmpty = [string]::IsNullOrWhiteSpace($mainDCS.InnerText)
			if ($isEmpty -or $SetMainSKD) {
				$objName = $xmlDoc.SelectSingleNode("//md:${objectTypeName}/md:Properties/md:Name", $nsMgr).InnerText
				$mainDCS.InnerText = "$objectTypeName.$objName.Template.$TemplateName"
				$mainDCSUpdated = $true
			}
		}
	}
}

# Stage the parent XML, then commit the complete tree with rollback.
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = $encBom
$settings.Indent = $false
$stagedObjectPath = Join-Path $transactionRoot "Object.xml"
$stream = New-Object System.IO.FileStream($stagedObjectPath, [System.IO.FileMode]::Create)
$writer = [System.Xml.XmlWriter]::Create($stream, $settings)
$xmlDoc.Save($writer)
$writer.Close()
$stream.Close()

$committedMeta = $false
$committedTree = $false
try {
	New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null
	Move-Item -LiteralPath $stagedTemplateMetaPath -Destination $templateMetaPath
	$committedMeta = $true
	Move-Item -LiteralPath $stagedTemplateDir -Destination $templateDir
	$committedTree = $true
	Move-Item -LiteralPath $stagedObjectPath -Destination $rootXmlFull.Path -Force
} catch {
	if ($committedTree -and (Test-Path $templateDir)) { Remove-Item -LiteralPath $templateDir -Recurse -Force }
	if ($committedMeta -and (Test-Path $templateMetaPath)) { Remove-Item -LiteralPath $templateMetaPath -Force }
	Write-Error "TEMPLATE_ADD_TRANSACTION_FAILED: $($_.Exception.Message)"
	exit 1
} finally {
	if (Test-Path $transactionRoot) { Remove-Item -LiteralPath $transactionRoot -Recurse -Force }
}

Write-Host "[OK] Создан макет: $TemplateName ($TemplateType)"
Write-Host "     Метаданные: $templateMetaPath"
Write-Host "     Содержимое: $templateFilePath"
if ($mainDCSUpdated) {
	Write-Host "     MainDataCompositionSchema: $($mainDCS.InnerText)"
}
