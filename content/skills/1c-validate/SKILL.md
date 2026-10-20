---
name: 1c-validate
description: "Validate changed 1C artifacts — BSL by path (BSL Language Server), logic and performance (1С:Напарник check), style and ITS review, metadata XML against XSD — within the verification-policy budget. Use after every BSL or metadata edit."
argument-hint: "<module path | xml> [lines]"
allowed-tools: mcp__1c-syntax-checker-mcp__syntaxcheck_file, mcp__1c-syntax-checker-mcp__syntaxcheck, mcp__1c-code-check-mcp__check_1c_logic, mcp__1c-code-check-mcp__check_1c_code, mcp__1c-code-check-mcp__review_1c_code, mcp__1c-code-metadata-mcp__verify_xml
---

# 1c-validate — the validator chain

Order for touched BSL: standalone `syntaxcheck_file` → preferred `check_1c_logic` (fallback `check_1c_code`) → `review_1c_code`, selecting only the gates required by `VERIFICATION_DEPTH` and task path under `content/rules/verification-policy.md → Validator budget`. Before editing or blocking on AI findings, apply `content/rules/verification-ai-evidence.md`; confirmed defects need fresh applicable proof after correction. AI timeout in `auto` uses compensation and continuation with an unverified AI gate; `required` still blocks its dependent step. Default 2/3 counts are diagnostic checkpoints; necessary continuation needs no numeric-budget question. Preserve explicit limits, unknown-completion protection and the single unusable-response recovery. Gate 3 explicitly requested at `lite` follows Gate 1 even if Gate 2 is unselected. Pure metadata XML without BSL: `verify_xml` once. Gate selection — `content/rules/verification-gates.md`.

## Tools and exact arguments

| Gate | Call | Arguments |
|---|---|---|
| 1 Syntax — saved file (default) | `syntaxcheck_file` | `file_path` relative to the mounted sources root, optional `lines="5, 10-20"` — save first; a failed path is retried once, then fall back to text |
| 1 Syntax — text (fallback) | `syntaxcheck` | `code` — only when the file tool is not exposed or the fragment has no file yet; confirm by path once written |
| 2 Logic & performance | `check_1c_logic` preferred | Read the live exposed schema; never guess arguments |
| 2 fallback | `check_1c_code` | exactly one of `code` or `files` (list of saved paths under the declared workspace roots) |
| 3 Style & ITS | `review_1c_code` | same shape as `check_1c_code` |
| 5 Metadata XML | `verify_xml` | `xml_content`, `object_type` (`Справочник`, `Документ`, `Форма`, `Роль`, `СКД`, `Макет`) |

`syntaxcheck` and `syntaxcheck_file` are one validator for budgeting. A Code Checker syntax section cannot replace standalone Gate 1. Never feed syntax-broken code to the AI validators. Collect the coherent closing snapshot first; no AI validator after intermediate edits or same-server parallel calls.

## Calls

```json
{"tool": "syntaxcheck_file", "args": {"file_path": "Documents/РеализацияТоваровУслуг/Ext/ObjectModule.bsl", "lines": "120-185"}}
{"tool": "check_1c_code", "args": {"files": ["Documents/РеализацияТоваровУслуг/Ext/ObjectModule.bsl"]}}
{"tool": "review_1c_code", "args": {"files": ["Documents/РеализацияТоваровУслуг/Ext/ObjectModule.bsl"]}}
{"tool": "verify_xml", "args": {"object_type": "Справочник", "xml_content": "<MetaDataObject …>"}}
```

## Reading the answers

- Blocking: any `error` from syntax; `critical` / `error` from check; `error` from review; a logic, data-integrity, security, transaction or performance defect named by the validator. Style noise never starts another AI pass.
- `provenance.index` on a syntax answer says what a clean report proves: `absent` / `building` / `failed` = syntax and local rules only; `ready` = cross-module resolution included. Read it, never wait for it.
- A check of a large module may run for minutes; the server retries transport failures itself — do not resend.
- Rewrites from `rewrite_1c_code` / `modify_1c_code` are drafts and re-enter this chain.
- A missing validator is graceful degradation with a `Risk:` line, never a silent skip. Typed answers map to actions by code — `content/rules/mcp-policy.md → C. Server answers → actions`.

Details: `content/skills/mcp-1c-tools/docs/1c-syntax-checker-mcp.md`, `content/skills/mcp-1c-tools/docs/1c-code-check-mcp.md`, `content/skills/mcp-1c-tools/docs/1c-code-metadata-mcp.md → XSD schemas & validation`.
