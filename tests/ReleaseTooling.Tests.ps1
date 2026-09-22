BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")

    function New-TestReleaseQualification([string]$ForkRoot, [string]$ArtifactRoot) {
        $scriptsDir = Join-Path $ForkRoot "scripts"
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:ForkRoot "scripts\check.ps1") -Destination (Join-Path $scriptsDir "check.ps1") -Force
        Copy-Item -LiteralPath (Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1") -Destination (Join-Path $scriptsDir "publish-fork-release.ps1") -Force
        [System.IO.File]::WriteAllText((Join-Path $ForkRoot ".gitignore"), "build/`n", [System.Text.UTF8Encoding]::new($false))
        & git -C $ForkRoot add scripts .gitignore
        & git -C $ForkRoot commit -m "fixture: add qualified release tooling" | Out-Null

        New-Item -ItemType Directory -Path $ArtifactRoot -Force | Out-Null
        $junitPath = Join-Path $ArtifactRoot "pester.xml"
        [System.IO.File]::WriteAllText($junitPath, '<testsuites tests="0" failures="0"/>', [System.Text.UTF8Encoding]::new($false))
        $qualificationPath = Join-Path $ArtifactRoot "full.json"
        $commit = (& git -C $ForkRoot rev-parse HEAD).Trim()
        $tree = (& git -C $ForkRoot rev-parse 'HEAD^{tree}').Trim()
        $branch = (& git -C $ForkRoot branch --show-current).Trim()
        $qualification = [ordered]@{
            schemaVersion = 1
            kind = "itl-ai-rules-full-qualification"
            status = "passed"
            reusable = $true
            repository = [ordered]@{ name = "fixture"; commit = $commit; tree = $tree; branch = $branch; worktreeClean = $true }
            provenance = [ordered]@{ nearestForkTag = ""; upstreamRef = ""; upstreamCommit = "" }
            environment = [ordered]@{}
            inventory = [ordered]@{
                tests = @()
                scripts = @(
                    [ordered]@{ path = "scripts/check.ps1"; sha256 = (Get-FileHash -LiteralPath (Join-Path $scriptsDir "check.ps1") -Algorithm SHA256).Hash.ToLowerInvariant() }
                    [ordered]@{ path = "scripts/publish-fork-release.ps1"; sha256 = (Get-FileHash -LiteralPath (Join-Path $scriptsDir "publish-fork-release.ps1") -Algorithm SHA256).Hash.ToLowerInvariant() }
                )
            }
            junit = [ordered]@{ path = $junitPath.Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $junitPath -Algorithm SHA256).Hash.ToLowerInvariant() }
            result = [ordered]@{ passed = 0; failed = 0; skipped = 0 }
            stages = @()
            startedAt = [DateTime]::UtcNow.ToString("o")
            finishedAt = [DateTime]::UtcNow.ToString("o")
            durationMs = 0
            error = $null
        }
        [System.IO.File]::WriteAllText($qualificationPath, ($qualification | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        return $qualificationPath
    }
}

