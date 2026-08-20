Set-StrictMode -Version Latest

function Find-ItlManagedProjectRoot {
    [CmdletBinding()]
    param([string[]]$StartPaths)

    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($startPath in @($StartPaths)) {
        if ([string]::IsNullOrWhiteSpace($startPath)) { continue }
        try {
            $current = [System.IO.DirectoryInfo]::new([System.IO.Path]::GetFullPath($startPath))
        }
        catch {
            continue
        }
        while ($null -ne $current) {
            if ($visited.Add($current.FullName)) {
                $marker = Join-Path $current.FullName ".agent-1c\project.json"
                if (Test-Path -LiteralPath $marker -PathType Leaf) { return $current.FullName }
            }
            $current = $current.Parent
        }
    }
    return $null
}

function Assert-ItlLifecycleOwnership {
    [CmdletBinding()]
    param([string]$ScriptName = $MyInvocation.ScriptName)

    $managedRoot = Find-ItlManagedProjectRoot -StartPaths @((Get-Location).Path, $PSScriptRoot)
    if (-not $managedRoot) { return }
    $name = if ([string]::IsNullOrWhiteSpace($ScriptName)) { "lifecycle script" } else { $ScriptName }
    throw "ITL_LIFECYCLE_HELPER_REQUIRED: '$name' cannot run directly inside managed ITL project '$managedRoot'. Use the matching /itl* bridge or host lifecycle helper so the proven branch infobase, rollback state, publication, and fresh verification remain workflow-owned."
}
