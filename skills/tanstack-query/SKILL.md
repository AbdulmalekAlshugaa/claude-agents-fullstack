---
name: tanstack-query
description: The data layer for every app - TanStack Query v5 for all client-side reads and writes. queryOptions/mutationOptions factories, query key design, Next.js App Router prefetch + hydration, mutations, invalidation, and optimistic updates. Use whenever a component reads data, writes data, or a cache goes stale.
---

# Data handling with TanStack Query v5

`@tanstack/react-query` owns **all client-side server state**. React state is for
UI state only (open/closed, selected tab, form draft). If a value came from the
database, it lives in the Query cache — never in `useState` + `useEffect`.

Verified against `@tanstack/react-query@5.102.x`.

## Install

```bash
pnpm add @tanstack/react-query
pnpm add -D @tanstack/react-query-devtools @tanstack/eslint-plugin-query
```

## The three-file convention per feature

```
src/modules/<feature>/
├── keys.ts        # query key factory — the single source of truth for keys
├── queries.ts     # queryOptions factories (reads)
├── mutations.ts   # mutationOptions factories (writes)
├── actions.ts     # 'use server' — the transport both of the above call
├── services/      # DB access (unchanged: services own Mongo + business logic)
└── schemas/       # Zod schemas + z.infer types
```

Components never inline a `queryKey` or a `queryFn`. They import a factory.

## 1. Query keys — one factory, hierarchical

```ts
// modules/users/keys.ts
import type { ListUsersInput } from './schemas/user'

export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: ListUsersInput) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
} as const
```

Rules:
- **Hierarchical, general → specific.** `invalidateQueries({ queryKey: userKeys.lists() })`
  then hits every list regardless of filters, because invalidation is prefix-matched.
- **Every variable the `queryFn` reads is in the key.** A filter, page, or id that
  changes the response but not the key is a cache-poisoning bug.
- Serialisable values only — no class instances, no `Date` objects (use ISO strings).

## 2. Reads — `queryOptions` factories

`queryOptions()` is the "create options" helper: it keeps full type inference when
options live outside the hook, and it ties the `queryKey` to its `queryFn` so
`queryClient.getQueryData(opts.queryKey)` is typed with no annotation.

```ts
// modules/users/queries.ts
import { queryOptions, infiniteQueryOptions } from '@tanstack/react-query'
import { listUsersAction, getUserAction } from './actions'
import { userKeys } from './keys'
import type { ListUsersInput } from './schemas/user'

export function listUsersOptions(filters: ListUsersInput) {
  return queryOptions({
    queryKey: userKeys.list(filters),
    // Wrap the call: TanStack passes a QueryFunctionContext, which is not
    // serialisable across the server-action boundary. Never pass it through.
    queryFn: () => listUsersAction(filters),
    staleTime: 60 * 1000,
  })
}

export function userOptions(id: string) {
  return queryOptions({
    queryKey: userKeys.detail(id),
    queryFn: () => getUserAction(id),
  })
}
```

One factory is now usable everywhere, with the same key and the same types:

```ts
useQuery(listUsersOptions(filters))
useSuspenseQuery(listUsersOptions(filters))
queryClient.query(listUsersOptions(filters))          // server prefetch
queryClient.invalidateQueries({ queryKey: userKeys.lists() })
queryClient.getQueryData(userOptions(id).queryKey)    // typed User | undefined
```

For paginated lists use `infiniteQueryOptions` with the same shape plus
`initialPageParam` / `getNextPageParam` (cursor-based — see mongodb-data-modeling).

## 3. Transport: server actions, not private route handlers

The `queryFn` must be **isomorphic** — the same function runs during server
prefetch and during client refetch. A `'use server'` action is exactly that: a
direct function call on the server, an RPC POST from the client.

```ts
// modules/users/actions.ts
'use server'
import { auth } from '@/lib/auth'
import { listUsersSchema } from './schemas/user'
import * as usersService from './services'

export async function listUsersAction(input: unknown) {
  const session = await auth()
  if (!session) throw new Error('unauthenticated')
  const filters = listUsersSchema.parse(input)     // actions are public endpoints
  return usersService.listUsers({ ...filters, userId: session.user.id })
}
```

