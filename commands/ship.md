---
description: Verify, commit, and open a PR for the current work
argument-hint: [branch-name]
---

Ship the current changes. Branch name (optional): $ARGUMENTS

1. Run typecheck, lint, and tests. Stop and report if anything fails.
2. Spawn the **code-reviewer** agent; if it reports Blockers, stop and show them
   to me instead of committing.
3. Show me the proposed commit message (conventional format, no AI attribution,
   no Co-Authored-By) and wait for approval.
4. On approval: create the branch if needed, commit, push, and open a PR with
   this exact body format:

   ```
   ## Summary
   <1-3 bullet points>

   ## Test plan
   - [ ] <test step>
   ```

Never push to main directly. Never merge.
