---
description: Scaffold a new fullstack Next.js + TypeScript app (Postgres/Drizzle default, Mongo optional)
argument-hint: <app-name> [short description]
---

Scaffold a new app named "$ARGUMENTS" following the `web-app-scaffold` skill
(~/.claude/skills/web-app-scaffold/SKILL.md) exactly.

Before running anything, confirm with me:
1. The directory it will be created in
2. Database: Postgres (default — Neon URL vs local docker) or MongoDB
   (Atlas URI vs local docker)

Then scaffold, verify `pnpm build` and the `/api/health` route work, copy the
CLAUDE.md template into the repo, and make the initial commit.
