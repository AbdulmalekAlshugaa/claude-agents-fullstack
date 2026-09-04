---
name: component-design
description: Conventions for React components in Next.js App Router - server vs client split, props contracts, Tailwind styling, and async UI states. Use when building or restructuring UI components.
---

# Component design (Next.js App Router)

## Server vs client

- **Default to server components.** Add `'use client'` only for state, effects,
  event handlers, or browser APIs — and put the directive on the smallest leaf
  that needs it, not the page.
- Static/one-shot data: fetch in server components (call services directly) and
  pass plain serializable props down. Never pass raw DB rows or Mongoose docs;
  prefer ISO
  strings over Dates; ObjectIds must be `.toString()`ed.
- Data the client interacts with (refetch, pagination, mutation): the server
  component prefetches via `queryClient.query()` + `HydrationBoundary`, the
  client component consumes with `useSuspenseQuery` — see the `tanstack-query`
  skill. Never `useEffect` + `fetch`.
- Fresh data after a mutation → `invalidateQueries` in the mutation's
  `onSuccess` (plus `revalidatePath` in the action if RSC-rendered data
  changed) — never manual refetch loops or `router.refresh()` as a fix.

## Component structure

- **Smart/dumb split**: pages and feature containers fetch and decide; leaf
  components in `modules/<feature>/components/` are prop-driven and presentational.
- Props are explicit and typed inline or as `type Props = { ... }` above the
  component. No `React.FC`.
- **Discriminated unions over optional-prop bags** when a component has modes:
  ```ts
  type Props =
    | { state: 'loading' }
    | { state: 'error'; message: string }
    | { state: 'ready'; items: Item[] }
  ```
- Never spread props into custom components (`<Card {...props}>` hides the contract).
- Callbacks named `onX`, handlers named `handleX`.

## Async UI states — every data-driven view handles all four

1. Loading — `loading.tsx` or Suspense boundary with a skeleton
2. Error — `error.tsx` or an inline error state with a retry path
3. Empty — a designed empty state, never a blank region
4. Populated

## Forms

- shadcn/ui `form` (react-hook-form + `zodResolver`) submitting through
  `useMutation` for the standard case; `useActionState` for simple RSC-only
  forms with no client cache to reconcile.
- Validate with the same Zod schema on client (nice errors) and server (security).
- Disable the submit button while `isPending`; surface field-level errors.

## Styling

- Compose shadcn/ui primitives from `components/ui/` (generate with
  `pnpm dlx shadcn@latest add <name>`) — never hand-build a widget the registry
  already has. Use semantic tokens (`bg-background`, `text-muted-foreground`),
  not raw palette classes, in feature code. See the `shadcn-ui` skill.
- Tailwind utilities directly on elements; extract a component when a set of
  classes repeats, not a CSS file.
- Use a `cn()` helper (clsx + tailwind-merge) for conditional classes.
- Mobile-first responsive: base styles are mobile, layer `md:`/`lg:` up.
- Interactive elements are real `<button>`/`<a>` — never clickable divs; keep
  focus states visible.
