# Global preferences (apply in every project)

## Default stack

When I start a new web app or the project doesn't dictate otherwise, use:

- **Next.js** (App Router, latest stable) with **TypeScript** (strict mode)
- **MongoDB** via **Mongoose** for data (Atlas in prod, local/docker in dev)
- **Node.js** LTS for any standalone services/scripts
- **Tailwind CSS** for styling, **pnpm** as package manager
- **Zod** for validation at every boundary (API input, env vars, external data)
- **Vitest** + React Testing Library for tests

## Architecture rules

- Fullstack-in-Next.js by default: UI + Route Handlers + Server Actions in one app.
  Only split out a separate Node service when there's a real reason (long-running
  jobs, websockets, queues).
- Layering inside `src/`:
  - `app/` — routes, pages, layouts, route handlers (thin, delegate to services)
  - `components/` — shared UI components
  - `modules/<feature>/` — feature code: `components/`, `services/`, `schemas/`
  - `lib/db/` — Mongo connection singleton + Mongoose models
  - `lib/` — cross-cutting helpers (auth, env, fetch wrappers)
- Route handlers and server actions never touch Mongoose models directly —
  they call a service function. Services own DB access and business logic.
- Validate all external input with Zod before it reaches a service.
- Never expose Mongoose documents to the client — map to plain DTOs
  (`.lean()` + explicit mapping) so `_id`/`__v` and internals don't leak.

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
