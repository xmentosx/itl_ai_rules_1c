# Memory

This file is the working project memory for AI agents.

In a managed ITL project (`.agent-1c/project.json` exists), keep this
project-root file and project-scoped `1c-templates-mcp` memory. Do not route
project facts to Cognee or OpenViking without a separately qualified
project-scoped integration. Outside managed ITL projects, use Cognee-first
writes (then OpenViking, then templates MCP) and search across eligible
connected memory providers. Eligibility and fallback rules are in
`content/rules/project-memory.md` (`AGENTS.md → Project memory`).
There are no permanent entries yet.

Entry format (one entry = one self-contained rule). Use English for narrative,
preserve original 1C identifiers (objects, modules, attributes) as-is:

<!--
## YYYY-MM-DD — <short rule title>

- **Scope:** module / subsystem / object where the rule applies (e.g. `Документ.РеализацияТоваровУслуг`).
- **Rule:** what must / must not be done.
- **Why:** consequence of violation (production breakage / data loss / regulatory / data leak).
- **Source:** user request, incident, or external document that established the rule.
-->
