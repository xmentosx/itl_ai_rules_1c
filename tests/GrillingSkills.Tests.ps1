BeforeAll {
    . (Join-Path $PSScriptRoot "TestSupport.ps1")
}

Describe "Grilling skill family" -Tag "Fast" {
    It "ships complete portable aliases and domain-modeling resources" {
        $skills = Join-Path $script:ForkRoot "content\skills"
        foreach ($path in @(
            "grilling\SKILL.md",
            "grilling\agents\openai.yaml",
            "grill-me\SKILL.md",
            "grill-me\agents\openai.yaml",
            "grill-with-docs\SKILL.md",
            "grill-with-docs\agents\openai.yaml",
            "domain-modeling\SKILL.md",
            "domain-modeling\CONTEXT-FORMAT.md",
            "domain-modeling\ADR-FORMAT.md",
            "domain-modeling\agents\openai.yaml"
        )) {
            Test-Path -LiteralPath (Join-Path $skills $path) -PathType Leaf | Should -BeTrue -Because $path
        }

        $grillMe = Get-Content -LiteralPath (Join-Path $skills "grill-me\SKILL.md") -Raw -Encoding UTF8
        $grillMe | Should -Match ([regex]::Escape("../grilling/SKILL.md"))
        $grillWithDocs = Get-Content -LiteralPath (Join-Path $skills "grill-with-docs\SKILL.md") -Raw -Encoding UTF8
        $grillWithDocs | Should -Match ([regex]::Escape("../grilling/SKILL.md"))
        $grillWithDocs | Should -Match ([regex]::Escape("../domain-modeling/SKILL.md"))
        foreach ($alias in @("grill-me", "grill-with-docs")) {
            $policy = Get-Content -LiteralPath (Join-Path $skills "$alias\agents\openai.yaml") -Raw -Encoding UTF8
            $policy | Should -Match ('display_name:\s*"' + [regex]::Escape($alias) + '"')
            $policy | Should -Match 'allow_implicit_invocation:\s*false'
        }
    }

    It "preserves frontier rounds while integrating ITL facts and planning routes" {
        $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot "content\skills\grilling\SKILL.md") -Raw -Encoding UTF8
        $text | Should -Match "Ask the whole frontier in one round"
        $text | Should -Match "Finding _facts_ is your job"
        $text | Should -Match "project-specific read-only explorer"
        $text | Should -Match "If the user says to stop"
        $text | Should -Match 'planningMode=OpenSpec'
        $text | Should -Match 'executionPath'
        $text | Should -Match "instead of creating a parallel specification format"
    }

    It "keeps the glossary complementary to product docs and OpenSpec" {
        $text = Get-Content -LiteralPath (Join-Path $script:ForkRoot "content\skills\domain-modeling\SKILL.md") -Raw -Encoding UTF8
        $text | Should -Match "product-documentation routing"
        $text | Should -Match "surface the conflict immediately"
        $text | Should -Match 'CONTEXT\.md.*not a replacement.*OpenSpec'
        $text | Should -Match 'update .*CONTEXT\.md.* right there'
        $text | Should -Match "all three are true"
    }

    It "ships thin native command wrappers through the upstream command adapters" {
        $commands = Join-Path $script:ForkRoot "content\commands"
        foreach ($name in @("grill-me", "grill-with-docs")) {
            $wrapper = Get-Content -LiteralPath (Join-Path $commands "$name.md") -Raw -Encoding UTF8
            $wrapper | Should -Match ('Activate the installed `' + [regex]::Escape($name) + '` skill')
            $wrapper | Should -Match "only a native-command wrapper"
            $wrapper.Length | Should -BeLessThan 700
        }

        $nativeClients = @("kilocode", "claude-code", "cursor", "opencode", "qwen", "command-code")
        foreach ($client in $nativeClients) {
            $adapter = Get-Content -LiteralPath (Join-Path $script:ForkRoot "adapters\$client.yaml") -Raw -Encoding UTF8
            $adapter | Should -Match 'commands:'
            $adapter | Should -Match 'copyTo:'
        }
    }

    It "installs both wrappers at every native command path" {
        $testRoot = New-ForkTestRoot
        $commandRoots = [ordered]@{
            "kilocode" = ".kilo\commands"
            "claude-code" = ".claude\commands"
            "cursor" = ".cursor\commands"
            "opencode" = ".opencode\command"
            "qwen" = ".qwen\commands"
            "command-code" = ".commandcode\commands"
        }
        try {
            foreach ($client in $commandRoots.Keys) {
                $projectRoot = Join-Path $testRoot $client
                New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
                $result = Invoke-WindowsPowerShellFile -FilePath (Join-Path $script:ForkRoot "install.ps1") -Arguments @(
                    "init", "-ProjectRoot", $projectRoot, "-Source", $script:ForkRoot,
                    "-Tools", $client, "-NonInteractive", "-AssumeYes", "-McpMode", "delegated"
                )
                $result.ExitCode | Should -Be 0 -Because $result.Output
                foreach ($name in @("grill-me", "grill-with-docs")) {
                    Test-Path -LiteralPath (Join-Path (Join-Path $projectRoot $commandRoots[$client]) "$name.md") -PathType Leaf |
                        Should -BeTrue -Because "$client should install /$name"
                }
            }
        } finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
