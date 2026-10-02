---
description: ITL managed-form client/server boundary check for changed user paths
alwaysApply: false
category: development
---

# ITL managed-form context

Load for a managed-form change or a runtime defect that crosses a client/server boundary. Obtain platform rules and member availability through `1C-docs-mcp` when available; this local contract adds the project path and evidence boundary.

Before editing, trace the affected user action from its UI entry through each changed client/server call and into unchanged code. For each changed procedure, check its directive and module properties. Verify every new or suspect global property, manager, applied type, constructor and method in that execution context. A syntax pass does not establish that a member exists or is usable in that context; when uncertain, use `bsl_scope_members`, platform documentation or a working project pattern.

At each crossing, check that parameters and return values can cross, retain the expected type and are usable by the receiver. Never return a server-only applied object, manager or selection to client code. Convert it in the owning context and return client-usable values or data structures. Client code obtains a predefined value with `ПредопределенноеЗначение("Перечисление.ВидОперации.Значение")`, not a server-only enumeration manager.

For a changed runtime path, exercise the exact affected user action once before dependent implementation when the branch infobase and authorized UI route are available; reuse fresh evidence for the same saved code and path. This is a diagnostic checkpoint, not a completion pass, and does not replace Vanessa or the final ITL assessment. A missing runtime route remains unverified with the helper's continuation. `&НаСервере` is not a universal fix: server code must avoid client-only UI APIs and return a valid client contract.