- Actions used as a `queryFn` **throw** on failure — Query needs a rejected promise
  to enter its `error` state. Actions used as a `mutationFn` throw too. This is the
  one place the repo's "return result objects, don't throw" rule is inverted;
  keep the result-object style for actions called directly from `useActionState`.
- Return plain DTOs only (services already `.lean()` + map). No Mongoose docs,
  no `ObjectId`, no `Date` — the payload crosses a serialisation boundary twice.
- **Escape hatch:** switch that read to a `GET` route handler + typed `fetch` when
  it is hot enough to want HTTP/CDN caching, must be parallel (server actions are
  POSTs and Next.js serialises them), or is consumed by a non-browser client.
  The `queryOptions` factory is the only file that changes.

## 4. Next.js App Router: prefetch on the server, hydrate on the client

`src/lib/query/get-query-client.ts`:

```ts
import {
  QueryClient,
  defaultShouldDehydrateQuery,
  environmentManager,
} from '@tanstack/react-query'

function makeQueryClient() {
  return new QueryClient({
    defaultOptions: {
      // Non-zero staleTime: without it, every hydrated query refetches
      // immediately on mount and the prefetch was wasted.
      queries: { staleTime: 60 * 1000, retry: 1 },
      dehydrate: {
        // Ship still-pending queries so streaming works without awaiting.
        shouldDehydrateQuery: (query) =>
          defaultShouldDehydrateQuery(query) || query.state.status === 'pending',
      },
    },
  })
}

let browserQueryClient: QueryClient | undefined

export function getQueryClient() {
  if (environmentManager.isServer()) return makeQueryClient()
  return (browserQueryClient ??= makeQueryClient())
}
```

Never build a `QueryClient` at module scope or in a server component body without
this guard — on the server it leaks one user's data into another request; in the
browser a fresh client on every render throws the cache away.

`src/app/providers.tsx`:

```tsx
'use client'
import { QueryClientProvider } from '@tanstack/react-query'
import { getQueryClient } from '@/lib/query/get-query-client'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={getQueryClient()}>{children}</QueryClientProvider>
  )
}
```

Mount `<Providers>` once in `app/layout.tsx`, wrapping `{children}`.

Prefetch in the server component that owns the route:

```tsx
// app/users/page.tsx  (server component)
import { dehydrate, HydrationBoundary, noop } from '@tanstack/react-query'
import { getQueryClient } from '@/lib/query/get-query-client'
import { listUsersOptions } from '@/modules/users/queries'
import { UsersTable } from '@/modules/users/components/users-table'

export default function UsersPage() {
  const queryClient = getQueryClient()

  // void + .catch(noop) => start the fetch, stream the shell now.
  // await it instead when the page is useless without the data.
  void queryClient.query(listUsersOptions({ page: 1 })).catch(noop)

  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <UsersTable />
    </HydrationBoundary>
  )
}
```

```tsx
// modules/users/components/users-table.tsx
'use client'
import { useSuspenseQuery } from '@tanstack/react-query'
import { listUsersOptions } from '../queries'

export function UsersTable() {
  const { data } = useSuspenseQuery(listUsersOptions({ page: 1 }))
  // ...
}
```

The prefetch call and the hook call **must use the same factory with the same
arguments** — a mismatch silently double-fetches on the client.

`useSuspenseQuery` (paired with `loading.tsx`/`<Suspense>` and `error.tsx`) for
data the view cannot render without; `useQuery` when you want to render around a
loading/error state yourself, or when the query is conditional (`enabled`).

### Deprecated — do not write these

`queryClient.prefetchQuery` · `fetchQuery` · `ensureQueryData` ·
`prefetchInfiniteQuery` · `fetchInfiniteQuery`. All are deprecated in v5.102 and
removed in v6. Use `queryClient.query(...)` / `queryClient.infiniteQuery(...)`,
and `staleTime: 'static'` where you previously reached for `ensureQueryData`.

## 5. Writes — `mutationOptions` factories

```ts
// modules/users/mutations.ts
import { mutationOptions } from '@tanstack/react-query'
import { createUserAction } from './actions'
import { userKeys } from './keys'

export function createUserMutationOptions() {
  return mutationOptions({
    mutationKey: userKeys.all,
    mutationFn: createUserAction,
  })
}
```

