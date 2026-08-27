---
name: api-design
description: Conventions for Next.js route handlers, server actions, Zod validation, and service-layer design. Use when adding or changing any API endpoint, server action, or backend service function.
---

# API design: route handlers, server actions, services

## Choosing the mechanism

- **Server component fetching data** → call the service directly. No HTTP hop.
- **Mutations from your own UI** → server action.
- **Endpoint consumed by external clients / mobile / webhooks** → route handler.
- Never build a route handler just so your own client component can `fetch` it —
  use a server action or lift the fetch to a server component.

## Route handler shape (thin)

`src/app/api/<resource>/route.ts`:

```ts
import { NextResponse } from 'next/server'
import { createUserSchema } from '@/modules/users/schemas/user'
import { createUser } from '@/modules/users/services/create-user'

export async function POST(req: Request) {
  const body = await req.json().catch(() => null)
  const parsed = createUserSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 })
  }
  const result = await createUser(parsed.data)
  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status })
  }
  return NextResponse.json(result.data, { status: 201 })
}
```

Pattern: parse → authorize → call service → map result to response. Under ~30
lines; anything more belongs in the service.

## Server actions

- File-level `'use server'` in `modules/<feature>/actions.ts`.
- **Every action validates input with Zod and checks auth itself** — server
  actions are public HTTP endpoints regardless of where the button lives.
- Return typed results (`{ ok: true, data } | { ok: false, error }`), don't throw
  for expected failures.
- Call `revalidatePath`/`revalidateTag` after mutations that affect rendered data.

## Services

- Live in `modules/<feature>/services/`, one exported function per file for
  non-trivial ones.
- Own ALL DB access and business rules. Call `dbConnect()` at the top.
- Input: already-validated typed data (the `z.infer` type). Output: plain DTOs.
- Expected failures return result objects; only truly exceptional states throw.

## Status codes & errors

400 invalid input · 401 unauthenticated · 403 unauthorized · 404 not found ·
409 conflict (duplicate key → catch Mongo error code 11000) · 500 everything else.
Never leak internal error messages or stack traces in responses; log them
server-side instead.

## Zod schemas

- Live in `modules/<feature>/schemas/`, shared by route handlers, actions, and
  client forms.
- DTO types derive from schemas: `export type CreateUserInput = z.infer<typeof createUserSchema>`.
- Schemas are strict by default; use `.strict()` on objects accepting client input.
