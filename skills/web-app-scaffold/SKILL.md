---
name: web-app-scaffold
description: Bootstrap a new fullstack web app with Next.js (App Router), TypeScript, MongoDB/Mongoose, TanStack Query, shadcn/ui, Tailwind, Zod, and Vitest. Use when starting a new project or when the user says "new app", "scaffold", or "set up a project".
---

# Scaffold a fullstack Next.js + MongoDB app

## Steps

1. **Create the app** (confirm the name first):
   ```bash
   pnpm create next-app@latest <name> --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-pnpm
   ```

2. **Install the stack**:
   ```bash
   pnpm add mongoose zod @tanstack/react-query
   pnpm add -D vitest @vitejs/plugin-react @testing-library/react @testing-library/jest-dom jsdom mongodb-memory-server @tanstack/react-query-devtools @tanstack/eslint-plugin-query
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
       │   ├── connect.ts    # cached connection singleton
       │   └── models/       # Mongoose models
       ├── query/
       │   └── get-query-client.ts  # server/browser-guarded QueryClient
       └── env.ts            # Zod-validated env
   ```

   Wire `getQueryClient`, `providers.tsx`, and mount `<Providers>` in
   `app/layout.tsx` exactly as specified in the `tanstack-query` skill.

4. **DB connection singleton** — `src/lib/db/connect.ts` must cache the connection
   on `globalThis` (Next.js hot-reload creates duplicate connections otherwise):
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
   (`MONGODB_URI: z.string().url()` at minimum). Create `.env.local` and
   `.env.example`. Never import `env.ts` from client components.

6. **tsconfig**: ensure `"strict": true` and add `"noUncheckedIndexedAccess": true`.

7. **Vitest**: add `vitest.config.ts` with the react plugin + jsdom, and scripts
   `"test": "vitest run"`, `"test:watch": "vitest"`.

8. **Copy the project CLAUDE.md** from `~/.claude/templates/CLAUDE.md.template`
   into the repo root as `CLAUDE.md`, filling in the app name.

9. **Verify**: `pnpm build` passes, `pnpm dev` boots, a smoke test
   (`/api/health` route handler returning `{ ok: true }` with a `dbConnect()`
   call) responds.

10. **Init git** with a first commit `chore: scaffold app` (no AI attribution).

## Local MongoDB

If the user has no Atlas URI, offer docker:
```bash
docker run -d --name <name>-mongo -p 27017:27017 mongo:7
# MONGODB_URI=mongodb://localhost:27017/<name>
```
