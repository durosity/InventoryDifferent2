# Orphaned Files Cleanup — Design Spec

**Date:** 2026-05-10

## Overview

Add a lazy-scan orphaned file detector to the web Usage page. Files that exist in the `/app/uploads/devices/` directory but are not referenced by any `Image` record in the database waste storage. This feature lets admins identify and delete those files, individually or in bulk, with confirmation before any destructive action.

---

## API

### New GraphQL type

```graphql
type OrphanedFile {
  path: String!       # URL-style path, e.g. /uploads/devices/42/abc123.jpg
  sizeBytes: Float!
}
```

### New query

```graphql
Query {
  orphanedFiles: [OrphanedFile!]!   # auth-gated
}
```

**Resolver logic:**

1. Fetch all `Image.path` and `Image.thumbnailPath` values from the database into a `Set<string>`.
2. Recursively walk `/app/uploads/devices/` using `fs.readdirSync`.
3. For each file (not directory) encountered, convert its disk path back to the `/uploads/...` URL form and check if it exists in the Set.
4. If not found in the Set, collect it as an orphan with its `fs.statSync` size.
5. Return the list of orphans.

### New mutation

```graphql
Mutation {
  deleteOrphanedFiles(paths: [String!]!): Int!  # auth-required; returns count deleted
}
```

**Resolver logic:**

1. For each path, validate it starts with `/uploads/devices/` — reject any that don't (path traversal guard).
2. Map each to the disk path `/app/uploads/...`.
3. `fs.unlinkSync` each file, catching per-file errors silently (file already gone is fine).
4. Return the count of files successfully deleted.

---

## UI

Located on the existing `/usage` page (`web/src/app/(main)/usage/page.tsx`), as a new section below the storage card.

### States

**Initial (pre-scan):**
- A "Scan for Orphaned Files" button. No filesystem walk occurs on page load.

**Loading (scan in progress):**
- Button replaced with a loading spinner / disabled state.

**No orphans found:**
- Green confirmation: "No orphaned files found."
- "Scan Again" button remains available.

**Orphans found:**
- Summary bar: `{count} orphaned files · {totalSize}` with a "Select All" checkbox on the left and a "Delete Selected" button on the right (disabled until ≥ 1 file is checked).
- List of orphaned files, one per row:
  - Checkbox
  - Truncated path (e.g. `devices/42/leftover.jpg`)
  - File size
  - Individual delete button — first click turns the button red and shows "Confirm?"; second click executes the deletion
- "Scan Again" button below the list.

**After bulk delete:**
- "Delete Selected" triggers a modal: "Delete {n} files? This cannot be undone." with Cancel / Confirm buttons.
- On confirm, calls `deleteOrphanedFiles` mutation with selected paths.
- Deleted files are removed from the list client-side. If the list becomes empty, transition to the "no orphans" state.

**After individual delete:**
- The confirmed file is removed from the list immediately client-side.
- Summary bar count and size update accordingly.
- If the list becomes empty, transition to the "no orphans" state.

---

## i18n

All new UI strings go through the translation system. New keys under `pages.usage`:

- `orphanedFiles` — section heading
- `scanButton` — "Scan for Orphaned Files"
- `scanAgainButton` — "Scan Again"
- `noOrphansFound` — "No orphaned files found."
- `orphansSummary` — "{count} orphaned files · {size}"
- `deleteSelected` — "Delete Selected"
- `selectAll` — "Select All"
- `confirmDeleteSingle` — "Confirm?"
- `confirmDeleteBulkTitle` — "Delete {n} files?"
- `confirmDeleteBulkBody` — "This cannot be undone."

Added to `en.ts`, `de.ts`, and `fr.ts`.

---

## Error Handling

- If the scan query fails, show an inline error message with a retry option.
- If the delete mutation partially fails (some files already gone), the returned count is still shown and client-side list updated for the successfully-deleted set. No hard error surfaced for already-missing files.
- Path validation failures (non-`/uploads/devices/` paths) return a GraphQL error and no files are deleted.

---

## Auth

Both `orphanedFiles` query and `deleteOrphanedFiles` mutation require authentication, consistent with all other destructive admin operations.

---

## Out of Scope

- Orphaned device-level directories (empty folders with no corresponding device) — not addressed in this iteration.
- Any changes to the storefront or iOS app.
