BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSupport.ps1')
    $installer = Get-Content -LiteralPath (Join-Path $script:ForkRoot 'install.ps1') -Raw -Encoding UTF8
    $prefix = $installer.Substring(0, $installer.IndexOf('# SECTION 14: MAIN DISPATCH'))
    . ([scriptblock]::Create($prefix)) -Command doctor -McpMode delegated -AssumeYes -NonInteractive
    Set-StrictMode -Off

    function New-PlacementFixture {
        param([string]$BasePath)
        $source = Join-Path $BasePath 'source'
        $root = Join-Path $BasePath 'Проект с пробелом'
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        foreach ($section in @('rules','agents','commands','skills')) {
            New-Item -ItemType Directory -Force -Path (Join-Path $source "content/$section") | Out-Null
        }
        Write-TextFile -Path (Join-Path $source 'content/rules/test.md') -Content "---`ndescription: example`n---`nRule body`n"
        Write-TextFile -Path (Join-Path $source 'content/skills/example/SKILL.md') -Content "---`nname: example`n---`nSee content/rules/test.md`n"
        return [pscustomobject]@{root=$root;source=$source}
    }

    function New-SharedPlacementAdapter {
        return @{
            rules = @{copyTo='shared/rules/{name}.md';mode='verbatim';frontmatter=$null;template=$null}
            agents=$null; commands=$null; entry=$null
            skills = @{copyTo='shared/skills/{name}'}
        }
    }
}

