Set-StrictMode -Version Latest

function Get-ForkFullStageCatalog {
    return @(
        [pscustomobject]@{ name = 'rules-validator'; runtime = 'powershell'; path = 'tools/validate-rules.ps1'; arguments = @() }
        [pscustomobject]@{ name = 'tool-policy-settings'; runtime = 'powershell'; path = 'tools/tests/tool-policy-settings.ps1'; arguments = @() }
        [pscustomobject]@{ name = 'initial-source-dump'; runtime = 'powershell'; path = 'tools/tests/initial-source-dump.ps1'; arguments = @() }
        [pscustomobject]@{ name = 'files-update-task'; runtime = 'powershell'; path = 'tools/tests/files-update-task.ps1'; arguments = @() }
        [pscustomobject]@{ name = 'render-gate-evals'; runtime = 'powershell'; path = 'tools/render-gate-evals.ps1'; arguments = @('-OutDir', '{EVAL_OUTPUT}') }
        [pscustomobject]@{ name = 'metadata-tools'; runtime = 'powershell'; path = 'tools/tests/metadata-tools-regression.ps1'; arguments = @() }
        [pscustomobject]@{ name = 'marketplace-bootstrap'; runtime = 'powershell'; path = 'tools/tests/marketplace-bootstrap.ps1'; arguments = @() }
        [pscustomobject]@{ name = 'agent-adapters'; runtime = 'powershell'; path = 'tools/tests/agent-adapters.ps1'; arguments = @() }
        [pscustomobject]@{ name = 'installer-paths'; runtime = 'powershell'; path = 'tools/tests/installer-paths-regression.ps1'; arguments = @() }
        [pscustomobject]@{ name = 'python-ports'; runtime = 'python'; path = 'tools/tests/python-ports-regression.py'; arguments = @() }
        [pscustomobject]@{ name = 'web-python'; runtime = 'python'; path = 'tools/tests/web-python-regression.py'; arguments = @() }
        [pscustomobject]@{ name = 'transcribe'; runtime = 'python'; path = 'tools/tests/transcribe-regression.py'; arguments = @() }
        [pscustomobject]@{ name = 'docx-dependencies'; runtime = 'npm'; path = 'content/skills/md-to-docx/package-lock.json'; arguments = @('ci', '--prefix', '{DOCX_ROOT}', '--ignore-scripts', '--no-audit', '--no-fund') }
        [pscustomobject]@{ name = 'md-to-docx'; runtime = 'python'; path = 'tools/tests/md-to-docx-regression.py'; arguments = @() }
        [pscustomobject]@{ name = 'plugin-syntax'; runtime = 'node'; path = 'plugins/1c-rules/plugin.mjs'; arguments = @('--check') }
    )
}

function Get-ForkFullInventory {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)
    $relativePaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($directory in @('tests', 'tools/tests', 'adapters', 'plugins/1c-rules', 'content/openspec-bundle')) {
        $root = Join-Path $RepositoryRoot ($directory.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "FULL_CHECK_INPUT_MISSING: $root" }
    }
    # Qualification outputs may live below these roots. Only Git-owned input
    # paths belong to the proof; source bytes are still read from the worktree.
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $start.WorkingDirectory = [IO.Path]::GetFullPath($RepositoryRoot)
    $start.Arguments = '-c core.quotepath=false ls-files --cached -z -- tests tools/tests adapters plugins/1c-rules content/openspec-bundle'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false, $true)
    $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false, $true)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $paths = $stdout.GetAwaiter().GetResult()
        $diagnostic = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "FULL_CHECK_INVENTORY_GIT_FAILED: exit=$($process.ExitCode); $diagnostic" }
        if ($paths -and -not $paths.EndsWith([string][char]0)) { throw 'FULL_CHECK_INVENTORY_GIT_FAILED: missing NUL path terminator.' }
        foreach ($relative in $paths.Split([char[]]@([char]0), [StringSplitOptions]::RemoveEmptyEntries)) {
            [void]$relativePaths.Add($relative)
        }
    } finally {
        $process.Dispose()
    }
    foreach ($relative in @('install.ps1', 'AGENTS.md', 'USER-RULES.md',
            'tools/validate-rules.ps1', 'tools/render-gate-evals.ps1',
            'tools/refresh-openspec-bundle.ps1', 'tools/apply-openspec-downstream-overlay.ps1',
            'content/skills/md-to-docx/package.json', 'content/skills/md-to-docx/package-lock.json',
            'scripts/check.ps1', 'scripts/full-check-contract.ps1', 'scripts/publish-fork-release.ps1')) {
        [void]$relativePaths.Add($relative)
    }
    $entries = @()
    $orderedPaths = [string[]]@($relativePaths)
    [Array]::Sort($orderedPaths, [StringComparer]::Ordinal)
    foreach ($relative in $orderedPaths) {
        $path = Join-Path $RepositoryRoot ($relative.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "FULL_CHECK_INPUT_MISSING: $path" }
        $entries += [ordered]@{
            path = $relative
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    return @($entries)
}

function Get-ForkFullRuntimeIdentity {
    $result = [ordered]@{}
    foreach ($name in @('powershell.exe', 'python.exe', 'node.exe', 'npm.cmd')) {
        $command = Get-Command $name -ErrorAction Stop | Select-Object -First 1
        $path = [IO.Path]::GetFullPath([string]$command.Source)
        $arguments = @('--version')
        if ($name -eq 'powershell.exe') {
            $arguments = @('-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
        }
        $version = @(& $path @arguments 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "FULL_CHECK_RUNTIME_VERSION_FAILED: $path" }
        $result[$name] = [ordered]@{
            path = $path
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            version = $version.Trim()
        }
    }
    $python = [string]$result['python.exe'].path
    $modules = @(& $python -B -c "import importlib.metadata as m; print('python-docx=' + m.version('python-docx')); print('lxml=' + m.version('lxml'))" 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "FULL_CHECK_PYTHON_DEPENDENCIES_MISSING: $modules" }
    $result['pythonModules'] = $modules.Trim()
    return $result
}

function Get-ForkRequiredFullStageNames {
    return @('git-diff-check', 'pester', 'runtime-identity') + @((Get-ForkFullStageCatalog) | ForEach-Object { [string]$_.name })
}
