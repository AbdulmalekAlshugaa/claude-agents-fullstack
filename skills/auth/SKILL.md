---
name: auth
description: Adding authentication and authorization to a Next.js app (Postgres/Drizzle or MongoDB) - Auth.js setup, session checks, protecting routes/actions/handlers, and role-based access. Use when implementing login, signup, sessions, or permissions.
---

# Auth (Auth.js / NextAuth v5)

## Setup

- Use **Auth.js (next-auth v5)** with the adapter matching the project's DB:
  ```bash
  # Postgres (default)
  pnpm add next-auth@beta @auth/drizzle-adapter
  # Mongo
  pnpm add next-auth@beta @auth/mongodb-adapter mongodb
  ```
- Config in `src/lib/auth.ts` exporting `{ handlers, auth, signIn, signOut }`;
  route handler at `src/app/api/auth/[...nextauth]/route.ts` re-exports `handlers`.
- Prefer OAuth providers (Google/GitHub) first; credentials provider only when
  required — then hash with `bcrypt` (cost ≥ 12) and never store or log the
  plain password.
- `AUTH_SECRET` in `.env.local` (`npx auth secret`), validated in `lib/env.ts`.

## The one rule that matters

**Check the session at every entry point that does anything private.** Middleware
is UX (redirects), not security. Each of these independently verifies:

- **Server component / page**: `const session = await auth()` → redirect if null.
- **Server action**: first line `const session = await auth(); if (!session) return { ok: false, error: 'unauthenticated' }` —
  actions are public HTTP endpoints.
- **Route handler**: same check, return 401.
- **Service layer**: takes `userId` as an explicit parameter — services never
  read the session themselves, callers pass identity in.

## Authorization (roles/ownership)

- Store `role` on the user row/document; put it in the JWT/session via callbacks
  so checks don't hit the DB.
- Ownership checks happen in the service, in the query itself:
  `where(and(eq(t.id, id), eq(t.userId, userId)))` in Drizzle, or
  `Model.findOne({ _id: id, userId })` in Mongoose — not a post-fetch `if` (avoids TOCTOU and
  leaking existence via 403 vs 404; return 404 for both).
- Never trust a userId, role, or orgId from the request body — always from the
  session.

## Session strategy

- JWT sessions (default) for simplicity; database sessions if you need instant
  revocation.
- Keep the session payload small: `id`, `email`, `role`. Everything else is a
  DB read.
