---
name: mongodb-data-modeling
description: Conventions for Mongoose schemas, models, indexes, and queries in TypeScript. Use when creating or changing a MongoDB collection, writing queries, or debugging query performance.
---

# MongoDB + Mongoose conventions

## Model definition pattern

One file per model in `src/lib/db/models/<name>.ts`:

```ts
import { Schema, model, models, type InferSchemaType } from 'mongoose'

const userSchema = new Schema(
  {
    email: { type: String, required: true, lowercase: true, trim: true },
    name: { type: String, required: true },
    role: { type: String, enum: ['user', 'admin'], default: 'user' },
  },
  { timestamps: true },
)

userSchema.index({ email: 1 }, { unique: true })

export type UserDoc = InferSchemaType<typeof userSchema>
// models.User guard is required: Next.js hot reload re-runs this module
export const User = models.User ?? model('User', userSchema)
```

## Rules

- **`models.X ?? model(...)`** guard on every model — without it, hot reload
  throws `OverwriteModelError`.
- **`timestamps: true`** on every schema.
- **Declare indexes in the schema file**, one per real query pattern. Compound
  indexes follow ESR: Equality fields, then Sort fields, then Range fields.
- **Embed vs reference**: embed bounded, owned, read-together data; reference
  anything unbounded, shared, or independently queried. No unbounded arrays.
- **Reads use `.lean()`** and map to a DTO before leaving the service:
  ```ts
  const doc = await User.findById(id).lean()
  if (!doc) return null
  return { id: doc._id.toString(), email: doc.email, name: doc.name }
  ```
  Never return raw documents (ObjectId/Date don't serialize across RSC, and
  `__v`/internals leak).
- **Writes**: pick explicit fields from validated input — never spread a request
  body into `create`/`updateOne` (mass assignment).
- **Queries take validated primitives**, never user-supplied objects — building a
  filter from a raw object enables NoSQL injection (`{ $gt: '' }`).
- **Always paginate list queries**: `.limit()` + cursor (`_id`-based) or
  skip/limit for small datasets.
- **Cast ids deliberately**: validate with Zod
  (`z.string().regex(/^[0-9a-f]{24}$/)`) before querying; an invalid ObjectId
  string throws a CastError, not a clean 404.

## Transactions

Multi-document writes that must be atomic use a session — but first ask whether
a better document design (embedding) removes the need. Local single-node Mongo
needs a replica set for transactions; note that in the README if used.

## Migrations

Schema changes on existing collections need a note in the PR: backfill script
(`scripts/migrations/<date>-<name>.ts`) or lazy-migrate-on-read, and which one.
