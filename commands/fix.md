---
description: Root-cause a bug, then fix it with a regression test
argument-hint: <bug description / error message / repro steps>
---

Bug: $ARGUMENTS

1. Spawn the **debugger** agent with the bug description and repo path.
2. Relay the root cause and proposed fix to me.
3. Implement the minimal fix at the identified location — no drive-by refactors.
4. Add the regression test the debugger proposed (spawn **test-writer** if it's
   more than one test) and confirm it fails without the fix and passes with it.
5. Run the full test suite + typecheck and report.
