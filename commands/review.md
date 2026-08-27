---
description: Strict review of the current diff before commit/PR
---

Spawn the **code-reviewer** agent on the current working tree.

Relay its findings grouped by severity (Blocker / Should-fix / Nit) with
file:line references, and its ship verdict. Then ask me whether to fix the
blockers now — do not fix anything without my confirmation.
