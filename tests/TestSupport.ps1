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
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $FilePath @Arguments 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n")
    }
}
