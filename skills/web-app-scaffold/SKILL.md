---
name: web-app-scaffold
description: Bootstrap a new fullstack web app with Next.js (App Router), TypeScript, PostgreSQL/Drizzle (default) or MongoDB/Mongoose, TanStack Query, shadcn/ui, Tailwind, Zod, and Vitest. Use when starting a new project or when the user says "new app", "scaffold", or "set up a project".
---

# Scaffold a fullstack Next.js app

Database default is **PostgreSQL via Drizzle**; use MongoDB/Mongoose when the
user asks for it or the domain is genuinely document-shaped.

## Steps

1. **Create the app** (confirm the name first):
   ```bash
   pnpm create next-app@latest <name> --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-pnpm
   ```

2. **Install the stack**:
   ```bash
   # Postgres (default)
   pnpm add drizzle-orm pg zod @tanstack/react-query
   pnpm add -D drizzle-kit @types/pg @electric-sql/pglite \
     vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom jsdom \
     @tanstack/react-query-devtools @tanstack/eslint-plugin-query
   # Mongo variant: swap drizzle-orm/pg/drizzle-kit/@types/pg/@electric-sql/pglite
   # for: mongoose (dep) + mongodb-memory-server (dev)
   pnpm dlx shadcn@latest init            # then: pnpm dlx shadcn@latest add button card ...
   ```

3. **Folder layout** under `src/`:
   ```
   src/
   ├── app/                  # routes, layouts, route handlers
   │   ├── providers.tsx     # 'use client': QueryClientProvider (+ devtools)
   │   └── api/<resource>/route.ts
   ├── components/           # shared UI
   │   └── ui/               # shadcn/ui components (CLI-generated)
   ├── modules/<feature>/
   │   ├── components/
   │   ├── services/         # all business logic + DB access
   │   ├── schemas/          # Zod schemas + z.infer DTO types
   │   ├── actions.ts        # 'use server' actions (auth → parse → service)
   │   ├── keys.ts           # query key factory
   │   ├── queries.ts        # queryOptions factories
   │   └── mutations.ts      # mutationOptions factories
   └── lib/
       ├── db/
       │   ├── index.ts      # drizzle() client cached on globalThis
       │   └── schema/       # pgTable definitions (+ index.ts barrel)
       │   # Mongo variant: connect.ts singleton + models/
       ├── query/
       │   └── get-query-client.ts  # server/browser-guarded QueryClient
       └── env.ts            # Zod-validated env
   ```

   Wire `getQueryClient`, `providers.tsx`, and mount `<Providers>` in
   `app/layout.tsx` exactly as specified in the `tanstack-query` skill.

4. **DB client** — cache on `globalThis` (Next.js hot-reload duplicates modules):

   Postgres, `src/lib/db/index.ts`:
   ```ts
   import { drizzle } from 'drizzle-orm/node-postgres'
   import { env } from '@/lib/env'
   import * as schema from './schema'

   const g = globalThis as { __db?: ReturnType<typeof drizzle<typeof schema>> }
   export const db = (g.__db ??= drizzle(env.DATABASE_URL, { schema }))
   ```
   Plus `drizzle.config.ts` at the root (`dialect: 'postgresql'`,
   `schema: './src/lib/db/schema/index.ts'`, `out: './drizzle'`) — see the
   `postgres-data-modeling` skill. Add scripts:
   `"db:push": "drizzle-kit push"`, `"db:generate": "drizzle-kit generate"`,
   `"db:migrate": "drizzle-kit migrate"`.

   Mongo variant, `src/lib/db/connect.ts`:
   ```ts
   import mongoose from 'mongoose'
   import { env } from '@/lib/env'

   const cached = (globalThis as any).__mongoose ??= { conn: null, promise: null }

   export async function dbConnect() {
     if (cached.conn) return cached.conn
     cached.promise ??= mongoose.connect(env.MONGODB_URI)
     cached.conn = await cached.promise
     return cached.conn
   }
   ```

5. **Env validation** — `src/lib/env.ts` parses `process.env` with Zod
   (`DATABASE_URL` or `MONGODB_URI`: `z.string().url()` at minimum). Create
   `.env.local` and `.env.example`. Never import `env.ts` from client components.

6. **tsconfig**: ensure `"strict": true` and add `"noUncheckedIndexedAccess": true`.

7. **Vitest**: add `vitest.config.ts` with the react plugin + jsdom, and scripts
   `"test": "vitest run"`, `"test:watch": "vitest"`.

8. **Copy the project CLAUDE.md** from `~/.claude/templates/CLAUDE.md.template`
   into the repo root as `CLAUDE.md`, filling in the app name and the DB chosen.

9. **Verify**: `pnpm build` passes, `pnpm dev` boots, a smoke test
   (`/api/health` route handler that runs a trivial query — `select 1` via
   Drizzle, or `dbConnect()` for Mongo — returning `{ ok: true }`) responds.

10. **Init git** with a first commit `chore: scaffold app` (no AI attribution).

## Local database

If the user has no hosted URL, offer docker:
```bash
# Postgres (default)
docker run -d --name <name>-pg -p 5432:5432 -e POSTGRES_PASSWORD=dev -e POSTGRES_DB=<name> postgres:17
# DATABASE_URL=postgresql://postgres:dev@localhost:5432/<name>

# Mongo variant
docker run -d --name <name>-mongo -p 27017:27017 mongo:7
# MONGODB_URI=mongodb://localhost:27017/<name>
```