Describe 'Installer final client contribution plan' {
    It 'merges identical shared rule and skill contributions with every owner' {
        $fixture = New-PlacementFixture -BasePath (Join-Path $TestDrive 'identical')
        $adapters = @{'claude-code'=(New-SharedPlacementAdapter); 'command-code'=(New-SharedPlacementAdapter)}
        $manifest = [ordered]@{tools=@('claude-code','command-code');files=[ordered]@{}}
        Invoke-PlacePhase -Root $fixture.root -SourceRoot $fixture.source -ActiveTools $manifest.tools -Adapters $adapters -Manifest $manifest
        @($manifest.files['shared/rules/test.md'].owners) | Should -Be @('claude-code','command-code')
        @($manifest.files['shared/skills/example/SKILL.md'].owners) | Should -Be @('claude-code','command-code')
        (Read-TextFile (Join-Path $fixture.root 'shared/skills/example/SKILL.md')) | Should -Match 'shared/rules/test.md'
    }

    It 'rejects different desired bytes before the first rule or skill write' {
        $fixture = New-PlacementFixture -BasePath (Join-Path $TestDrive 'different')
        $second = New-SharedPlacementAdapter
        $second.rules.mode = 'transform'
        $second.rules.frontmatter = @{drop=@('description')}
        # Only commands support adapter inclusion filters. An ignored rules
        # field must not hide bytes the real placement will still write.
        $second.rules.include = @('does-not-suppress-rules')
        $adapters = @{'claude-code'=(New-SharedPlacementAdapter); 'command-code'=$second}
        $manifest = [ordered]@{tools=@('claude-code','command-code');files=[ordered]@{}}
        { Invoke-PlacePhase -Root $fixture.root -SourceRoot $fixture.source -ActiveTools $manifest.tools -Adapters $adapters -Manifest $manifest } | Should -Throw '*INSTALLER_CLIENT_CONTRIBUTION_CONFLICT*repeat the original installer command*'
        @(Get-ChildItem -LiteralPath $fixture.root -Recurse -File).Count | Should -Be 0
        $manifest.files.Count | Should -Be 0
        $manifest.Contains('modelTiersByClient') | Should -BeFalse
        # The original operation succeeds after resolving the adapter conflict.
        $second.rules.mode = 'verbatim'
        Invoke-PlacePhase -Root $fixture.root -SourceRoot $fixture.source -ActiveTools $manifest.tools -Adapters $adapters -Manifest $manifest
        Test-Path -LiteralPath (Join-Path $fixture.root 'shared/rules/test.md') | Should -BeTrue
    }

    It 'checks retained owners when add places only the incoming client' {
        $fixture = New-PlacementFixture -BasePath (Join-Path $TestDrive 'add')
        $adapters = @{'claude-code'=(New-SharedPlacementAdapter); 'command-code'=(New-SharedPlacementAdapter)}
        $manifest = [ordered]@{tools=@('claude-code');files=[ordered]@{}}
        Invoke-PlacePhase -Root $fixture.root -SourceRoot $fixture.source -ActiveTools @('claude-code') -Adapters $adapters -Manifest $manifest
        $path = Join-Path $fixture.root 'shared/rules/test.md'
        $before = Get-FileSha256 $path
        $manifestBefore = $manifest | ConvertTo-Json -Depth 20 -Compress
        $adapters['command-code'].rules.mode = 'transform'
        $adapters['command-code'].rules.frontmatter = @{drop=@('description')}
        { Invoke-PlacePhase -Root $fixture.root -SourceRoot $fixture.source -ActiveTools @('command-code') -Adapters $adapters -Manifest $manifest } | Should -Throw '*INSTALLER_CLIENT_CONTRIBUTION_CONFLICT*'
        (Get-FileSha256 $path) | Should -Be $before
        ($manifest | ConvertTo-Json -Depth 20 -Compress) | Should -Be $manifestBefore
    }

    It 'retains explicitly user-modified shared content during the plan and placement' {
        $fixture = New-PlacementFixture -BasePath (Join-Path $TestDrive 'user')
        $path = Join-Path $fixture.root 'shared/rules/test.md'
        Write-TextFile -Path $path -Content 'User-authored rule'
        $adapters = @{'claude-code'=(New-SharedPlacementAdapter); 'command-code'=(New-SharedPlacementAdapter)}
        $adapters['command-code'].rules.mode = 'transform'
        $adapters['command-code'].rules.frontmatter = @{drop=@('description')}
        $manifest = [ordered]@{tools=@('claude-code','command-code');files=[ordered]@{
            'shared/rules/test.md'=[ordered]@{source='content/rules/test.md';installedHash=(Get-FileSha256 $path);userModified=$true;owners=@('claude-code')}
        }}
        Invoke-PlacePhase -Root $fixture.root -SourceRoot $fixture.source -ActiveTools $manifest.tools -Adapters $adapters -Manifest $manifest
        (Read-TextFile $path) | Should -Be 'User-authored rule'
        $manifest.files['shared/rules/test.md'].userModified | Should -BeTrue
        @($manifest.files['shared/rules/test.md'].owners) | Should -Be @('claude-code','command-code')
    }

    It 'renders the complete twelve-client delegated plan without writing project files' {
        $root = Join-Path $TestDrive 'Все двенадцать клиентов'
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        $clients = @('codex','kilocode','claude-code','cursor','opencode','kimi','qwen','command-code','cline','pi','zcode','mimocode')
        $adapters = Load-Adapters -SourceRoot $script:ForkRoot -Tools $clients
        $layouts = Resolve-CanonicalArtifactLayouts -ActiveTools $clients -Adapters $adapters
        $manifest = [ordered]@{tools=$clients;files=[ordered]@{}}
        Assert-InstallerPlacementFinalSet -Root $root -SourceRoot $script:ForkRoot -ActiveTools $clients -Adapters $adapters -Manifest $manifest -Layouts $layouts
        @(Get-ChildItem -LiteralPath $root -Recurse -File).Count | Should -Be 0
        $manifest.files.Count | Should -Be 0
    }

    It 'excludes Python bytecode from both shared-client preflight and actual skill placement' {
        $fixture = New-PlacementFixture -BasePath (Join-Path $TestDrive 'Python кэш с пробелом')
        Write-TextFile -Path (Join-Path $fixture.source 'content/skills/example/SKILL.md') -Content "---`nname: example`n---`nSame skill body`n"
        Write-TextFile -Path (Join-Path $fixture.source 'content/skills/example/scripts/run.py') -Content "print('owned source')`n"
        # If bytecode entered the shared-target plan, these content references
        # would render differently for the two owners and falsely block install.
        foreach ($relative in @('scripts/stale.pyc','scripts/__pycache__/run.cpython-313.pyc','scripts/__pycache__/notes.txt')) {
            Write-TextFile -Path (Join-Path $fixture.source "content/skills/example/$relative") -Content 'content/rules/test.md'
        }
        $first = New-SharedPlacementAdapter
        $second = New-SharedPlacementAdapter
        $first.rules.copyTo = 'first/rules/{name}.md'
        $second.rules.copyTo = 'second/rules/{name}.md'
        $adapters = @{'claude-code'=$first; 'command-code'=$second}
        $manifest = [ordered]@{tools=@('claude-code','command-code');files=[ordered]@{}}
        Invoke-PlacePhase -Root $fixture.root -SourceRoot $fixture.source -ActiveTools $manifest.tools -Adapters $adapters -Manifest $manifest
        @($manifest.files.Keys | Where-Object { $_ -like 'shared/skills/*' }) | Should -HaveCount 2
        @($manifest.files['shared/skills/example/SKILL.md'].owners) | Should -Be @('claude-code','command-code')
        @($manifest.files['shared/skills/example/scripts/run.py'].owners) | Should -Be @('claude-code','command-code')
        @(Get-ChildItem -LiteralPath (Join-Path $fixture.root 'shared/skills') -Recurse -File | Where-Object {
            $_.Extension -eq '.pyc' -or $_.FullName -match '[\\/]__pycache__[\\/]'
        }).Count | Should -Be 0
    }
}
