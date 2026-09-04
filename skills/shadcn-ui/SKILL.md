---
name: shadcn-ui
description: shadcn/ui conventions - installing and generating components with the CLI, theming with CSS variables, composing forms/dialogs/tables, third-party registries and the shadcn MCP server (21st.dev as opt-in), and the AI SDK helpers for chat UIs. Use when adding UI components, looking for fancy/animated UI, building forms/dialogs/data tables, theming, or building an AI chat interface.
---

# shadcn/ui

shadcn/ui is the component layer: accessible Radix-based components **copied into
the repo** via CLI, styled with Tailwind. You own the code — edit it like any
other project file.

## Setup

In an existing Next.js + Tailwind app:

```bash
pnpm dlx shadcn@latest init
```

For a brand-new app, scaffold through shadcn instead of create-next-app:

```bash
pnpm dlx shadcn@latest init -t next
```

`init` creates `components.json` (style, base color, CSS variables, aliases) and
`src/lib/utils.ts` with the `cn()` helper. Components land in `src/components/ui/`.

## Adding components

```bash
pnpm dlx shadcn@latest add button card dialog form input table sonner
```

Rules:
- **Always generate via the CLI** — never hand-write a file into `components/ui/`
  or copy from memory; the registry version matches the installed Radix/Tailwind.
- `components/ui/` is shadcn's namespace. Your own components live in
  `components/` and `modules/<feature>/components/` and **compose** the ui
  primitives. Edit `components/ui/` files only for project-wide restyles, and
  know that `add` will not overwrite your edits silently — it prompts.
- Before building any widget by hand, check the registry
  (`pnpm dlx shadcn@latest search -q <term>` or ui.shadcn.com/docs/components) —
  dialogs, comboboxes, date pickers, data tables, charts already exist.
- Don't install all components "to be safe" — add on demand; each one is code
  you now own.

## Registries and MCP

The **official shadcn MCP server** is the default way to discover and install
UI, including "fancy" third-party components. It is free and needs no API key:

```bash
pnpm dlx shadcn@latest mcp init --client claude   # writes .mcp.json in the project
```

With it wired up, ask in plain language ("add a login form", "find an animated
hero section") and it searches and installs through the same CLI path — so the
"always generate via the CLI" rule still holds.

Third-party registries (Magic UI, Aceternity, Origin UI, Kibo UI, …) plug into
`components.json` under `registries` and are addressed with a namespace:

```bash
pnpm dlx shadcn@latest add @magicui/shimmer-button
```

Prefer this route over hand-porting a component from a docs page: the registry
item is versioned, declares its dependencies, and lands in `components/ui/`
like everything else. Still restyle anything that ships with hard-coded palette
classes onto the semantic tokens below.

**21st.dev (opt-in, not installed by default).** A community catalog plus an
MCP that can *generate* new component variants from a prompt. Reach for it only
when no shadcn-compatible registry has what you need. Caveats: it needs an
account (browser login or a `TWENTYFIRST_TOKEN` API key), free accounts get a
small daily quota for retrieving component code, and AI generation costs
credits. Two ways to bring code in, with different rules:

- `21st add <user>/<slug>` installs through the 21st **shadcn registry** — same
  footing as any registry item above, lands in `components/ui/`.
- Anything from `21st get` or `21st generate` is bespoke code — put it in
  `components/` or `modules/<feature>/components/`, **never** in
  `components/ui/`, refactor its colors onto semantic tokens, and review it
  like any third-party paste.

Wire it per project when wanted (the `@21st-dev/cli` package supersedes the
older `@21st-dev/magic`):

```bash
npx @21st-dev/cli login                          # one-time, saves a token in ~/.config/21st
npx @21st-dev/cli init --client claude --write   # merges the 21st server into the MCP config
```

## Theming

- Colors are CSS variables in `globals.css` (`--background`, `--primary`,
  `--destructive`, …) with a `.dark` block. Change the theme by changing the
  variables, not by editing class strings inside `components/ui/`.
- In feature code use the semantic tokens (`bg-background`, `text-muted-foreground`,
  `border-input`) — raw palette classes (`bg-zinc-100`) break dark mode.
- Dark mode via `next-themes` `<ThemeProvider attribute="class">` in the root layout.

## Composition patterns

**Forms** — `form` component (react-hook-form + `zodResolver`) reusing the same
Zod schema the server action validates with:

```tsx
const form = useForm<CreateUserInput>({ resolver: zodResolver(createUserSchema) })
```

`<Form {...form}>` + `FormField`/`FormItem`/`FormLabel`/`FormControl`/`FormMessage`
per field. Submit handler calls the mutation from the tanstack-query skill:
`onSubmit={form.handleSubmit((values) => mutate(values))}`, button disabled while
`isPending`, server errors surfaced via `form.setError` or a toast (`sonner`).

**Data tables** — `table` primitives + `@tanstack/react-table` per the shadcn
data-table guide; feed it data from `useSuspenseQuery`, keep sorting/pagination
state in the query key so the server does the work.

**Confirmations** — `alert-dialog` for destructive actions, never `window.confirm`.
**Toasts** — `sonner`; fire from mutation `onSuccess`/`onError`.
**Loading** — `skeleton` components inside `loading.tsx`/Suspense fallbacks,
shaped like the content they replace.

## AI SDK helpers (chat UIs)

For AI chat interfaces, shadcn ships helpers that pair with the Vercel AI SDK
(`ai` + `@ai-sdk/react`):

```bash
pnpm add @shadcn/helpers
```

`createChat()` from `@shadcn/helpers/ai-sdk` builds typed, predefined
conversations and streams them through `useChat` **without a model, API route,
or key**:

```ts
const chat = createChat()
  .user('What is the weather?')
  .assistant('Let me check…', { tools: [...] })

useChat({ transport: chat.transport() })
```

Use it to develop and test chat components against realistic streaming output
(reasoning, tool calls, files, sources, human-in-the-loop pauses) before wiring a
real model — and in Vitest for deterministic chat-UI tests with no network. Wire
the real provider only after the UI is proven against the fake transport.

## Review checklist

- [ ] Components generated by the CLI, not hand-written into `components/ui/`
- [ ] Feature code composes ui primitives; no parallel bespoke button/input/dialog
- [ ] Semantic color tokens only in feature code
- [ ] Forms: shared Zod schema client + server, pending state, field-level errors
- [ ] Existing registry component checked before building a widget by hand
- [ ] Third-party/generated components (registries, 21st.dev) live outside `components/ui/`
      unless CLI-installed, and use semantic tokens
