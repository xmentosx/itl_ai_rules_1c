# 1c-code-check-mcp — tool catalog

1С:Напарник: code review and technical code checking, AI rewrite / modify, platform documentation by version, ITS standards, configuration documentation.

> Load this file only if the `1c-code-check-mcp` server is actually available in the current session.

## Code analysis & modification

| Tool | Purpose | When to use |
|---|---|---|
| **check_1c_code** | Technical check: syntax, logic, performance | After writing code — find bugs and performance issues |
| **check_1c_logic** *(conditional)* | Logic and performance check only; does not validate syntax | Preferred Gate 2 tool after standalone `syntaxcheck` / `syntaxcheck_file` passes on the same unchanged snapshot |
| **review_1c_code** | Code review: style, ITS standards, naming, structure | After writing code — verify standards compliance |
| **rewrite_1c_code** | AI rewrites code with improvements (optional `goal`: `optimize`, `readability`, `error handling`) | When code needs significant improvement. **Non-deterministic — mandatory re-validation** via applicable Gates 1–3 |
| **modify_1c_code** | Modify / generate code by explicit instruction | Targeted fixes, specific bug fixes, feature additions. **Non-deterministic — mandatory re-validation** |
| **ask_1c_ai** | Free-form question to 1С:Напарник (preserves dialog context) | Architectural questions, concept explanations, advice. **Non-deterministic — treat as a hint, not authority** |

## Documentation & knowledge base

| Tool | Purpose | When to use |
|---|---|---|
| **search_1c_documentation** | Search platform documentation for a specific version (`v8.3.25`) | Verify method signatures in a specific version, version-specific platform features |
| **onec_help** | Search platform documentation (latest version) | Quick lookup of features, methods, types |
| **its_help** | Search the ITS knowledge base (standards, methodology) | Find ITS standards, best practices. **Returns document IDs → use `fetch_its`** |
| **fetch_its** | Read the full content of an ITS document by ID | **Always after `its_help`** — read every found article. Special IDs: `root`, `v8std` |
| **diff_1c_documentation_versions** | Compare documentation between platform versions | Changes between versions (`v8.3.25` → `v8.5.1`) |
| **config_help** | Search documentation for specific configurations (ERP, БП, ЗУП, УТ) | Configuration-specific business logic, object descriptions |

## Key ITS workflow

`its_help` → get document IDs → `fetch_its` for each ID → read the full content. **Never ignore ITS article references without `fetch_its`.**

## Notes on AI tools

`ask_1c_ai`, `rewrite_1c_code`, `modify_1c_code` are non-deterministic. Their output is a draft hint, not authority. Generated / rewritten code is **always** re-validated through applicable Gates 1–3 on the closing snapshot.

## Call limit

`check_1c_logic`, `check_1c_code`, and `review_1c_code` are closing-snapshot validators, not per-edit feedback. Build one coherent validation unit per touched module (whole module when it fits; otherwise non-overlapping changed routines plus required context), obtain standalone syntax evidence first, call the exposed Gate 2 tool once after implementation, then call `review_1c_code` once only after logic validation passes. Do not send same-server validator calls through `Promise.all`, do not validate overlapping snippets, and never re-call unchanged code.

Prefer `check_1c_logic` for Gate 2 when it is exposed. It never calls the syntax checker and does not accept syntax evidence as an argument; ordering and freshness are owned by `verification-gates.md`. Use `check_1c_code` only as the compatibility fallback when the logic-only tool is absent. A blocking result (`critical` / `error` for the active Gate 2 tool, `error` for `review_1c_code`, or a reported logic / metadata / data-integrity / security / transaction / lock / performance-critical defect) must be fixed and followed by a clean confirming run. `full` allows 3 calls total per validator; `standard` allows the initial call plus one confirmation (2 total); promotion-trigger changes always use `full`. Style warnings, naming nits, and BSLLS noise do **not** justify re-running the same AI validator. If the budget ends without a clean confirmation after a blocking fix, the gate fails and the module remains unverified. For pure metadata-XML changes with no BSL touched, these tools are usually irrelevant — use `verify_xml`. Full policy: `verification-gates.md`.
