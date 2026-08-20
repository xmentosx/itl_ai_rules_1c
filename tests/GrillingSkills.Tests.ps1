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
}
