---
description: Delta-aware MCP-first search discipline — the current worktree is mandatory for branch-local changes, while unchanged baseline source uses bounded project-index MCP discovery before native fallback. Load before any code / metadata / usage / file-location search in a 1C project.
alwaysApply: false
globs: ["**/*.bsl", "**/*.xml"]
category: tooling
---

# MCP-first search discipline

For any 1C **project-source search** (code, metadata, usages, call chains, structure, forms, layouts, **and locating the source files themselves**) first determine which source can cover the target. The current worktree comes first for branch-local changes; project-index MCP comes first for unchanged baseline source. Native discovery outside the branch delta remains a bounded fallback, not an equal alternative to structural search.

**What counts as search.** Any action whose goal is to *locate* code, metadata, or files you do not yet have an exact path or qualified name for — including "getting oriented" sweeps at the start of a task (globbing the source tree, listing directories, reading modules one after another to see what is there). All of it falls under the hard rule below. Reading a specific file **already located via MCP** — to edit it, or to see a found fragment in full context — is normal work, not search, and needs no justification.

Applies to every subagent except `1c-explorer`, which already encodes the same rule in its own prompt. The canonical fallback chain owner is `content/skills/mcp-1c-tools/SKILL.md → Fallback chain → Project-source search before Grep / Glob / rg`. This file does not redefine it — it makes the rule salient inside subagent prompts that previously only had a soft pointer.

---

## Hard rule

1. **Establish branch scope once.** Before the first project-source search in a non-baseline development branch, you MUST build or reuse one cheap path-only delta against the project's local baseline branch (`master` in ITL-managed projects). Include committed, staged, unstaged, and untracked source paths. Git path output MUST use `core.quotepath=false` and NUL delimiters. Do not fetch, hash file contents, calculate a fingerprint, persist a new state file, or repeat the delta while branch state is unchanged. If the project has no usable baseline ref, known current-task and worktree edits still form the local delta and search MUST continue without inventing a freshness probe.
2. **Branch delta is local-first.** If the target file or object is in that delta, or is already known to have been created, renamed, or changed in the branch, you MUST search and read the current worktree first. You MUST NOT call a remote project index to establish that target's existence, absence, path, or current contents. For an unknown exact identifier that may be branch-local, search the cached delta paths before asking the remote index. The worktree is authoritative for this scope.
3. **Untouched baseline is bounded MCP-first.** Outside the branch delta, you MUST call the single best-fitting exposed project-index tool before native discovery: a graph tool for structural/impact questions or a code-metadata tool for code, form, and exact-name navigation. If that lookup is insufficient, make at most one substantively changed retry for the same search intent; `grep=true` is one possible retry on tools that expose it. Then you MUST fall back to local discovery. An MCP miss is never proof that code or metadata is absent.
4. **Mixed questions keep both routes.** Inspect the branch-local side from disk and use MCP for unchanged baseline structure or dependencies. One route MUST NOT replace the other. A different MCP call is allowed when it closes a different concrete evidence gap; it is not a retry of the same search intent.
5. **Unavailable means immediate fallback.** If the applicable MCP tool is not exposed, or its substantive call fails, use local discovery immediately. Do not enter discovery, health, restart, or reindex loops merely to satisfy this rule.
6. **No-change repeats are forbidden.** Do not repeat a Git delta or MCP call against unchanged state. A repeated lookup MUST change parameters substantively or follow a material source/session change.

External-knowledge servers (`1c-templates-mcp`, `1c-ssl-mcp`, `1C-docs-mcp`, `1c-code-check-mcp`, `1c-syntax-checker-mcp`, `1c-data-mcp`) have **no `Grep` / `rg` equivalent** — they are called only when their knowledge is needed, not as part of the fallback above.

---

## Full-file `Read` — fragment first

`Read` of a whole BSL module to *find or understand one routine* is the same fallback as `Grep`. When the need is a fragment — retrieve at fragment level first: `get_module_structure(module_path)` for the layout, `search_code` (`detail_level="L0"`) or `search_function` for the full body of a specific routine, `bsl_scope_members` for available members of a context.

Full-file `Read` is **normal work** — no MCP attempt, no justification note — when:

- the file is your **direct edit target** (reading before editing is mandatory, not a fallback);
- the file is small (a few screens) — slicing it via MCP costs more than reading it;
- the file belongs to the cached branch delta or you (or the user) just edited it — the disk state is authoritative;
- whole-module context genuinely is the task (module-wide review, refactor, region restructuring);
- the fragment returned by MCP is truncated or insufficient and full context is needed to proceed.

---

## Quick first-pick table for untouched baseline source

