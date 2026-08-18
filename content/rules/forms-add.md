---
description: Generating or significantly altering a managed 1C form (`Form.xml` + `Form.Module.bsl`), including form-presentation rules — programmatic modification of typical forms, element placement, fill checking, form commands. Load from `forms.md` for any form-creation or form-presentation task.
alwaysApply: false
category: forms
---

# Adding or Modifying a Managed Form

This file owns the **rules**, not the MCP sequence. The pre-edit and post-edit MCP playbooks live in:

- `tooling-playbooks.md → Form Analysis and Generation` — full ordered list of MCP calls (`search_forms` → `inspect_form_layout` → `metadatasearch` → `get_xsd_schema` → write/modify XML → `verify_xml` → compile via the `1c-metadata-manage` skill).

Do not duplicate that sequence here.

## Rules specific to creating / modifying a form

- **The `1c-metadata-manage` skill (form-manage section) is the mandatory execution path** for creating or structurally modifying `Form.xml` — hard gate per `AGENTS.md → Skills and Subagents`; the skill drives the toolchain (BOM, encoding, UID generation, ordering of `ChildObjects`). Adding, removing, moving, nesting, or changing the type of elements in an existing `Form.xml` must use `1c-form-edit` when that operation is supported; line count and apparent simplicity do not make structural XML insertion a manual one-line fix. Hand-editing is limited to the documented literal-value or unsupported-repair exceptions, and the report must state why the form tool did not apply.
- **Table and tree row changes.** For every added `Table` (including a tree backed by `ValueTree`), explicitly decide whether users may change the row set and row order through standard platform actions. If direct editing is not intended, or changes are available only through project commands, set both `changeRowSet: false` and `changeRowOrder: false`. Hiding or clearing the command bar/context menu, setting `Autofill` to `false`, or rejecting event handlers does not replace these properties. The properties do not prohibit programmatic row changes in BSL.
- **XSD validation is mandatory** after any XML edit — `verify_xml` against the schema returned by `get_xsd_schema(object_type="Форма")`. A form that parses in your editor is not a form that loads in Designer.
- **Form-element naming.** Elements added to a typical form must carry the `{PREFIX}` prefix from `.dev.env`. Elements inside a newly created form (object already prefixed) do **not** repeat the prefix on every element — see `dev-standards-change-markers.md → "Metadata Naming"`.
- **Common pitfalls** are catalogued in `metadata-xml-workarounds.md` — read it before hand-editing the XML.
- **Region structure of the form module** — `module-structure.md → Form Module` (5 mandatory regions).

## Form-Presentation Rules

### Programmatic Modification of Typical Forms

All typical form modifications are performed **programmatically**, not visually. Elements are created in the `OnCreateAtServer` handler (or via subscription / extension).

### Placement of Added Elements

- If the form has tabs — add elements to a separate tab (e.g. "Additional" or with `{PREFIX}`).
- If no tabs — create a group without title for added elements.
- Typical form element names — with `{PREFIX}` prefix.

### New Forms (Non-Typical Objects)

- Separate header attributes and tabular sections into distinct tabs: "Main" (header), then one tab per tabular section.
- Fill "Header Data Path" property for pages with tabular sections.
- Reference fields — maximum width 27 characters.
- Multiline comment fields — width 79, height 3.

### Fill Checking

- Use "Fill check" property on form attributes.
- Before writing / posting, call `ПроверитьЗаполнение()`:

```bsl
Если Не ПроверитьЗаполнение() Тогда
	Возврат;
КонецЕсли;
```

### Form Commands

- When creating commands that modify data — enable "Modifies stored data" flag.

## Companion rules

| If the change also includes… | Also load |
|---|---|
| Event handlers (`ПриОткрытии`, `ПередЗаписью`, …), form-module logic, reserved names | `form-module.md` |
| Client-side async code (`Асинх` / `Ждать`) | `async-methods.md` |

This list is curated by the router file `forms.md`; load only the items you actually touch.
