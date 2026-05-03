# LOANED Status — Design Spec

**Date:** 2026-05-03  
**Status:** Approved

---

## Overview

Add a `LOANED` device status for items temporarily lent to others. Loaned devices are still owned, so they count toward estimated value. The only lifecycle action is returning the device to the collection.

---

## Data Layer

**`api/prisma/schema.prisma`**
- Add `LOANED` to the `Status` enum (after `RETURNED`)
- Create migration: `npx prisma migrate dev --name add_loaned_status`
- Run `npx prisma generate` to regenerate the client

**Financials behavior**
- The `estimatedValueOwned` query already excludes `['SOLD', 'DONATED', 'IN_REPAIR', 'REPAIRED', 'RETURNED']` via a `notIn` filter. `LOANED` is not in that list, so it is automatically included — no resolver change needed.

---

## API

**`api/src/typeDefs.ts`**
- Add `LOANED` to the `Status` enum in the GraphQL schema

**`api/src/resolvers.ts`**
- Add `LOANED: "Loaned"` to the `statusLabels` map used by the collection stats resolver

---

## Web

### Translations

Add `LOANED` key to the `status` section of all three language files:

| File | Value |
|------|-------|
| `en.ts` | `"Loaned"` |
| `de.ts` | `"Verliehen"` |
| `fr.ts` | `"Prêté"` |

Also add `LOANED` to the `Translations` type definition in `en.ts`.

### Colors

Sky blue — distinct from all existing statuses.

| Location | Classes |
|----------|---------|
| Card badge (`DeviceCardNew.tsx`) | `bg: 'bg-sky-500', text: 'text-white', valueText: 'text-sky-500'` |
| Detail status chip (`devices/[id]/page.tsx`) | `bg-sky-100 text-sky-800 dark:bg-sky-900/40 dark:text-sky-300` |

### Lifecycle Actions (`web/src/app/devices/[id]/page.tsx`)

**From COLLECTION:**  
Add a "Mark as Loaned" button alongside the existing "For Sale" button. Calls `handleSetStatus('LOANED')`.

**From LOANED:**  
New section with a single "Return to Collection" button. Calls `handleSetStatus('COLLECTION')`.

**Catch-all block:**  
The existing catch-all "Return to Collection" (shown for SOLD, DONATED, RETURNED, etc.) must explicitly exclude `LOANED` so it doesn't render a duplicate button.

### i18n keys needed (web)

Add to `detail` section (or reuse existing `lifecycleActions` pattern):
- `markAsLoaned` — "Mark as Loaned" / "Als Verliehen markieren" / "Marquer comme Prêté"
- `returnToCollection` already exists — reuse it

---

## iOS

### `Models/Device.swift`

Add `LOANED` case to the `Status` enum:
- `displayName`: `lm.t.status.LOANED`
- `color`: `"cyan"` (distinct from `"blue"` used by FOR_SALE and `"teal"` used by IN_REPAIR)

### Translations

**`i18n/Translations.swift`**
- Add `LOANED` to the `StatusT` struct

**`i18n/Translations+en.swift`**  
`LOANED: "Loaned"`

**`i18n/Translations+de.swift`**  
`LOANED: "Verliehen"`

**`i18n/Translations+fr.swift`**  
`LOANED: "Prêté"`

### Lifecycle (iOS device detail / edit views)

- From `COLLECTION`: add "Mark as Loaned" action
- From `LOANED`: show "Return to Collection" action
- Follow the existing pattern used for IN_REPAIR → COLLECTION transitions

---

## Release Notes

Add to `Unreleased` in `web/src/lib/releaseNotes.ts` and `CHANGELOG.md`:
- `added`: "LOANED status for devices temporarily lent to others — sky blue badge, counts toward estimated value, lifecycle action returns device to collection"

---

## Build Verification Order

1. `cd api && npx prisma migrate dev && npx prisma generate && npm run build`
2. `cd web && npm run build`
3. `cd storefront && npm run build`
4. iOS: `xcodebuild` to verify no compile errors from new enum case