Describe "Fork release tooling" -Tag "Fast" {
    It "parses the intake and publish scripts" {
        foreach ($name in @("check.ps1", "new-upstream-upgrade.ps1", "publish-fork-release.ps1")) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                (Join-Path $script:ForkRoot "scripts\$name"),
                [ref]$tokens,
                [ref]$errors
            )
            @($errors) | Should -BeNullOrEmpty
        }
    }

    It "sets an explicit UTF-8 boundary for redirected qualification" {
        $check = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\check.ps1") -Raw -Encoding UTF8
        $check | Should -Match '\[Console\]::OutputEncoding = \$utf8'
        $check | Should -Match '\$OutputEncoding = \$utf8'
    }

    It "derives the repository root at runtime instead of in param defaults" {
        foreach ($name in @("new-upstream-upgrade.ps1", "publish-fork-release.ps1")) {
            $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\$name") -Raw -Encoding UTF8
            $text | Should -Match '\[string\]\$RepositoryRoot = ""'
            $text | Should -Match '\$PSCommandPath'
            $text | Should -Not -Match '\$RepositoryRoot = \(Split-Path -Parent \$PSScriptRoot\)'
        }
    }

    It "requires immutable source input and atomic tag publication" {
        $intake = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\new-upstream-upgrade.ps1") -Raw -Encoding UTF8
        $publish = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1") -Raw -Encoding UTF8
        $intake | Should -Match "refs/tags/"
        $intake | Should -Match "\^\[0-9a-fA-F\]\{40\}\$"
        $intake | Should -Match "must equal the current remote tip"
        $publish | Should -Match 'push", "--atomic"'
        $publish | Should -Match '\$\{resolvedUpstreamCommit\}:refs/heads/main'
        $publish | Should -Match 'itl-\$normalizedSource-r\$Revision'
        $publish | Should -Match 'upgrade/\$normalizedSource-r\$Revision'
        $publish | Should -Match 'CommitAbbreviationLength'
        $publish | Should -Match "Test-ReusableQualification"
        $publish | Should -Match '\$publishWhatIfPreference = \$WhatIfPreference'
        $publish | Should -Match '(?s)\$WhatIfPreference = \$false.*?Test-ReusableQualification.*?\$WhatIfPreference = \$publishWhatIfPreference.*?ShouldProcess'
        $publish | Should -Not -Match "SkipCheck"
    }

    It "emits a versioned Full qualification with exact inventory and stage timings" {
        $check = Get-Content -LiteralPath (Join-Path $script:ForkRoot "scripts\check.ps1") -Raw -Encoding UTF8
        $check | Should -Match '\[string\]\$QualificationPath'
        $check | Should -Match 'schemaVersion = 2'
        $check | Should -Match 'itl-ai-rules-full-qualification'
        $check | Should -Match 'inventory = \[ordered\]'
        $check | Should -Match 'durationMs'
        $check | Should -Match 'junit = \[ordered\]'
        $check | Should -Match 'git tag --merged HEAD --list "itl-\*"'
        $check | Should -Match 'git diff --check "\$resolvedUpstreamCommit\.\.HEAD"'
        $check | Should -Match 'Full requires -UpstreamCommit before publication'
        $check | Should -Not -Match 'git describe --tags'
    }
}