```tsx
'use client'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { createUserMutationOptions } from '../mutations'
import { userKeys } from '../keys'

export function CreateUserForm() {
  const queryClient = useQueryClient()
  const { mutate, isPending, error } = useMutation({
    ...createUserMutationOptions(),
    onSuccess: () => {
      // Invalidate the narrowest prefix that covers what changed.
      queryClient.invalidateQueries({ queryKey: userKeys.lists() })
    },
  })
  // disable submit while isPending; render error inline
}
```

Rules:
- **Every mutation invalidates something.** A write with no `invalidateQueries`
  (or no `setQueryData`) leaves the UI showing stale data — treat it as a bug.
- Invalidate in `onSuccess`; use `onSettled` when an optimistic update must be
  reconciled whether the write succeeded or failed.
- Cross-feature effects belong in the component's `onSuccess`, not the shared
  factory — keep factories transport-only so they stay reusable.
- `mutate` for fire-and-forget; `mutateAsync` only when you genuinely need to
  await (and then you must `try/catch` — it rejects).
- Prefer invalidation over hand-writing the cache. Reach for `setQueryData` only
  when the server response already contains the exact updated entity.

### Optimistic updates — only where latency is felt

```ts
useMutation({
  ...toggleMutationOptions(),
  onMutate: async (next) => {
    await queryClient.cancelQueries({ queryKey: userKeys.detail(next.id) })
    const previous = queryClient.getQueryData(userOptions(next.id).queryKey)
    queryClient.setQueryData(userOptions(next.id).queryKey, next)
    return { previous }
  },
  onError: (_e, next, ctx) =>
    queryClient.setQueryData(userOptions(next.id).queryKey, ctx?.previous),
  onSettled: (_d, _e, next) =>
    queryClient.invalidateQueries({ queryKey: userKeys.detail(next.id) }),
})
```

All four steps or none: cancel → snapshot → patch → rollback on error → invalidate
on settle. A partial implementation corrupts the cache on failure.

## 6. Coexisting with RSC and `revalidatePath`

Two caches exist. Keep the ownership line sharp:

| Data rendered by | Refreshed with |
|---|---|
| A server component (no client interactivity) | call the service directly; `revalidatePath`/`revalidateTag` after a mutation |
| A client component via `useQuery`/`useSuspenseQuery` | `queryClient.invalidateQueries` |

If one screen has both, the mutation does **both** — `revalidatePath` in the
action, `invalidateQueries` in `onSuccess`. Never use `router.refresh()` to fix
stale Query data; that is a missing invalidation.

Static content, marketing pages, and one-shot server-rendered detail views should
stay pure RSC. Query earns its place when data is refetched, mutated, paginated,
polled, or shared across client components.

## 7. Devtools

```tsx
{process.env.NODE_ENV !== 'production' && <ReactQueryDevtools initialIsOpen={false} />}
```

Inside `<Providers>`. First stop for any "why is this stale / refetching" bug:
read the actual key in the devtools before changing code.

## 8. Testing

- Wrap the component in a `QueryClientProvider` with a **per-test** client:
  `new QueryClient({ defaultOptions: { queries: { retry: false } } })`. Retries turn
  a failing test into a timeout.
- Mock at the action boundary (`vi.mock('../actions')`), never the hook.
- Test the option factories directly: assert the key shape for a given input —
  that is the contract every invalidation depends on.

## Review checklist

- [ ] No `useEffect` + `fetch`/`useState` pair holding server data
- [ ] Every `queryKey` comes from a key factory; every variable read by the `queryFn` is in it
- [ ] Prefetch and hook use the same `queryOptions` factory and arguments
- [ ] `HydrationBoundary` present wherever a server component prefetched
- [ ] `staleTime` non-zero on hydrated queries
- [ ] Every mutation invalidates or writes the cache
- [ ] Optimistic updates roll back on error
- [ ] No deprecated `prefetchQuery` / `fetchQuery` / `ensureQueryData`
- [ ] `QueryClient` created via `getQueryClient()`, never at module scope
