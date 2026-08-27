---
description: Plan then implement a fullstack feature (schema → service → API → UI)
argument-hint: <feature description>
---

Build this feature: $ARGUMENTS

Workflow:
1. Spawn the **planner** agent with the feature description and repo path. If the
   feature involves new or changed collections, also spawn **db-designer** in
   parallel.
2. Show me the plan and wait for my approval — do not implement before I confirm.
3. After approval, implement following the plan (or spawn **fullstack-implementer**
   for large features), respecting the api-design, mongodb-data-modeling, and
   component-design skills.
4. Spawn **test-writer** to cover the new services and key UI states.
5. Run typecheck, lint, and the full test suite. Report what was built and what
   I should manually verify in the browser.

Do not commit unless I ask.
