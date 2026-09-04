---
name: deploy
description: Deployment checklist for Next.js apps - Vercel or Docker/Node hosting, hosted Postgres (Neon) or MongoDB Atlas, env management, and production readiness. Use when shipping an app to production or setting up CI.
---

# Deploy (Vercel + Neon Postgres by default; Atlas for Mongo)

## Pre-deploy checklist

- `pnpm build` passes locally with no type errors or lint errors.
- All env vars in `.env.example` exist in the hosting env; `lib/env.ts` Zod parse
  will fail the build/boot loudly if not — that's the point.
- No secrets in `NEXT_PUBLIC_*` vars. Grep for `NEXT_PUBLIC` before shipping.
- `/api/health` route exists: connects to DB, returns `{ ok: true }` — used for
  uptime checks.
- List endpoints are paginated; mutations are auth-checked (spot-check with the
  code-reviewer agent).
- Postgres: committed Drizzle migrations are up to date
  (`pnpm drizzle-kit generate` produces no diff) and `db:migrate` runs in the
  deploy step, never `db:push` against prod.

## Hosted Postgres (Neon or similar)

- Serverless driver or connection pooling (Neon pools for you; on plain
  Postgres use pgBouncer) — serverless functions without pooling exhaust
  connections.
- One database per app, one role per app with least privilege — never the
  superuser in `DATABASE_URL`.
- Point preview deployments at a branch/staging database, never prod. Neon
  branches map 1:1 to Vercel preview branches nicely.
- Backups/PITR on before real users exist.

## MongoDB Atlas (Mongo projects)

- Free M0 cluster for hobby, M10+ for anything real.
- **Network access**: Vercel has no static IPs on hobby — allow `0.0.0.0/0` and
  rely on strong credentials + TLS, or use Atlas + Vercel integration. Note this
  tradeoff in the README.
- Dedicated DB user per app with `readWrite` on that app's database only —
  never the admin user.
- Connection string in `MONGODB_URI`; Mongoose pools automatically. In
  serverless, the cached-on-`globalThis` connection pattern (from the scaffold
  skill) is what prevents connection storms.
- Enable Atlas backups on any paid tier before real users exist.

## Vercel

- Import the repo, framework auto-detected. Set env vars for Production and
  Preview separately (preview points at a staging DB, never prod).
- Every PR gets a preview deployment — test the golden path there before merging.

## Docker / Node hosting (when not Vercel)

- `output: 'standalone'` in `next.config`; multi-stage Dockerfile
  (deps → build → `node .next/standalone/server.js` on a slim Node LTS image).
- Run as non-root user; healthcheck hits `/api/health`.

## CI (GitHub Actions) minimum

One workflow on PR: install (pnpm, cached) → typecheck → lint → test → build.
Merges blocked on green. Deploys happen from main only.
