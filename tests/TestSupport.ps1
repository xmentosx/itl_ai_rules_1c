Set-StrictMode -Version Latest

$script:ForkRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function New-ForkTestRoot {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("itl-ai-rules-test-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    return $path
}

function Invoke-WindowsPowerShellFile {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $previousPreference = $ErrorActionPreference
    $previousConsoleEncoding = [Console]::OutputEncoding
    $ErrorActionPreference = "Continue"
    try {
        $utf8 = [Text.UTF8Encoding]::new($false)
        [Console]::OutputEncoding = $utf8
        $OutputEncoding = $utf8
        $output = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
        [Console]::OutputEncoding = $previousConsoleEncoding
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = ($output -join "`n")
    }
}

function Invoke-TestNativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    # Windows PowerShell 5.1 promotes redirected native stderr to an error
    # record under the Full runner's Stop preference. A nonzero exit is the
    # expected result in guard/invalid-input tests; keep the bytes and exit.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = ($output -join "`n") }
}