| Need | First call (MCP) | If empty — next |
|---|---|---|
| Find BSL code by behaviour / description | `search_code` (`semantic`, `detail_level=L1`) | `search_code` (`hybrid`) → `codesearch` |
| Find BSL code by exact identifier / literal | `search_code` (`fulltext`) | `codesearch(grep=true)` → only then `Grep` |
| Find a routine by name | `search_function(name, exact=true)` | `search_function(grep=true)` → `Grep` |
| Understand a metadata object | `get_object_dossier(object_name=...)` | `get_metadata_details(object_name=...)` |
| Metadata search by name / structure | `search_metadata` (JSON template) | `metadatasearch` (`names_only=true`) |
| Metadata search by Russian description / synonym | `search_metadata_by_description` or `business_search` | `metadatasearch` |
| Usages of an object | `find_usages_of_object(object_name=...)` / `find_objects_using_object(object_name=...)` | `graph_dependencies(object_name=..., direction="reverse")` |
| Impact of an object change | `trace_impact(object_name=..., direction="downstream", depth=3)` | `graph_dependencies(object_name=...)` (single-level) |
| Call graph (who calls / who is called) | `trace_call_chain(routine_name=..., object_name=..., direction="callers" \| "callees", depth=3)` | `get_method_call_hierarchy(method_name=...)` |
| Locate the source files / modules of an object | `get_object_dossier(object_name=...)` (paths in the passport) → `get_module_structure(module_path)` | `search_metadata` / `metadatasearch(names_only=true)` |
| "Get oriented" in an unfamiliar configuration | `search_metadata` (list by category) / `business_search` | `metadatasearch(names_only=true)` — **not** `Glob **/*.bsl` |
| Module structure overview | `get_module_structure(module_path)` | `inspect_form_layout` for forms |
| Form layout | `inspect_form_layout(object_name)` | `search_forms` |
| Canonical pattern / template | **`templatesearch` only** — task description verbatim; pre-flight `1c-templates-mcp.md → Query formulation (templatesearch only)` (`AGENTS.md → A.8`) (+ `ssl_search` for БСП) | — |
| Platform API verification | `docinfo(name)` or `docsearch(query)` | `helpsearch` |
| Does the platform ship a mechanism for X (СЛАУ, crypto, data analysis, bus, bots, …)? | `docsearch(capability description)` → `docinfo` per found name (`AGENTS.md → A.7`) | `ssl_search` for a БСП-level solution |
| ITS standards | `its_help(query)` → `fetch_its(id)` for **every** relevant doc | — |

Native discovery tools (`Grep`, `Glob` / file search, directory listing, bulk `Read`) are absent from this table on purpose — they are not a first pick for any of these needs.

---

## When `Grep` / `Glob` / `Read` are legitimately the right tool

This rule is a **bounded priority, not a prohibition** — the agent must always stay operational without MCP and must be free to search on its own after an MCP miss. Native tools are appropriate, with no need for an MCP attempt first, when:

- the project-index MCP servers (`1c-graph-metadata-mcp`, `1c-code-metadata-mcp`) are **not exposed** in the current session — the whole chain collapses; work with native tools normally and state the unavailability once, in one line;
- the target belongs to the cached branch delta — use targeted local discovery first and do not spend a remote lookup on its existence or current contents;
- an MCP result **looks wrong or stale** (contradicts known facts or the current disk state) — verify or override it against the worktree immediately;
- the target is **outside the MCP index**: non-BSL / non-metadata files (`.md` documentation, `.json` / `.yaml` configs, slash-command sources, rule files, `openspec/` artifacts, deployment logs), text fixtures, sample payloads, generated reports under `handoffs/` / `dist/` / build output;
- a file you have already read in this session and are scanning for a literal string locally;
- reading a file whose path came from an MCP result (edit target, full context of a found fragment) — see also *Full-file `Read` — fragment first* above.

And after the best-fitting MCP attempt plus at most one substantively changed retry for the same intent **missed** — fall back immediately with the one-line "what was tried" note; no further equivalent MCP calls are owed to this rule.

In all remaining 1C project-source cases — follow the hard rule above.

---

## Response gate

Before delivering a result that involved native discovery on project source, include a short authority/fallback line. For branch-local scope, name the local delta instead of inventing failed MCP attempts; for untouched baseline fallback, state what MCP lookup missed, e.g.:

> *`<Object>` is in the local branch delta, so its current source was read from the worktree; MCP was used only for unchanged dependencies.*
>
> *Tried `codesearch(query="...")` (empty), `search_function(name="...", exact=true)` (no match); fell back to `Grep` for the literal `<...>`.*

One or two sentences. No bullet list of every parameter tried.

---

## Success criteria

- ✅ One path-only local-baseline delta was built or reused before the first development-branch source search; committed, staged, unstaged, and untracked source paths were covered without fingerprints or fetches.
- ✅ Branch-delta targets were searched locally first and were not looked up remotely to establish existence, absence, path, or current contents.
- ✅ Untouched baseline source used the best-fitting exposed MCP tool before native discovery.
- ✅ No "getting oriented" sweeps (source-tree globbing, bulk module reading) while project-index MCP servers are exposed.
- ✅ Fragment-level retrieval preferred over full-module `Read` when the need is one routine — outside the normal-work cases listed above.
- ✅ The same search intent used at most one substantively changed retry; distinct calls closed distinct evidence gaps.
- ✅ After a missed MCP attempt — or with servers not exposed — fallback proceeded immediately; no ritual MCP calls made only to satisfy this rule.
- ✅ Local authority or native fallback was justified inline.
- ✅ No duplicated calls against unchanged state.
