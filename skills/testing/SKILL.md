---
name: testing
description: Testing strategy and Vitest conventions for Next.js + TypeScript apps on Postgres/Drizzle or MongoDB - what to test, how to test services against a real in-process database, and component testing. Use when writing tests or setting up test infrastructure.
---

# Testing (Vitest + Testing Library + in-process DB)

## Priority order — spend effort where bugs live

1. **Services** — business logic + DB access. Highest value.
2. **Zod schemas** — boundary validation edge cases.
3. **Pure helpers** in `lib/`.
4. **Components** — the four states (loading/error/empty/populated) and user
   interactions. Test through the DOM, not implementation.
5. Skip: trivial pass-through code, styles, Next.js framework behavior.

## Service tests with a real (in-process) database

Test real query behavior, constraints, and indexes without mocking the ORM.

**Postgres (default)** — PGlite, an in-process Postgres:

```ts
import { PGlite } from '@electric-sql/pglite'
import { drizzle } from 'drizzle-orm/pglite'
import * as schema from '@/lib/db/schema'

const client = new PGlite()
export const testDb = drizzle(client, { schema })

beforeAll(async () => {
  // apply the committed migrations (or push the schema) to the fresh instance
  await migrate(testDb, { migrationsFolder: './drizzle' })
})
afterEach(async () => {
  // truncate all tables between tests
})
```

Put this in a shared `src/test/setup-db.ts` and stub `@/lib/db` with the test
instance via `vi.mock` so services under test hit PGlite.

**Mongo** — `mongodb-memory-server`:

```ts
import { MongoMemoryServer } from 'mongodb-memory-server'
import mongoose from 'mongoose'

let mongod: MongoMemoryServer

beforeAll(async () => {
  mongod = await MongoMemoryServer.create()
  await mongoose.connect(mongod.getUri())
})
afterEach(async () => {
  await mongoose.connection.db?.dropDatabase()
})
afterAll(async () => {
  await mongoose.disconnect()
  await mongod.stop()
})
```

Stub `dbConnect` to a no-op in tests (connection is already open).

## Conventions

- Test files: `<name>.test.ts(x)` next to the code under test.
- Names describe behavior: `it('returns 409 result when email already exists')`.
- Arrange with real service calls or direct model inserts — no fixture dumps that
  hide what matters to the test.
- Every bug fix ships with a regression test that fails without the fix.
- Assert on outcomes (returned DTO, DB state, rendered text), not on spies,
  unless the call itself is the contract (e.g. revalidatePath was invoked).

## Component tests

- `@testing-library/react` + jsdom; query by role/text like a user would.
- Test client components directly with props for each state. Async server
  components don't render in jsdom — test their services instead and keep the
  component thin.
- Mock server actions at the import boundary with `vi.mock`.
- Components using TanStack Query hooks: wrap in a `QueryClientProvider` with a
  fresh per-test client and `retry: false` (retries turn failures into
  timeouts):
  ```tsx
  function renderWithQuery(ui: React.ReactElement) {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    return render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>)
  }
  ```
  Mock the actions the option factories call — never the hooks themselves. For
  mutations, assert the visible outcome (updated list, toast, disabled button),
  not that `invalidateQueries` was spied on.
- Query key factories get direct unit tests: assert the key shape per input —
  every invalidation in the app depends on that contract.

## Before claiming done

Run the whole suite (`pnpm test`), plus typecheck and lint. A green new test with
a red suite is not done.
