---
name: postgres-data-modeling
description: Conventions for PostgreSQL with Drizzle ORM in TypeScript - schema definitions, relations, indexes, migrations with drizzle-kit, and query patterns. Use when creating or changing a Postgres table, writing queries, or debugging query performance. (Mongo projects use mongodb-data-modeling instead.)
---

# PostgreSQL + Drizzle conventions

## Schema definition pattern

One file per domain area in `src/lib/db/schema/<name>.ts`, all re-exported from
`src/lib/db/schema/index.ts` (drizzle-kit points at the barrel):

```ts
import { pgTable, varchar, timestamp, uuid, index, uniqueIndex } from 'drizzle-orm/pg-core'

export const users = pgTable(
  'users',
  {
    id: uuid().primaryKey().defaultRandom(),
    email: varchar({ length: 255 }).notNull(),
    name: varchar({ length: 120 }).notNull(),
    role: varchar({ length: 20, enum: ['user', 'admin'] }).notNull().default('user'),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('users_email_idx').on(t.email),
  ],
)

export type UserRow = typeof users.$inferSelect
export type NewUser = typeof users.$inferInsert
```

Connection in `src/lib/db/index.ts`, cached on `globalThis` (Next.js hot reload):

```ts
import { drizzle } from 'drizzle-orm/node-postgres'
import { env } from '@/lib/env'
import * as schema from './schema'

const cached = (globalThis as { __db?: ReturnType<typeof create> })
function create() {
  return drizzle(env.DATABASE_URL, { schema })
}
export const db = (cached.__db ??= create())
```

## Rules

- **Types come from the schema**: `$inferSelect` / `$inferInsert` — never
  hand-write a row type. API DTOs still derive from Zod (`z.infer`); map row →
  DTO in the service and never return raw rows to the client.
- **Every table gets `createdAt`/`updatedAt`** (`withTimezone: true`); bump
  `updatedAt` in the service on update.
- **Foreign keys are real**: `.references(() => users.id, { onDelete: 'cascade' | 'restrict' })`
  chosen deliberately — say which and why. Add a `relations()` definition when
  you want `db.query.*` nested reads.
- **Index every real query pattern** in the table's third argument; composite
  indexes ordered by selectivity, matching the WHERE + ORDER BY they serve.
  Flag indexes nothing uses.
- **Queries are built with the query builder or `db.query`** — never string
  concatenation. If you must drop to SQL, use the `sql` template tag (it
  parameterises); `sql.raw()` with user input is an injection, full stop.
- **Ownership in the WHERE clause**:
  `db.select().from(items).where(and(eq(items.id, id), eq(items.userId, userId)))` —
  not a post-fetch `if`. Return 404 for both missing and unowned.
- **No N+1**: batch with `inArray`, join, or a `db.query` relation — never
  `await` a query inside a loop.
- **Always paginate list queries**: `.limit(n)` + keyset cursor
  (`where(lt(t.createdAt, cursor))` with a matching index) for real datasets;
  offset only for small admin lists.
- **Unique violations**: catch Postgres error code `23505` in the service and
  return a 409-shaped result — don't let it bubble as a 500.

## Migrations (drizzle-kit)

`drizzle.config.ts` at the repo root:

```ts
import { defineConfig } from 'drizzle-kit'

export default defineConfig({
  out: './drizzle',
  schema: './src/lib/db/schema/index.ts',
  dialect: 'postgresql',
  dbCredentials: { url: process.env.DATABASE_URL! },
})
```

- Local iteration: `pnpm drizzle-kit push` (no migration files).
- Anything shared or deployed: `pnpm drizzle-kit generate` → review the SQL in
  `./drizzle/` → commit it → `pnpm drizzle-kit migrate` runs in deploy.
  **Generated migrations are code-reviewed like code** — check for table
  rewrites and dropped columns.
- Destructive changes (drop/rename column) ship in two steps: add-and-backfill
  first, remove later. Note the plan in the PR.

## Transactions

Multi-table writes that must be atomic use `db.transaction(async (tx) => { ... })` —
use `tx`, not `db`, inside the callback (using `db` silently escapes the
transaction). Keep transactions short; no external calls inside them.

## Choosing Postgres vs Mongo (when scaffolding)

Postgres is the default: relational integrity, joins, and migrations tooling fit
most CRUD apps. Choose Mongo when the domain is genuinely document-shaped
(deep nested aggregates read/written as one unit, highly variable fields) — then
follow `mongodb-data-modeling` instead. Never both in one app without a reason.
