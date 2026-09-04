# Global preferences (apply in every project)

## Default stack

When I start a new web app or the project doesn't dictate otherwise, use:

- **Next.js** (App Router, latest stable) with **TypeScript** (strict mode)
- **PostgreSQL** via **Drizzle ORM** for data (Neon in prod, local/docker in
  dev) — **MongoDB via Mongoose** as the alternative for genuinely
  document-shaped domains
- **TanStack Query v5** for ALL client-side data fetching and mutations
  (`queryOptions`/`mutationOptions` factories over server actions — see the
  `tanstack-query` skill). Never `useEffect` + `fetch` for server data.
- **shadcn/ui** for components (CLI-generated into `components/ui/`),
  **Tailwind CSS** for styling, **pnpm** as package manager
- **Node.js** LTS for any standalone services/scripts
- **Zod** for validation at every boundary (API input, env vars, external data)
- **Vitest** + React Testing Library for tests

## Architecture rules

- Fullstack-in-Next.js by default: UI + Route Handlers + Server Actions in one app.
  Only split out a separate Node service when there's a real reason (long-running
  jobs, websockets, queues).
- Layering inside `src/`:
  - `app/` — routes, pages, layouts, route handlers (thin, delegate to services)
  - `components/` — shared UI; `components/ui/` is shadcn's (CLI-managed)
  - `modules/<feature>/` — feature code: `components/`, `services/`, `schemas/`,
    `actions.ts`, plus the data layer: `keys.ts`, `queries.ts`, `mutations.ts`
  - `lib/db/` — DB client cached on `globalThis` + schema (Drizzle `schema/`
    or Mongoose `models/`)
  - `lib/query/` — `getQueryClient()` (server/browser-guarded QueryClient)
  - `lib/` — cross-cutting helpers (auth, env, fetch wrappers)
- Route handlers and server actions never touch the database directly —
  they call a service function. Services own DB access and business logic.
- Data ownership: pure server-rendered views call services directly and refresh
  via `revalidatePath`; anything a client component reads goes through a
  `queryOptions` factory and refreshes via `invalidateQueries`. Every mutation
  reconciles the cache(s) it affects.
- Validate all external input with Zod before it reaches a service.
- Never expose raw DB rows or Mongoose documents to the client — map to plain
  DTOs (explicit mapping; `.lean()` first in Mongoose) so internals don't leak.

## Commit & PR authoring

- **Never add `Co-Authored-By: Claude ...` trailers** to commit messages.
- **Never add "Generated with Claude Code"** or any 🤖 attribution to commits,
  PR titles, or PR bodies.
- Conventional commits: `<type>(<scope>): <short description>`.
- PR body format:

  ```
  ## Summary
  <1-3 bullet points>

  ## Test plan
  - [ ] <test step>
  ```

## Working style

- Prefer editing existing files over creating new ones.
- No comments unless the WHY is non-obvious.
- Secrets live in `.env.local` (gitignored); validate env with Zod in `lib/env.ts`.
- Before claiming a feature works, run it: `pnpm dev` + hit the route/page,
  or run the relevant tests.
