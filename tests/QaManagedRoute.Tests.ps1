BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $qaScript = Join-Path $script:ForkRoot 'content/skills/1c-qa-testing/scripts/qa-testclient.ps1'
    $guardScript = Join-Path $script:ForkRoot 'content/skills/1c-metadata-manage/tools/_common/Assert-ItlLifecycleOwnership.ps1'
}

Describe 'QA client lifecycle uses the existing ITL boundary' {
    It 'refuses each standalone action in a managed project before shared QA state or processes' -ForEach @('start','capture','stop','status') {
        $scope = Join-Path $TestDrive ('Managed project Кириллица ' + $_)
        $localState = Join-Path $scope 'Local state Кириллица'
        New-Item -ItemType Directory -Force -Path (Join-Path $scope '.agent-1c'),$localState | Out-Null
        [IO.File]::WriteAllText((Join-Path $scope '.agent-1c/project.json'),'{}')
        $beforeLocal = $env:LOCALAPPDATA
        try {
            $env:LOCALAPPDATA = $localState
            Push-Location -LiteralPath $scope
            try { $result = Invoke-WindowsPowerShellFile -FilePath $qaScript -Arguments @($_,'-Port','58139') }
            finally { Pop-Location }
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'ITL_LIFECYCLE_HELPER_REQUIRED'
            $result.Output | Should -Match 'qa-testclient.ps1'
            (Test-Path -LiteralPath (Join-Path $localState 'mcp_qa_testclient')) | Should -BeFalse
        } finally { $env:LOCALAPPDATA = $beforeLocal }
    }

    It 'discovers an installed managed root when invoked from an unrelated directory' {
        $scope = Join-Path $TestDrive 'Installed project Кириллица'
        $skills = Join-Path $scope '.agents/skills'
        $installedQa = Join-Path $skills '1c-qa-testing/scripts/qa-testclient.ps1'
        $installedGuard = Join-Path $skills '1c-metadata-manage/tools/_common/Assert-ItlLifecycleOwnership.ps1'
        $outside = Join-Path $TestDrive 'Outside work Кириллица'
        New-Item -ItemType Directory -Force -Path (Join-Path $scope '.agent-1c'),(Split-Path $installedQa),(Split-Path $installedGuard),$outside | Out-Null
        [IO.File]::WriteAllText((Join-Path $scope '.agent-1c/project.json'),'{}')
        Copy-Item -LiteralPath $qaScript -Destination $installedQa
        Copy-Item -LiteralPath $guardScript -Destination $installedGuard
        Push-Location -LiteralPath $outside
        try { $result = Invoke-WindowsPowerShellFile -FilePath $installedQa -Arguments @('status','-Port','58140') }
        finally { Pop-Location }
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'ITL_LIFECYCLE_HELPER_REQUIRED'
    }

    It 'keeps standalone read-only status working without launching a client' {
        $scope = Join-Path $TestDrive 'Standalone project Кириллица'
        New-Item -ItemType Directory -Force -Path $scope | Out-Null
        $beforeLocal = $env:LOCALAPPDATA
        try {
            $env:LOCALAPPDATA = $scope
            Push-Location -LiteralPath $scope
            try { $result = Invoke-WindowsPowerShellFile -FilePath $qaScript -Arguments @('status','-Port','58141') }
            finally { Pop-Location }
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Not -Match 'ITL_LIFECYCLE_HELPER_REQUIRED'
            $status = $result.Output | ConvertFrom-Json
            $status.port | Should -Be 58141
        } finally { $env:LOCALAPPDATA = $beforeLocal }
    }

    It 'routes managed essential checks without substituting Vanessa for required physical QA' {
        $route = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'content/rules/ui-testing-tools.md') -Raw -Encoding UTF8
        $route | Should -Match 'installed `itl-vanessa-ui-mcp` skill'
        $route | Should -Match '`TOOL_QA=required` specifically requires the physical `1c-qa` provider'
        $route | Should -Match 'Vanessa does not satisfy it'
        $route | Should -Match 'important new or changed visible behaviour at `essential`'
        $route | Should -Match '`UI_TESTING=essential` does not enable them, and `manual` does not disable them'
        $route | Should -Match 'broader no-UI instruction takes precedence'
        $route | Should -Match 'never substitutes for the fresh final helper assessment'
    }
}