Describe "Upstream intake behavior" {
    It "creates an upgrade branch directly from a real remote tag" {
        $testRoot = New-ForkTestRoot
        try {
            $remoteRoot = Join-Path $testRoot "upstream.git"
            $sourceRoot = Join-Path $testRoot "source"
            $forkRoot = Join-Path $testRoot "fork"
            & git init --bare $remoteRoot | Out-Null
            & git init $sourceRoot | Out-Null
            & git -C $sourceRoot config user.email "test@example.invalid"
            & git -C $sourceRoot config user.name "ITL Test"
            Set-Content -LiteralPath (Join-Path $sourceRoot "install.ps1") -Encoding ASCII -Value "`$script:ProtocolVersion = '1.0'"
            Set-Content -LiteralPath (Join-Path $sourceRoot "AGENTS.md") -Encoding ASCII -Value "fixture"
            & git -C $sourceRoot add .
            & git -C $sourceRoot commit -m "fixture" | Out-Null
            & git -C $sourceRoot tag "v2.0.0"
            & git -C $sourceRoot remote add origin $remoteRoot
            & git -C $sourceRoot push origin HEAD:main --tags | Out-Null
            & git --git-dir=$remoteRoot symbolic-ref HEAD refs/heads/main
            & git clone $remoteRoot $forkRoot | Out-Null
            & git -C $forkRoot remote add upstream $remoteRoot

            $scriptPath = Join-Path $script:ForkRoot "scripts\new-upstream-upgrade.ps1"
            $result = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @(
                "-UpstreamTag", "v2.0.0", "-Remote", "upstream", "-RepositoryRoot", $forkRoot
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            (& git -C $forkRoot branch --show-current).Trim() | Should -Be "upgrade/v2.0.0"
            (& git -C $forkRoot rev-parse HEAD).Trim() | Should -Be (& git -C $forkRoot rev-parse "v2.0.0^{commit}").Trim()
            Test-Path -LiteralPath (Join-Path $forkRoot "build\reports\upstream-intake-v2.0.0.json") | Should -BeTrue

            $publishPath = Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1"
            $qualificationPath = New-TestReleaseQualification -ForkRoot $forkRoot -ArtifactRoot (Join-Path $testRoot "qualification")
            $publishResult = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                "-UpstreamTag", "v2.0.0", "-RepositoryRoot", $forkRoot,
                "-UpstreamRemote", "upstream", "-PublishRemote", "origin", "-QualificationPath", $qualificationPath
            )
            $publishResult.ExitCode | Should -Be 0 -Because $publishResult.Output
            (& git -C $forkRoot cat-file -t "refs/tags/itl-v2.0.0-r1").Trim() | Should -Be "tag"
            (& git -C $forkRoot rev-parse "release/itl-v2.0.0-r1").Trim() | Should -Be (& git -C $forkRoot rev-parse HEAD).Trim()
            @(& git -C $forkRoot ls-remote --tags origin "refs/tags/itl-v2.0.0-r1").Count | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "freezes the current upstream branch tip as a full commit snapshot" {
        $testRoot = New-ForkTestRoot
        try {
            $remoteRoot = Join-Path $testRoot "upstream.git"
            $sourceRoot = Join-Path $testRoot "source"
            $forkRoot = Join-Path $testRoot "fork"
            & git init --bare $remoteRoot | Out-Null
            & git init $sourceRoot | Out-Null
            & git -C $sourceRoot config user.email "test@example.invalid"
            & git -C $sourceRoot config user.name "ITL Test"
            Set-Content -LiteralPath (Join-Path $sourceRoot "install.ps1") -Encoding ASCII -Value "`$script:ProtocolVersion = '1.0'"
            Set-Content -LiteralPath (Join-Path $sourceRoot "AGENTS.md") -Encoding ASCII -Value "fixture"
            & git -C $sourceRoot add .
            & git -C $sourceRoot commit -m "first" | Out-Null
            $staleCommit = (& git -C $sourceRoot rev-parse HEAD).Trim()
            Add-Content -LiteralPath (Join-Path $sourceRoot "AGENTS.md") -Encoding ASCII -Value "current"
            & git -C $sourceRoot add AGENTS.md
            & git -C $sourceRoot commit -m "current" | Out-Null
            $currentCommit = (& git -C $sourceRoot rev-parse HEAD).Trim()
            & git -C $sourceRoot remote add origin $remoteRoot
            & git -C $sourceRoot push origin HEAD:main | Out-Null
            & git --git-dir=$remoteRoot symbolic-ref HEAD refs/heads/main
            & git clone $remoteRoot $forkRoot | Out-Null
            & git -C $forkRoot remote add upstream $remoteRoot

            $scriptPath = Join-Path $script:ForkRoot "scripts\new-upstream-upgrade.ps1"
            $staleResult = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @(
                "-UpstreamCommit", $staleCommit, "-UpstreamBranch", "main",
                "-Remote", "upstream", "-RepositoryRoot", $forkRoot
            )
            $staleResult.ExitCode | Should -Not -Be 0
            $staleResult.Output | Should -Match "must equal the current remote tip"

            $result = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @(
                "-UpstreamCommit", $currentCommit, "-UpstreamBranch", "main",
                "-Remote", "upstream", "-RepositoryRoot", $forkRoot
            )
            $result.ExitCode | Should -Be 0 -Because $result.Output
            $sourceId = "main-$($currentCommit.Substring(0, 8))"
            (& git -C $forkRoot branch --show-current).Trim() | Should -Be "upgrade/$sourceId"
            (& git -C $forkRoot rev-parse HEAD).Trim() | Should -Be $currentCommit
            $reportPath = Join-Path $forkRoot "build\reports\upstream-intake-$sourceId.json"
            Test-Path -LiteralPath $reportPath | Should -BeTrue
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $report.upstreamSourceKind | Should -Be "commit"
            $report.upstreamRef | Should -Be "refs/heads/main"
            $report.upstreamCommit | Should -Be $currentCommit

            $publishPath = Join-Path $script:ForkRoot "scripts\publish-fork-release.ps1"
            $qualificationPath = New-TestReleaseQualification -ForkRoot $forkRoot -ArtifactRoot (Join-Path $testRoot "qualification")
            $publishResult = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                "-UpstreamCommit", $currentCommit, "-UpstreamBranch", "main",
                "-RepositoryRoot", $forkRoot, "-UpstreamRemote", "upstream",
                "-PublishRemote", "origin", "-QualificationPath", $qualificationPath, "-Push"
            )
            $publishResult.ExitCode | Should -Be 0 -Because $publishResult.Output
            (& git -C $forkRoot cat-file -t "refs/tags/itl-$sourceId-r1").Trim() | Should -Be "tag"
            $annotation = (& git -C $forkRoot for-each-ref "--format=%(contents)" "refs/tags/itl-$sourceId-r1") -join "`n"
            $annotation | Should -Match "refs/heads/main@$currentCommit"
            (& git -C $forkRoot rev-parse "refs/remotes/origin/main").Trim() | Should -Be $currentCommit
            @(& git -C $forkRoot ls-remote --tags origin "refs/tags/itl-$sourceId-r1").Count | Should -Be 1
            @(& git -C $forkRoot ls-remote --heads origin "refs/heads/release/itl-$sourceId-r1").Count | Should -Be 1

            & git -C $forkRoot branch -m "upgrade/$sourceId-r2"
            $publishR2 = Invoke-WindowsPowerShellFile -FilePath $publishPath -Arguments @(
                "-UpstreamCommit", $currentCommit, "-UpstreamBranch", "main", "-Revision", "2",
                "-RepositoryRoot", $forkRoot, "-UpstreamRemote", "upstream",
                "-PublishRemote", "origin", "-QualificationPath", $qualificationPath
            )
            $publishR2.ExitCode | Should -Be 0 -Because $publishR2.Output
            (& git -C $forkRoot cat-file -t "refs/tags/itl-$sourceId-r2").Trim() | Should -Be "tag"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Metadata scaffold repeatability" {
    It "updates explicit form and template metadata without overwriting authored content" {
        $testRoot = Join-Path ([IO.Path]::GetTempPath()) ("itl-metadata-repeatability-" + [guid]::NewGuid().ToString("N"))
        try {
            $reportsDir = Join-Path $testRoot "Reports"
            New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
            $objectPath = Join-Path $reportsDir "SmokeReport.xml"
            $objectXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<MetaDataObject xmlns="http://v8.1c.ru/8.3/MDClasses" xmlns:v8="http://v8.1c.ru/8.1/data/core" version="2.17">
  <Report uuid="11111111-1111-1111-1111-111111111111">
    <Properties>
      <Name>SmokeReport</Name>
      <Synonym><v8:item><v8:lang>ru</v8:lang><v8:content>Smoke</v8:content></v8:item></Synonym>
      <DefaultForm/>
      <MainDataCompositionSchema/>
    </Properties>
    <ChildObjects/>
  </Report>
</MetaDataObject>
'@
            [IO.File]::WriteAllText($objectPath, $objectXml, [Text.UTF8Encoding]::new($true))

            $formScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-form-scaffold\scripts\form-add.ps1"
            $firstForm = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @(
                "-ObjectPath", $objectPath, "-FormName", "MainForm", "-Synonym", "Draft form", "-SetDefault"
            )
            $firstForm.ExitCode | Should -Be 0 -Because $firstForm.Output

            $formRoot = Join-Path $reportsDir "SmokeReport\Forms\MainForm\Ext"
            $formContentPath = Join-Path $formRoot "Form.xml"
            $modulePath = Join-Path $formRoot "Form\Module.bsl"
            $authoredForm = [Text.UTF8Encoding]::new($false).GetBytes("<Form>authored form</Form>")
            $authoredModule = [Text.UTF8Encoding]::new($false).GetBytes("Procedure Authored()`nEndProcedure")
            [IO.File]::WriteAllBytes($formContentPath, $authoredForm)
            [IO.File]::WriteAllBytes($modulePath, $authoredModule)
            $formContentBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($formContentPath))
            $moduleBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($modulePath))

            $secondForm = Invoke-WindowsPowerShellFile -FilePath $formScript -Arguments @(
                "-ObjectPath", $objectPath, "-FormName", "MainForm", "-Synonym", "Final form", "-SetDefault"
            )
            $secondForm.ExitCode | Should -Be 0 -Because $secondForm.Output
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($formContentPath)) | Should -Be $formContentBefore
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($modulePath)) | Should -Be $moduleBefore

            $templateScript = Join-Path $script:ForkRoot "content\skills\1c-metadata-manage\tools\1c-template-manage\scripts\add-template.ps1"
            $firstTemplate = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @(
                "-ObjectName", "SmokeReport", "-TemplateName", "MainSchema", "-TemplateType", "DataCompositionSchema",
                "-Synonym", "Draft schema", "-SrcDir", $reportsDir, "-SetMainSKD"
            )
            $firstTemplate.ExitCode | Should -Be 0 -Because $firstTemplate.Output

            $templateContentPath = Join-Path $reportsDir "SmokeReport\Templates\MainSchema\Ext\Template.xml"
            $authoredTemplate = [Text.UTF8Encoding]::new($false).GetBytes("<DataCompositionSchema>authored schema</DataCompositionSchema>")
            [IO.File]::WriteAllBytes($templateContentPath, $authoredTemplate)
            $templateBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($templateContentPath))

            $secondTemplate = Invoke-WindowsPowerShellFile -FilePath $templateScript -Arguments @(
                "-ObjectName", "SmokeReport", "-TemplateName", "MainSchema", "-TemplateType", "DataCompositionSchema",
                "-Synonym", "Final schema", "-SrcDir", $reportsDir, "-SetMainSKD"
            )
            $secondTemplate.ExitCode | Should -Be 0 -Because $secondTemplate.Output
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($templateContentPath)) | Should -Be $templateBefore

            $rootDoc = New-Object System.Xml.XmlDocument
            $rootDoc.Load($objectPath)
            $rootNs = New-Object System.Xml.XmlNamespaceManager($rootDoc.NameTable)
            $rootNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            @($rootDoc.SelectNodes("//md:ChildObjects/md:Form[text()='MainForm']", $rootNs)).Count | Should -Be 1
            @($rootDoc.SelectNodes("//md:ChildObjects/md:Template[text()='MainSchema']", $rootNs)).Count | Should -Be 1
            $rootDoc.SelectSingleNode("//md:Report/md:Properties/md:DefaultForm", $rootNs).InnerText | Should -Be "Report.SmokeReport.Form.MainForm"
            $rootDoc.SelectSingleNode("//md:Report/md:Properties/md:MainDataCompositionSchema", $rootNs).InnerText | Should -Be "Report.SmokeReport.Template.MainSchema"

            $formMetaDoc = New-Object System.Xml.XmlDocument
            $formMetaDoc.Load((Join-Path $reportsDir "SmokeReport\Forms\MainForm.xml"))
            $formMetaNs = New-Object System.Xml.XmlNamespaceManager($formMetaDoc.NameTable)
            $formMetaNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $formMetaNs.AddNamespace("v8", "http://v8.1c.ru/8.1/data/core")
            $formMetaDoc.SelectSingleNode("//md:Synonym/v8:item[v8:lang='ru']/v8:content", $formMetaNs).InnerText | Should -Be "Final form"

            $templateMetaDoc = New-Object System.Xml.XmlDocument
            $templateMetaDoc.Load((Join-Path $reportsDir "SmokeReport\Templates\MainSchema.xml"))
            $templateMetaNs = New-Object System.Xml.XmlNamespaceManager($templateMetaDoc.NameTable)
            $templateMetaNs.AddNamespace("md", "http://v8.1c.ru/8.3/MDClasses")
            $templateMetaNs.AddNamespace("v8", "http://v8.1c.ru/8.1/data/core")
            $templateMetaDoc.SelectSingleNode("//md:Synonym/v8:item[v8:lang='ru']/v8:content", $templateMetaNs).InnerText | Should -Be "Final schema"
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
