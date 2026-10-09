---
name: 1c-live-ib
description: "Answer what only the running infobase knows — query parsing, current data, a BSL fragment or event-log error — through the eligible scoped provider. Managed branches prefer ROCTUP; the HTTP data service is conditional. Read-only by default; mutations need explicit consent."
argument-hint: "<query text | bsl fragment | lasterror>"
allowed-tools: mcp__itl-roctup-data__resolve_tool, mcp__itl-roctup-data__call_tool, mcp__1c-data-mcp__validatequery, mcp__1c-data-mcp__vcvalidatequery, mcp__1c-data-mcp__vcexecutequery, mcp__1c-data-mcp__vcexecutecode, mcp__1c-data-mcp__vcloggetlasterror
---

# 1c-live-ib — the running infobase

Escalate here only when the configuration dump, the static validators and the docs cannot answer: "does it run *now* in *this* IB". Never a replacement for `1c-validate`. Available only when the tools are exposed in the session; a configured URL proves nothing, and fake "execution output" is a defect.

For an ITL-managed dev/test branch, use `.agents/skills/itl-roctup-1c-data/SKILL.md`: filtered metadata first, then a bounded read-only query through the existing facade on the exact branch infobase. The facade owns guard, attachment and cleanup; do not launch processes or call private HTTP. Do not turn query permission into code execution, restart or publication permission. Conditional HTTP fallback, actual argument schemas and error/empty-result handling: `content/skills/mcp-1c-tools/docs/1c-data-mcp.md → Select the actual provider`.

## Tools and exact arguments

| Need | Call | Arguments | Pass criterion |
|---|---|---|---|
| Does the query parse | Exposed `validatequery` (ITL XML) / `vcvalidatequery` (HTTP) | Actual provider schema; HTTP: `querytext` | `"нет ошибок"` — parse only, no metadata or RLS check |
| What does it return on real data | Managed ROCTUP `execute_query`; conditional HTTP `vcexecutequery` | Actual schema and bounded result; HTTP: `querytext` with embedded parameters | Compare expected and observed values; successful empty result is distinct from error |
| Does the fragment run on this platform | `vcexecutecode` | `bslcode`; assign `Результат = …` to get a value back | `"ошибок нет"` or the error text |
| Last error in the event log | `vcloggetlasterror` | — (24 h window, level `Ошибка`, one record) | formatted record or `"ошибок не найдено"` |

## HTTP provider calls

These examples require the named tools and exact argument schema to be exposed. Use `validatequery` instead of `vcvalidatequery` only when that legacy parser is the actual exposed tool. ROCTUP calls follow its managed skill.

```json
{"tool": "vcvalidatequery", "args": {"querytext": "ВЫБРАТЬ Т.Ссылка ИЗ Справочник.Контрагенты КАК Т ГДЕ Т.ИНН = \"7701234567\""}}
{"tool": "vcexecutequery", "args": {"querytext": "ВЫБРАТЬ ПЕРВЫЕ 5 Т.Ссылка, Т.ИНН ИЗ Справочник.Контрагенты КАК Т"}}
{"tool": "vcexecutecode", "args": {"bslcode": "Результат = Строка(Метаданные.Справочники.Контрагенты.Реквизиты.ИНН.Тип.КвалификаторыСтроки.Длина);"}}
{"tool": "vcloggetlasterror", "args": {}}
```

## Safety

- Read-only first: metadata-first bounded ROCTUP in managed branches; exposed query parser → read-only query on the HTTP route. Execution alone is not a parser pass. Record exact infobase/provider, query scope, expected and actual result; no metadata-only or ambiguous-empty pass.
- No `Записать()`, `Удалить()`, `НачатьТранзакцию`, register movements without asking the user, naming the object and having a rollback plan; on a production IB (`.dev.env` `INFOBASE_ROLE=prod`) refuse and request a copy.
- No secrets or personal data in `bslcode` / `querytext` — they travel over HTTP and may be logged.
- Validate AI-generated text first (actually exposed query parser, `syntaxcheck`), then run it here within the eligible provider's policy.
- Gate 3a (`content/rules/verification-gates.md`) uses only the read-only tools.

Where it sits in the playbooks: error fixing step 2 and 6, performance step 5, new-code step 5 — `content/rules/tooling-playbooks.md`. Setup and 401/403 troubleshooting — `content/commands/checkmcp.md`. Details: `content/skills/mcp-1c-tools/docs/1c-data-mcp.md`.
