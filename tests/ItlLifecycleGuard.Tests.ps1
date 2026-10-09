$GuardedScripts = @(
    @{ Path = "1c-db-ops\scripts\db-create.ps1"; Arguments = @() },
    @{ Path = "1c-db-ops\scripts\db-dump-cf.ps1"; Arguments = @("-OutputFile", "dummy.cf") },
    @{ Path = "1c-db-ops\scripts\db-dump-dt.ps1"; Arguments = @("-OutputFile", "dummy.dt") },
    @{ Path = "1c-db-ops\scripts\db-dump-xml.ps1"; Arguments = @("-ConfigDir", "dummy") },
    @{ Path = "1c-db-ops\scripts\db-load-cf.ps1"; Arguments = @("-InputFile", "dummy.cf") },
    @{ Path = "1c-db-ops\scripts\db-load-dt.ps1"; Arguments = @("-InputFile", "dummy.dt") },
    @{ Path = "1c-db-ops\scripts\db-load-git.ps1"; Arguments = @("-ConfigDir", "dummy") },
    @{ Path = "1c-db-ops\scripts\db-load-xml.ps1"; Arguments = @("-ConfigDir", "dummy") },
    @{ Path = "1c-db-ops\scripts\db-run.ps1"; Arguments = @() },
    @{ Path = "1c-db-ops\scripts\db-update.ps1"; Arguments = @() },
    @{ Path = "1c-db-ops\scripts\install-files-update.ps1"; Arguments = @("-ProjectRoot", ".", "-IndexPath", "dummy", "-CheckOnly") },
    @{ Path = "1c-web-ops\scripts\web-publish.ps1"; Arguments = @() },
    @{ Path = "1c-web-ops\scripts\web-unpublish.ps1"; Arguments = @() },
    @{ Path = "1c-web-ops\scripts\web-stop.ps1"; Arguments = @() }
)

BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $ToolsRoot = Join-Path $RepoRoot "content\skills\1c-metadata-manage\tools"
}

Describe "ITL lifecycle ownership guard" -Tag "Fast" {
    It "blocks the new Python web mutation peers before touching Apache" -ForEach @('publish', 'unpublish', 'stop') {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("itl-python-web-Кириллица " + [guid]::NewGuid().ToString('N'))
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot '.agent-1c') | Out-Null
            [IO.File]::WriteAllText((Join-Path $tempRoot '.agent-1c/project.json'), '{}')
            $scriptPath = Join-Path $ToolsRoot "1c-web-ops/scripts/web-$_.py"
            Push-Location -LiteralPath $tempRoot
            try {
                $result = Invoke-TestNativeCommand -FilePath 'python.exe' -Arguments @($scriptPath)
            } finally { Pop-Location }
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'ITL_LIFECYCLE_HELPER_REQUIRED'
        }
        finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "blocks the new repository script before connection or lock work" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("itl-repo-Кириллица " + [guid]::NewGuid().ToString('N'))
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot '.agent-1c') | Out-Null
            [IO.File]::WriteAllText((Join-Path $tempRoot '.agent-1c/project.json'), '{}')
            $scriptPath = Join-Path $RepoRoot 'content/skills/1c-repository-manage/tools/1c-repo-ops/scripts/repo-ops.ps1'
            Push-Location -LiteralPath $tempRoot
            try {
                $result = Invoke-WindowsPowerShellFile -FilePath $scriptPath -Arguments @('-Operation', 'status')
            } finally { Pop-Location }
            $result.ExitCode | Should -Not -Be 0
            $result.Output | Should -Match 'ITL_LIFECYCLE_HELPER_REQUIRED'
        }
        finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "blocks every guarded script before project lifecycle side effects" -ForEach $GuardedScripts {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("itl guard Кириллица " + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot ".agent-1c") | Out-Null
            Set-Content -LiteralPath (Join-Path $tempRoot ".agent-1c\project.json") -Encoding UTF8 -Value "{}"
            $stdout = Join-Path $tempRoot "stdout.txt"
            $stderr = Join-Path $tempRoot "stderr.txt"
            $result = Start-Process -FilePath "powershell" -WorkingDirectory $tempRoot -ArgumentList (@(
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $ToolsRoot $Path)
            ) + @($Arguments)) -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
            $result.ExitCode | Should -Not -Be 0
            $output = (Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) +
                (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
            $output | Should -Match "ITL_LIFECYCLE_HELPER_REQUIRED"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "discovers a managed marker above the installed script location" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("itl-script-root-" + [guid]::NewGuid().ToString("N"))
        $outsideRoot = Join-Path ([IO.Path]::GetTempPath()) ("itl-outside-" + [guid]::NewGuid().ToString("N"))
        try {
            $installedTools = Join-Path $tempRoot ".agents\skills\1c-metadata-manage\tools"
            New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot ".agent-1c"), (Join-Path $installedTools "_common"), (Join-Path $installedTools "1c-web-ops\scripts"), $outsideRoot | Out-Null
            Set-Content -LiteralPath (Join-Path $tempRoot ".agent-1c\project.json") -Encoding UTF8 -Value "{}"
            Copy-Item -LiteralPath (Join-Path $ToolsRoot "_common\Assert-ItlLifecycleOwnership.ps1") -Destination (Join-Path $installedTools "_common\Assert-ItlLifecycleOwnership.ps1")
            Copy-Item -LiteralPath (Join-Path $ToolsRoot "1c-web-ops\scripts\web-stop.ps1") -Destination (Join-Path $installedTools "1c-web-ops\scripts\web-stop.ps1")
            $stderr = Join-Path $outsideRoot "stderr.txt"
            $process = Start-Process -FilePath "powershell" -WorkingDirectory $outsideRoot -ArgumentList @(
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
                (Join-Path $installedTools "1c-web-ops\scripts\web-stop.ps1")
            ) -Wait -PassThru -WindowStyle Hidden -RedirectStandardError $stderr
            $process.ExitCode | Should -Not -Be 0
            (Get-Content -LiteralPath $stderr -Raw) | Should -Match "ITL_LIFECYCLE_HELPER_REQUIRED"
        }
        finally {
            Remove-Item -LiteralPath $tempRoot, $outsideRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "keeps non-managed usage and read-only or EPF tools outside the guard" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("non-itl-" + [guid]::NewGuid().ToString("N"))
        try {
            New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
            $stderr = Join-Path $tempRoot "stderr.txt"
            $stdout = Join-Path $tempRoot "stdout.txt"
            $process = Start-Process -FilePath "powershell" -WorkingDirectory $tempRoot -ArgumentList @(
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
                (Join-Path $ToolsRoot "1c-db-ops\scripts\db-create.ps1"), "-V8Path", (Join-Path $tempRoot "missing")
            ) -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
            $output = (Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue) +
                (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
            $output | Should -Not -Match "ITL_LIFECYCLE_HELPER_REQUIRED"
            $output | Should -Match "1C executable not found"

            foreach ($relative in @(
                "1c-web-ops\scripts\web-info.ps1",
                "1c-epf-build\scripts\epf-build.ps1",
                "1c-epf-dump\scripts\epf-dump.ps1"
            )) {
                (Get-Content -LiteralPath (Join-Path $ToolsRoot $relative) -Raw) | Should -Not -Match "Assert-ItlLifecycleOwnership"
            }
        }
        finally {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
